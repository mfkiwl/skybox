//!/bin/bash

// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "VX_tex_define.vh"

module VX_tex_unit import VX_gpu_pkg::*; import VX_tex_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_LANES = 1,
    parameter TAG_WIDTH = 1
) (
    input wire  clk,
    input wire  reset,

    // PERF
`ifdef PERF_ENABLE
    VX_tex_perf_if.master   perf_tex_if,
`endif

    VX_mem_bus_if.master    cache_bus_if [TCACHE_NUM_REQS],

    VX_dcr_bus_if.slave     dcr_bus_if,

    VX_tex_bus_if.slave     tex_bus_if
);
    `UNUSED_SPARAM (INSTANCE_ID)

    localparam BLEND_FRAC_W = (2 * NUM_LANES * `TEX_BLEND_FRAC);
    localparam W_ADDR_BITS = `TEX_ADDR_BITS + 6;

    // DCRs

    tex_dcrs_t tex_dcrs;

    VX_tex_dcr #(
        .INSTANCE_ID ($sformatf("%s-dcr", INSTANCE_ID)),
        .NUM_STAGES  (`VX_TEX_STAGE_COUNT)
    ) tex_dcr (
        .clk        (clk),
        .reset      (reset),
        .dcr_bus_if (dcr_bus_if),
        .stage      (tex_bus_if.req_data.stage),
        .tex_dcrs   (tex_dcrs)
    );

    // Texture stage select

    wire                                        req_valid;
    wire [NUM_LANES-1:0]                        req_mask;
    wire [`TEX_FILTER_BITS-1:0]                 req_filter;
    wire [`TEX_FORMAT_BITS-1:0]                 req_format;
    wire [1:0][`TEX_WRAP_BITS-1:0]              req_wraps;
    wire [1:0][`VX_TEX_LOD_BITS-1:0]            req_logdims;
    wire [`TEX_ADDR_BITS-1:0]                   req_baseaddr;
    wire [1:0][NUM_LANES-1:0][31:0]             req_coords;
    wire [NUM_LANES-1:0][`VX_TEX_LOD_BITS-1:0]  req_miplevel, sel_miplevel;
    wire [NUM_LANES-1:0][`TEX_MIPOFF_BITS-1:0]  req_mipoff, sel_mipoff;
    wire [TAG_WIDTH-1:0]                        req_tag;
    wire                                        req_ready;

    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign sel_miplevel[i] = tex_bus_if.req_data.lod[i][`VX_TEX_LOD_BITS-1:0];
        assign sel_mipoff[i] = tex_dcrs.mipoff[sel_miplevel[i]];
    end

    VX_elastic_buffer #(
        .DATAW   (NUM_LANES  + `TEX_FILTER_BITS + `TEX_FORMAT_BITS + 2 * `TEX_WRAP_BITS + 2 * `VX_TEX_LOD_BITS + `TEX_ADDR_BITS + NUM_LANES * (2 * 32 + `VX_TEX_LOD_BITS + `TEX_MIPOFF_BITS) + TAG_WIDTH),
        .OUT_REG (1)
    ) pipe_reg (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (tex_bus_if.req_valid),
        .ready_in  (tex_bus_if.req_ready),
        .data_in   ({tex_bus_if.req_data.mask, tex_dcrs.filter, tex_dcrs.format, tex_dcrs.wraps, tex_dcrs.logdims, tex_dcrs.baseaddr, tex_bus_if.req_data.coords, sel_miplevel, sel_mipoff, tex_bus_if.req_data.tag}),
        .data_out  ({req_mask, req_filter, req_format, req_wraps, req_logdims, req_baseaddr, req_coords, req_miplevel, req_mipoff, req_tag}),
        .valid_out (req_valid),
        .ready_out (req_ready)
    );

    // address generation

    wire mem_req_valid;
    wire [NUM_LANES-1:0] mem_req_mask;
    wire [`TEX_FILTER_BITS-1:0] mem_req_filter;
    wire [`TEX_LGSTRIDE_BITS-1:0] mem_req_lgstride;
    wire [NUM_LANES-1:0][1:0][`TEX_BLEND_FRAC-1:0] mem_req_blends;
    wire [NUM_LANES-1:0][3:0][31:0] mem_req_addr;
    wire [NUM_LANES-1:0][W_ADDR_BITS-1:0] mem_req_baseaddr;
    wire [(TAG_WIDTH + `TEX_FORMAT_BITS)-1:0] mem_req_info;
    wire mem_req_ready;

    VX_tex_addr #(
        .INSTANCE_ID ($sformatf("%s-addr", INSTANCE_ID)),
        .REQ_INFOW   (TAG_WIDTH + `TEX_FORMAT_BITS),
        .NUM_LANES   (NUM_LANES)
    ) tex_addr (
        .clk        (clk),
        .reset      (reset),

        // inputs
        .req_valid  (req_valid),
        .req_mask   (req_mask),
        .req_coords (req_coords),
        .req_format (req_format),
        .req_filter (req_filter),
        .req_wraps  (req_wraps),
        .req_baseaddr(req_baseaddr),
        .req_miplevel(req_miplevel),
        .req_mipoff (req_mipoff),
        .req_logdims(req_logdims),
        .req_info   ({req_tag, req_format}),
        .req_ready  (req_ready),

        // outputs
        .rsp_valid  (mem_req_valid),
        .rsp_mask   (mem_req_mask),
        .rsp_filter (mem_req_filter),
        .rsp_lgstride(mem_req_lgstride),
        .rsp_baseaddr(mem_req_baseaddr),
        .rsp_addr   (mem_req_addr),
        .rsp_blends (mem_req_blends),
        .rsp_info   (mem_req_info),
        .rsp_ready  (mem_req_ready)
    );

    // retrieve texel values from memory

    wire mem_rsp_valid;
    wire [NUM_LANES-1:0][3:0][31:0] mem_rsp_data;
    wire [(TAG_WIDTH + `TEX_FORMAT_BITS + BLEND_FRAC_W)-1:0] mem_rsp_info;
    wire mem_rsp_ready;

    VX_tex_mem #(
        .INSTANCE_ID ($sformatf("%s-mem", INSTANCE_ID)),
        .REQ_INFOW   (TAG_WIDTH + `TEX_FORMAT_BITS + BLEND_FRAC_W),
        .NUM_LANES   (NUM_LANES)
    ) tex_mem (
        .clk       (clk),
        .reset     (reset),

        // memory interface
        .cache_bus_if (cache_bus_if),

        // inputs
        .req_valid (mem_req_valid),
        .req_mask  (mem_req_mask),
        .req_filter(mem_req_filter),
        .req_lgstride(mem_req_lgstride),
        .req_baseaddr(mem_req_baseaddr),
        .req_addr  (mem_req_addr),
        .req_info  ({mem_req_info, mem_req_blends}),
        .req_ready (mem_req_ready),

        // outputs
        .rsp_valid (mem_rsp_valid),
        .rsp_data  (mem_rsp_data),
        .rsp_info  (mem_rsp_info),
        .rsp_ready (mem_rsp_ready)
    );

    // apply sampler

    wire sampler_rsp_valid;
    wire [NUM_LANES-1:0][31:0] sampler_rsp_data;
    wire [TAG_WIDTH-1:0] sampler_rsp_info;
    wire sampler_rsp_ready;

    VX_tex_sampler #(
        .INSTANCE_ID ($sformatf("%s-sampler", INSTANCE_ID)),
        .REQ_INFOW   (TAG_WIDTH),
        .NUM_LANES   (NUM_LANES)
    ) tex_sampler (
        .clk        (clk),
        .reset      (reset),

        // inputs
        .req_valid  (mem_rsp_valid),
        .req_data   (mem_rsp_data),
        .req_blends (mem_rsp_info[0 +: BLEND_FRAC_W]),
        .req_format (mem_rsp_info[BLEND_FRAC_W +: `TEX_FORMAT_BITS]),
        .req_info   (mem_rsp_info[(BLEND_FRAC_W + `TEX_FORMAT_BITS) +: TAG_WIDTH]),
        .req_ready  (mem_rsp_ready),

        // outputs
        .rsp_valid  (sampler_rsp_valid),
        .rsp_data   (sampler_rsp_data),
        .rsp_info   (sampler_rsp_info),
        .rsp_ready  (sampler_rsp_ready)
    );

    VX_elastic_buffer #(
        .DATAW   (NUM_LANES * 32 + TAG_WIDTH),
        .SIZE    (2),
        .OUT_REG (2) // external bus should be registered
    ) rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (sampler_rsp_valid),
        .ready_in  (sampler_rsp_ready),
        .data_in   ({sampler_rsp_data, sampler_rsp_info}),
        .data_out  ({tex_bus_if.rsp_data.texels, tex_bus_if.rsp_data.tag}),
        .valid_out (tex_bus_if.rsp_valid),
        .ready_out (tex_bus_if.rsp_ready)
    );

`ifdef PERF_ENABLE
    wire [`CLOG2(TCACHE_NUM_REQS+1)-1:0] perf_mem_req_per_cycle;
    wire [`CLOG2(TCACHE_NUM_REQS+1)-1:0] perf_mem_rsp_per_cycle;
    wire [`CLOG2(TCACHE_NUM_REQS+1)+1-1:0] perf_pending_reads_cycle;

    wire [TCACHE_NUM_REQS-1:0] perf_mem_req_fire;
    wire [TCACHE_NUM_REQS-1:0] perf_mem_rsp_fire;

    for (genvar i = 0; i < TCACHE_NUM_REQS; ++i) begin
        assign perf_mem_req_fire[i] = cache_bus_if[i].req_valid && cache_bus_if[i].req_ready;
        assign perf_mem_rsp_fire[i] = cache_bus_if[i].rsp_valid && cache_bus_if[i].rsp_ready;
    end

    `POP_COUNT(perf_mem_req_per_cycle, perf_mem_req_fire);
    `POP_COUNT(perf_mem_rsp_per_cycle, perf_mem_rsp_fire);

    reg [`PERF_CTR_BITS-1:0] perf_pending_reads;
    assign perf_pending_reads_cycle = perf_mem_req_per_cycle - perf_mem_rsp_per_cycle;

    always @(posedge clk) begin
        if (reset) begin
            perf_pending_reads <= '0;
        end else begin
            perf_pending_reads <= $signed(perf_pending_reads) + `PERF_CTR_BITS'($signed(perf_pending_reads_cycle));
        end
    end

    wire perf_stall_cycle = tex_bus_if.req_valid & ~tex_bus_if.req_ready;

    reg [`PERF_CTR_BITS-1:0] perf_mem_reads;
    reg [`PERF_CTR_BITS-1:0] perf_mem_latency;
    reg [`PERF_CTR_BITS-1:0] perf_stall_cycles;

    always @(posedge clk) begin
        if (reset) begin
            perf_mem_reads    <= '0;
            perf_mem_latency  <= '0;
            perf_stall_cycles <= '0;
        end else begin
            perf_mem_reads    <= perf_mem_reads + `PERF_CTR_BITS'(perf_mem_req_per_cycle);
            perf_mem_latency  <= perf_mem_latency + `PERF_CTR_BITS'(perf_pending_reads);
            perf_stall_cycles <= perf_stall_cycles + `PERF_CTR_BITS'(perf_stall_cycle);
        end
    end

    assign perf_tex_if.mem_reads    = perf_mem_reads;
    assign perf_tex_if.mem_latency  = perf_mem_latency;
    assign perf_tex_if.stall_cycles = perf_stall_cycles;
`endif

`ifdef DBG_TRACE_TEX
    always @(posedge clk) begin
        if (tex_bus_if.req_valid && tex_bus_if.req_ready) begin
            `TRACE(1, ("%d: %s-req: valid=%b, stage=%0d, lod=0x%0h, u=",
                    $time, INSTANCE_ID, tex_bus_if.req_data.mask, tex_bus_if.req_data.stage, tex_bus_if.req_data.lod))
            `TRACE_ARRAY1D(1, "0x%0h", tex_bus_if.req_data.coords[0], NUM_LANES)
            `TRACE(1, (", v="))
            `TRACE_ARRAY1D(1, "0x%0h", tex_bus_if.req_data.coords[1], NUM_LANES)
            `TRACE(1, (", tag=0x%0h (#%0d)\n", tex_bus_if.req_data.tag, tex_bus_if.req_data.tag[TAG_WIDTH-1 -: `UUID_WIDTH]))
        end
        if (tex_bus_if.rsp_valid && tex_bus_if.rsp_ready) begin
            `TRACE(1, ("%d: %s-rsp: texels=", $time, INSTANCE_ID))
            `TRACE_ARRAY1D(1, "0x%0h", tex_bus_if.rsp_data.texels, NUM_LANES)
            `TRACE(1, (", tag=0x%0h (#%0d)\n", tex_bus_if.rsp_data.tag, tex_bus_if.rsp_data.tag[TAG_WIDTH-1 -: `UUID_WIDTH]))
        end
    end
`endif

endmodule

///////////////////////////////////////////////////////////////////////////////

module VX_tex_unit_top import VX_gpu_pkg::*; import VX_tex_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_LANES = `NUM_THREADS,
    parameter TAG_WIDTH = `TEX_REQ_TAG_WIDTH
) (
    input wire                              clk,
    input wire                              reset,

    input wire                              dcr_write_valid,
    input wire [`VX_DCR_ADDR_WIDTH-1:0]     dcr_write_addr,
    input wire [`VX_DCR_DATA_WIDTH-1:0]     dcr_write_data,

    input  wire                             tex_req_valid,
    input  wire [NUM_LANES-1:0]             tex_req_mask,
    input  wire [1:0][NUM_LANES-1:0][31:0]  tex_req_coords,
    input  wire [NUM_LANES-1:0][`VX_TEX_LOD_BITS-1:0] tex_req_lod,
    input  wire [`VX_TEX_STAGE_BITS-1:0]    tex_req_stage,
    input  wire [TAG_WIDTH-1:0]             tex_req_tag,
    output wire                             tex_req_ready,

    output wire                             tex_rsp_valid,
    output wire [NUM_LANES-1:0][31:0]       tex_rsp_texels,
    output wire [TAG_WIDTH-1:0]             tex_rsp_tag,
    input  wire                             tex_rsp_ready,

    output wire [TCACHE_NUM_REQS-1:0]       cache_req_valid,
    output wire [TCACHE_NUM_REQS-1:0]       cache_req_rw,
    output wire [TCACHE_NUM_REQS-1:0][TCACHE_WORD_SIZE-1:0] cache_req_byteen,
    output wire [TCACHE_NUM_REQS-1:0][TCACHE_ADDR_WIDTH-1:0] cache_req_addr,
    output wire [TCACHE_NUM_REQS-1:0][TCACHE_WORD_SIZE*8-1:0] cache_req_data,
    output wire [TCACHE_NUM_REQS-1:0][TCACHE_TAG_WIDTH-1:0] cache_req_tag,
    input  wire [TCACHE_NUM_REQS-1:0]       cache_req_ready,

    input wire  [TCACHE_NUM_REQS-1:0]       cache_rsp_valid,
    input wire  [TCACHE_NUM_REQS-1:0][TCACHE_WORD_SIZE*8-1:0] cache_rsp_data,
    input wire  [TCACHE_NUM_REQS-1:0][TCACHE_TAG_WIDTH-1:0] cache_rsp_tag,
    output wire [TCACHE_NUM_REQS-1:0]       cache_rsp_ready
);

    VX_tex_perf_if perf_tex_if();

    VX_dcr_bus_if dcr_bus_if();

    assign dcr_bus_if.write_valid = dcr_write_valid;
    assign dcr_bus_if.write_addr = dcr_write_addr;
    assign dcr_bus_if.write_data = dcr_write_data;

    VX_tex_bus_if #(
        .NUM_LANES (NUM_LANES),
        .TAG_WIDTH (TAG_WIDTH)
    ) tex_bus_if();

    assign tex_bus_if.req_valid = tex_req_valid;
    assign tex_bus_if.req_data.mask = tex_req_mask;
    assign tex_bus_if.req_data.coords = tex_req_coords;
    assign tex_bus_if.req_data.lod = tex_req_lod;
    assign tex_bus_if.req_data.stage = tex_req_stage;
    assign tex_bus_if.req_data.tag = tex_req_tag;
    assign tex_req_ready = tex_bus_if.req_ready;

    assign tex_rsp_valid = tex_bus_if.rsp_valid;
    assign tex_rsp_texels = tex_bus_if.rsp_data.texels;
    assign tex_rsp_tag = tex_bus_if.rsp_data.tag;
    assign tex_bus_if.rsp_ready = tex_rsp_ready;

    VX_mem_bus_if #(
        .DATA_SIZE (TCACHE_WORD_SIZE),
        .TAG_WIDTH (TCACHE_TAG_WIDTH)
    ) cache_bus_if[TCACHE_NUM_REQS]();

    assign cache_req_valid = cache_bus_if[0].req_valid;
    assign cache_req_rw = cache_bus_if[0].req_data.rw;
    assign cache_req_byteen = cache_bus_if[0].req_data.byteen;
    assign cache_req_addr = cache_bus_if[0].req_data.addr;
    assign cache_req_data = cache_bus_if[0].req_data.data;
    assign cache_req_tag = cache_bus_if[0].req_data.tag;
    assign cache_bus_if[0].req_ready = cache_req_ready;

    assign cache_bus_if[0].rsp_valid = cache_rsp_valid;
    assign cache_bus_if[0].rsp_data.tag = cache_rsp_tag;
    assign cache_bus_if[0].rsp_data.data = cache_rsp_data;
    assign cache_rsp_ready = cache_bus_if[0].rsp_ready;

    VX_tex_unit #(
        .INSTANCE_ID (INSTANCE_ID),
        .NUM_LANES   (NUM_LANES),
        .TAG_WIDTH   (TAG_WIDTH)
    ) tex_unit (
        .clk          (clk),
        .reset        (reset),
    `ifdef PERF_ENABLE
        .perf_tex_if  (perf_tex_if),
    `endif
        .dcr_bus_if   (dcr_bus_if),
        .tex_bus_if   (tex_bus_if),
        .cache_bus_if (cache_bus_if)
    );

endmodule
