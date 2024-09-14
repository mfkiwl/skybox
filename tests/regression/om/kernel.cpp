#include "common.h"
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <vx_print.h>
#include <algorithm>
#include <math.h>

typedef struct {
  uint32_t tile_height;
	int a_scale;
	int r_scale;
	int g_scale;
	int b_scale;
} tile_info_t;

static tile_info_t g_tileinfo;

#define FXP_FRAC 16

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
	int a_scale = g_tileinfo.a_scale;
	int r_scale = g_tileinfo.r_scale;
	int g_scale = g_tileinfo.g_scale;
	int b_scale = g_tileinfo.b_scale;

	auto y_start = blockIdx.x * g_tileinfo.tile_height;
	auto y_end   = std::min<uint32_t>(y_start + g_tileinfo.tile_height, arg->dst_height);

	auto x_start = 0;
	auto x_end = arg->dst_width;

	uint32_t backface = arg->backface;
	uint32_t depth    = arg->depth;

	for (uint32_t y = y_start; y < y_end; ++y) {
		for (uint32_t x = x_start; x < x_end; ++x) {

			uint32_t alpha = arg->blend_enable ? ((y * a_scale) >> FXP_FRAC) : 0xff;
			uint32_t red   = (x * r_scale) >> FXP_FRAC;
			uint32_t green = (y * g_scale) >> FXP_FRAC;
			uint32_t blue  = ((x + y) * b_scale) >> FXP_FRAC;

			uint32_t color = (alpha << 24) | (red << 16) | (green << 8) | blue;

			vx_om(x, y, backface, color, depth);
		}
	}
}

int main() {
	auto __UNIFORM__ arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);

	int red   = (arg->color >> 16) & 0xff;
	int green = (arg->color >> 8) & 0xff;
	int blue  = arg->color & 0xff;

	g_tileinfo.tile_height = (arg->dst_height + arg->num_tasks - 1) / arg->num_tasks;
	g_tileinfo.a_scale = (255 << FXP_FRAC) / arg->dst_height;
	g_tileinfo.r_scale = (red << FXP_FRAC) / arg->dst_width;
  g_tileinfo.g_scale = (green << FXP_FRAC) / arg->dst_height;
  g_tileinfo.b_scale = (blue << FXP_FRAC) / (arg->dst_width + arg->dst_height);

	return vx_spawn_threads(1, &arg->num_tasks, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}