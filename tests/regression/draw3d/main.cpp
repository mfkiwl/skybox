#include <iostream>
#include <vector>
#include <unistd.h>
#include <cstring>
#include <chrono>
#include <cmath>
#include <array>
#include <assert.h>
#include <vortex.h>
#include <graphics.h>
#include <gfxutil.h>
#include <bitmanip.h>
#include "common.h"
#include <cocogfx/include/blitter.hpp>
#include <cocogfx/include/imageutil.hpp>

using namespace cocogfx;

#ifndef ASSETS_PATHS
#define ASSETS_PATHS ""
#endif

#define RT_CHECK(_expr)                                         \
   do {                                                         \
     int _ret = _expr;                                          \
     if (0 == _ret)                                             \
       break;                                                   \
     printf("Error: '%s' returned %d!\n", #_expr, (int)_ret);   \
	 cleanup();			                                              \
     exit(-1);                                                  \
   } while (false)

///////////////////////////////////////////////////////////////////////////////

const char* kernel_file = "kernel.vxbin";
const char* trace_file  = "triangle.cgltrace";
const char* output_file = "output.png";
const char* reference_file = nullptr;

bool sw_rast = false;
bool sw_tex = false;
bool sw_om = false;

uint32_t start_draw = 0;
uint32_t end_draw = -1;

uint32_t clear_color = 0xff000000;
uint32_t clear_depth = 0xffffffff;

uint32_t dst_width  = 128;
uint32_t dst_height = 128;

uint32_t zbuf_stride;
uint32_t zbuf_pitch;
uint32_t zbuf_size;

uint32_t cbuf_stride;
uint32_t cbuf_pitch;
uint32_t cbuf_size;

uint64_t cbuf_addr;
uint64_t zbuf_addr;
uint64_t texbuf_addr;
uint64_t tilebuf_addr;
uint64_t primbuf_addr;

vx_device_h device      = nullptr;
vx_buffer_h krnl_buffer = nullptr;
vx_buffer_h args_buffer = nullptr;
vx_buffer_h depth_buffer= nullptr;
vx_buffer_h color_buffer= nullptr;
vx_buffer_h tex_buffer  = nullptr;
vx_buffer_h tile_buffer = nullptr;
vx_buffer_h prim_buffer = nullptr;

kernel_arg_t kernel_arg = {};

uint32_t tileLogSize = RASTER_TILE_LOGSIZE;

static void show_usage() {
   std::cout << "Vortex 3D Rendering Test." << std::endl;
   std::cout << "Usage: [-t trace] [-s startdraw] [-e enddraw] [-o output] [-r reference] [-w width] [-h height] [-e empty] [-x s/w rast] [-y s/w om] [-k tilelogsize]" << std::endl;
}

static void parse_args(int argc, char **argv) {
  int c;
  while ((c = getopt(argc, argv, "t:s:e:i:o:r:w:h:t:k:uxyz?")) != -1) {
    switch (c) {
    case 't':
      trace_file = optarg;
      break;
    case 's':
      start_draw = std::atoi(optarg);
      break;
    case 'e':
      end_draw = std::atoi(optarg);
      break;
    case 'o':
      output_file = optarg;
      break;
    case 'r':
      reference_file = optarg;
      break;
    case 'w':
      dst_width = std::atoi(optarg);
      break;
    case 'h':
      dst_height = std::atoi(optarg);
      break;
    case 'u':
      sw_tex = true;
      break;
    case 'x':
      sw_rast = true;
      break;
    case 'y':
      sw_om = true;
      break;
    case 'k':
      tileLogSize = std::atoi(optarg);
      break;
    case '?': {
      show_usage();
      exit(0);
    } break;
    default:
      show_usage();
      exit(-1);
    }
  }
  if (strcmp (output_file, "null") == 0 && reference_file) {
    std::cout << "Error: the output file is missing for reference validation!" << std::endl;
    exit(1);
  }
}

void cleanup() {
  vx_mem_free(depth_buffer);
  vx_mem_free(color_buffer);
  vx_mem_free(tex_buffer);
  vx_mem_free(tile_buffer);
  vx_mem_free(prim_buffer);
  vx_mem_free(krnl_buffer);
  vx_mem_free(args_buffer);
  vx_dev_close(device);
}

#ifdef SW_ENABLE
  #define RASTER_DCR_WRITE(addr, value)  \
    vx_dcr_write(device, addr, value); \
    kernel_arg.raster_dcrs.write(addr, value)

  #define OM_DCR_WRITE(addr, value)  \
    vx_dcr_write(device, addr, value); \
    kernel_arg.om_dcrs.write(addr, value)

  #define TEX_DCR_WRITE(addr, value)  \
    vx_dcr_write(device, addr, value); \
    kernel_arg.tex_dcrs.write(addr, value)
#else
  #define RASTER_DCR_WRITE(addr, value)  \
    vx_dcr_write(device, addr, value)

  #define OM_DCR_WRITE(addr, value)  \
    vx_dcr_write(device, addr, value)

  #define TEX_DCR_WRITE(addr, value)  \
    vx_dcr_write(device, addr, value)
#endif

int render(const CGLTrace& trace) {
  std::cout << "render" << std::endl;
  auto time_begin = std::chrono::high_resolution_clock::now();

  uint64_t instrs = 0;
  uint64_t cycles = 0;

  // render each draw call
  for (uint32_t d = 0, nd = trace.drawcalls.size(); d < nd; ++d) {
    if (d < start_draw || d > end_draw)
      continue;

    auto& drawcall = trace.drawcalls.at(d);
    auto& states = drawcall.states;

    std::vector<uint8_t> tilebuf;
    std::vector<uint8_t> primbuf;

    // Perform tile binning
    auto num_tiles = graphics::Binning(tilebuf, primbuf, drawcall.vertices, drawcall.primitives, dst_width, dst_height, drawcall.viewport.near, drawcall.viewport.far, tileLogSize);
    std::cout << "Binning allocated " << std::dec << num_tiles << " tiles with " << (primbuf.size() / sizeof(graphics::rast_prim_t)) << " total primitives." << std::endl;
    if (0 == num_tiles)
      continue;

    // allocate tile memory
    if (tile_buffer != nullptr) vx_mem_free(tile_buffer);
    if (prim_buffer != nullptr) vx_mem_free(prim_buffer);
    RT_CHECK(vx_mem_alloc(device, tilebuf.size(), VX_MEM_READ, &tile_buffer));
    RT_CHECK(vx_mem_address(tile_buffer, &tilebuf_addr));
    RT_CHECK(vx_mem_alloc(device, primbuf.size(), VX_MEM_READ, &prim_buffer));
    RT_CHECK(vx_mem_address(prim_buffer, &primbuf_addr));
    std::cout << "tile_buffer=0x" << std::hex << tilebuf_addr << std::dec << std::endl;
    std::cout << "prim_buffer=0x" << std::hex << primbuf_addr << std::dec << std::endl;

    // upload tiles buffer
    std::cout << "upload tile buffer" << std::endl;
    RT_CHECK(vx_copy_to_dev(tile_buffer, tilebuf.data(), 0, tilebuf.size()));

    // upload primitives buffer
    std::cout << "upload primitive buffer" << std::endl;
    RT_CHECK(vx_copy_to_dev(prim_buffer, primbuf.data(), 0, primbuf.size()));

    uint32_t primbuf_stride = sizeof(graphics::rast_prim_t);

    // configure raster units
    RASTER_DCR_WRITE(VX_DCR_RASTER_TBUF_ADDR,   tilebuf_addr / 64); // block address
    RASTER_DCR_WRITE(VX_DCR_RASTER_TILE_COUNT,  num_tiles);
    RASTER_DCR_WRITE(VX_DCR_RASTER_PBUF_ADDR,   primbuf_addr / 64); // block address
    RASTER_DCR_WRITE(VX_DCR_RASTER_PBUF_STRIDE, primbuf_stride);
    RASTER_DCR_WRITE(VX_DCR_RASTER_SCISSOR_X, (dst_width << 16) | 0);
    RASTER_DCR_WRITE(VX_DCR_RASTER_SCISSOR_Y, (dst_height << 16) | 0);

    // configure om color buffer
    OM_DCR_WRITE(VX_DCR_OM_CBUF_ADDR,  cbuf_addr / 64); // block address
    OM_DCR_WRITE(VX_DCR_OM_CBUF_PITCH, cbuf_pitch);
    OM_DCR_WRITE(VX_DCR_OM_CBUF_WRITEMASK, states.color_writemask);

    if (states.depth_test || states.stencil_test) {
      // configure om depth buffer
      OM_DCR_WRITE(VX_DCR_OM_ZBUF_ADDR,  zbuf_addr / 64); // block address
      OM_DCR_WRITE(VX_DCR_OM_ZBUF_PITCH, zbuf_pitch);
    }

    if (states.depth_test) {
      // configure om depth states
      auto depth_func = graphics::toVXCompare(states.depth_func);
      OM_DCR_WRITE(VX_DCR_OM_DEPTH_FUNC, depth_func);
      OM_DCR_WRITE(VX_DCR_OM_DEPTH_WRITEMASK, states.depth_writemask);
    } else {
      OM_DCR_WRITE(VX_DCR_OM_DEPTH_FUNC, VX_OM_DEPTH_FUNC_ALWAYS);
      OM_DCR_WRITE(VX_DCR_OM_DEPTH_WRITEMASK, 0);
    }

    if (states.stencil_test) {
      // configure om stencil states
      auto stencil_func  = graphics::toVXCompare(states.stencil_func);
      auto stencil_zpass = graphics::toVXStencilOp(states.stencil_zpass);
      auto stencil_zfail = graphics::toVXStencilOp(states.stencil_zfail);
      auto stencil_fail  = graphics::toVXStencilOp(states.stencil_fail);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_FUNC, stencil_func);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_ZPASS, stencil_zpass);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_ZPASS, stencil_zfail);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_FAIL, stencil_fail);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_REF, states.stencil_ref);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_MASK, states.stencil_mask);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_WRITEMASK, states.stencil_writemask);
    } else {
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_FUNC, VX_OM_DEPTH_FUNC_ALWAYS);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_ZPASS, VX_OM_STENCIL_OP_KEEP);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_ZPASS, VX_OM_STENCIL_OP_KEEP);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_FAIL, VX_OM_STENCIL_OP_KEEP);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_REF, 0);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_MASK, VX_OM_STENCIL_MASK);
      OM_DCR_WRITE(VX_DCR_OM_STENCIL_WRITEMASK, 0);
    }

    if (states.blend_enabled) {
      // configure om blend states
      auto blend_src = graphics::toVXBlendFunc(states.blend_src);
      auto blend_dst = graphics::toVXBlendFunc(states.blend_dst);
      OM_DCR_WRITE(VX_DCR_OM_BLEND_MODE, (VX_OM_BLEND_MODE_ADD << 16)   // DST
                                         | (VX_OM_BLEND_MODE_ADD << 0));  // SRC
      OM_DCR_WRITE(VX_DCR_OM_BLEND_FUNC, (blend_dst << 24)            // DST_A
                                         | (blend_dst << 16)            // DST_RGB
                                         | (blend_src << 8)             // SRC_A
                                         | (blend_src << 0));           // SRC_RGB
    } else {
      OM_DCR_WRITE(VX_DCR_OM_BLEND_MODE, (VX_OM_BLEND_MODE_ADD << 16)   // DST
                                         | (VX_OM_BLEND_MODE_ADD << 0));  // SRC
      OM_DCR_WRITE(VX_DCR_OM_BLEND_FUNC, (VX_OM_BLEND_FUNC_ZERO << 24)  // DST_A
                                         | (VX_OM_BLEND_FUNC_ZERO << 16)  // DST_RGB
                                         | (VX_OM_BLEND_FUNC_ONE << 8)    // SRC_A
                                         | (VX_OM_BLEND_FUNC_ONE << 0));  // SRC_RGB
    }

    if (states.texture_enabled) {
      // configure texture states
      std::vector<uint8_t> texbuf;
      std::vector<uint32_t> mip_offsets;

      auto& texture = trace.textures.at(drawcall.texture_id);

      auto tex_bpp = Format::GetInfo(texture.format).BytePerPixel;
      auto tex_pitch = texture.width * tex_bpp;

      // generate mipmaps
      RT_CHECK(GenerateMipmaps(texbuf, mip_offsets, texture.pixels.data(), texture.format, texture.width, texture.height, tex_pitch));

      uint32_t tex_logwidth = log2ceil(texture.width);
      uint32_t tex_logheight = log2ceil(texture.height);

      int tex_format = graphics::toVXFormat(texture.format);

      int tex_filter = (states.texture_magfilter != CGLTrace::FILTER_NEAREST)
                    || (states.texture_magfilter != CGLTrace::FILTER_NEAREST);

      int tex_wrapU = (states.texture_addressU == CGLTrace::ADDRESS_WRAP);
      int tex_wrapV = (states.texture_addressU == CGLTrace::ADDRESS_WRAP);

      // allocate texture memory
      if (tex_buffer != nullptr) vx_mem_free(tex_buffer);
      RT_CHECK(vx_mem_alloc(device, texbuf.size(), VX_MEM_READ, &tex_buffer));
      RT_CHECK(vx_mem_address(tex_buffer, &texbuf_addr));
      std::cout << "tex_buffer=0x" << std::hex << texbuf_addr << std::dec << std::endl;

      // upload texture data
      std::cout << "upload texture buffer" << std::endl;
      RT_CHECK(vx_copy_to_dev(tex_buffer, texbuf.data(), 0, texbuf.size()));

      // configure texture units
      TEX_DCR_WRITE(VX_DCR_TEX_STAGE,  0);
      TEX_DCR_WRITE(VX_DCR_TEX_LOGDIM, (tex_logheight << 16) | tex_logwidth);
      TEX_DCR_WRITE(VX_DCR_TEX_FORMAT, tex_format);
      TEX_DCR_WRITE(VX_DCR_TEX_WRAP,   (tex_wrapV << 16) | tex_wrapU);
      TEX_DCR_WRITE(VX_DCR_TEX_FILTER, tex_filter ? VX_TEX_FILTER_BILINEAR : VX_TEX_FILTER_POINT);
      TEX_DCR_WRITE(VX_DCR_TEX_ADDR,   texbuf_addr / 64); // block address
      for (uint32_t i = 0; i < mip_offsets.size(); ++i) {
        assert(i < VX_TEX_LOD_MAX);
        TEX_DCR_WRITE(VX_DCR_TEX_MIPOFF(i), mip_offsets.at(i));
      };
    }

    // upload kernel argument
    std::cout << "upload kernel argument" << std::endl;
    {
      kernel_arg.depth_enabled = states.depth_test;
      kernel_arg.color_enabled = states.color_enabled;
      kernel_arg.tex_enabled   = states.texture_enabled;
      kernel_arg.tex_modulate  = (states.texture_enabled && states.texture_envmode == CGLTrace::ENVMODE_MODULATE);
      kernel_arg.prim_addr     = primbuf_addr;
      if (kernel_arg.tex_modulate && !kernel_arg.color_enabled)
        kernel_arg.tex_modulate = false;
      if (kernel_arg.tex_enabled && kernel_arg.color_enabled && !kernel_arg.tex_modulate)
        kernel_arg.color_enabled = false;

      RT_CHECK(vx_upload_bytes(device, &kernel_arg, sizeof(kernel_arg_t), &args_buffer));
    }

    auto time_start = std::chrono::high_resolution_clock::now();

    // start device
    std::cout << "start device" << std::endl;
    RT_CHECK(vx_start(device, krnl_buffer, args_buffer));

    // wait for completion
    std::cout << "wait for completion" << std::endl;
    RT_CHECK(vx_ready_wait(device, VX_MAX_TIMEOUT));

    auto time_end = std::chrono::high_resolution_clock::now();
    double elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(time_end - time_start).count();
    printf("Elapsed time: %lg ms\n", elapsed);

    if (d < trace.drawcalls.size()-1) {
      vx_dump_perf(device, stdout);
    }

    uint64_t instrs_;
    uint64_t cycles_;
    RT_CHECK(vx_mpm_query(device, VX_CSR_MCYCLE, -1, &cycles_));
    RT_CHECK(vx_mpm_query(device, VX_CSR_MINSTRET, -1, &instrs_));
    cycles += cycles_;
    instrs += instrs_;
  }

  auto time_end = std::chrono::high_resolution_clock::now();
  double elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(time_end - time_begin).count();
  float IPC = (float)(double(instrs) / double(cycles));
  printf("Total elapsed time: %lg ms, instrs=%ld, cycles=%ld, IPC=%f\n", elapsed, instrs, cycles, IPC);

  if (strcmp(output_file, "null") != 0) {
    std::cout << "save output image" << std::endl;
    std::vector<uint8_t> dst_pixels(cbuf_size);
    RT_CHECK(vx_copy_from_dev(dst_pixels.data(), color_buffer, 0, cbuf_size));
    //DumpImage(dst_pixels, dst_width, dst_height, 4);
    auto bits = dst_pixels.data() + (dst_height-1) * cbuf_pitch;
    RT_CHECK(SaveImage(output_file, FORMAT_A8R8G8B8, bits, dst_width, dst_height, -cbuf_pitch));
  }

  return 0;
}

int main(int argc, char *argv[]) {
  // parse command arguments
  parse_args(argc, argv);

  // open device connection
  std::cout << "open device connection" << std::endl;
  RT_CHECK(vx_dev_open(&device));

  uint64_t isa_flags;
  RT_CHECK(vx_dev_caps(device, VX_CAPS_ISA_FLAGS, &isa_flags));
  bool has_ext = (isa_flags & VX_ISA_EXT_RASTER) != 0;
  if (!has_ext) {
    std::cout << "RASTER ISA extensions are needed!" << std::endl;
    cleanup();
    return -1;
  }
  if (0 == (isa_flags & (VX_ISA_EXT_TEX))) {
    std::cout << "TEX ISA extensions are needed!" << std::endl;
    cleanup();
    return -1;
  }
  if (0 == (isa_flags & (VX_ISA_EXT_OM))) {
    std::cout << "OM ISA extensions are needed!" << std::endl;
    cleanup();
    return -1;
  }

  uint64_t num_cores, num_warps, num_threads;
  RT_CHECK(vx_dev_caps(device, VX_CAPS_NUM_CORES, &num_cores));
  RT_CHECK(vx_dev_caps(device, VX_CAPS_NUM_WARPS, &num_warps));
  RT_CHECK(vx_dev_caps(device, VX_CAPS_NUM_THREADS, &num_threads));

  uint32_t num_tasks = num_cores * num_warps * num_threads;

  std::cout << "number of tasks: " << std::dec << num_tasks << std::endl;

  CGLTrace trace;
  auto trace_file_s = graphics::ResolveFilePath(trace_file, ASSETS_PATHS);
  RT_CHECK(trace.load(trace_file_s.c_str()));

  uint64_t total_drawcalls  = trace.drawcalls.size();
  uint64_t total_textures   = trace.textures.size();
  uint64_t total_vertices   = 0;
  uint64_t total_primitives = 0;
  bool depth_test    = false;
  bool stencil_test  = false;
  bool blend_enabled = false;
  for (auto& drawcall : trace.drawcalls) {
    if (drawcall.states.depth_test)
      depth_test = true;
    if (drawcall.states.stencil_test)
      stencil_test = true;
    if (drawcall.states.blend_enabled)
      blend_enabled = true;
    total_vertices += drawcall.vertices.size();
    total_primitives += drawcall.primitives.size();
  }
  std::cout << "CGL Trace: drawcalls=" << std::dec << total_drawcalls
            << ", vertices=" << total_vertices
            << ", primitives=" << total_primitives
            << ", textures=" << total_textures
            << ", depth=" << depth_test
            << ", stencil=" << stencil_test
            << ", blend=" << blend_enabled << std::endl;

  // upload program
  std::cout << "upload program" << std::endl;
  RT_CHECK(vx_upload_kernel_file(device, kernel_file, &krnl_buffer));

  zbuf_stride = 4;
  zbuf_pitch  = dst_width * zbuf_stride;
  zbuf_size   = dst_height * zbuf_pitch;

  cbuf_stride = 4;
  cbuf_pitch  = dst_width * cbuf_stride;
  cbuf_size   = dst_width * cbuf_pitch;

  // allocate device memory
  RT_CHECK(vx_mem_alloc(device, zbuf_size, VX_MEM_READ_WRITE, &depth_buffer));
  RT_CHECK(vx_mem_address(depth_buffer, &zbuf_addr));
  RT_CHECK(vx_mem_alloc(device, cbuf_size, VX_MEM_READ_WRITE, &color_buffer));
  RT_CHECK(vx_mem_address(color_buffer, &cbuf_addr));

  std::cout << "depth_buffer=0x" << std::hex << zbuf_addr << std::dec << std::endl;
  std::cout << "color_buffer=0x" << std::hex << cbuf_addr << std::dec << std::endl;

  // clear depth buffer
  std::cout << "clear depth buffer" << std::endl;
  {
    std::vector<uint32_t> staging_buf(zbuf_size / zbuf_stride, clear_depth);
    RT_CHECK(vx_copy_to_dev(depth_buffer, staging_buf.data(), 0, zbuf_size));
  }

  // clear destination buffer
  std::cout << "clear destination buffer" << std::endl;
  {
    std::vector<uint32_t> staging_buf(cbuf_size / cbuf_stride, clear_color);
    RT_CHECK(vx_copy_to_dev(color_buffer, staging_buf.data(), 0, cbuf_size));
  }

  // update kernel arguments
  kernel_arg.log_num_tasks = log2ceil(num_tasks);
  kernel_arg.sw_tex        = sw_tex;
  kernel_arg.sw_rast       = sw_rast;
  kernel_arg.sw_om         = sw_om;

  // run tests
  RT_CHECK(render(trace));

  // cleanup
  std::cout << "cleanup" << std::endl;
  cleanup();

  if (reference_file) {
     auto reference_file_s = graphics::ResolveFilePath(reference_file, ASSETS_PATHS);
    auto errors = CompareImages(output_file, reference_file_s.c_str(), FORMAT_A8R8G8B8);
    if (0 == errors) {
      std::cout << "PASSED!" << std::endl;
    } else {
      std::cout << "FAILED! " << errors << " errors." << std::endl;
      return errors;
    }
  }

  return 0;
}
