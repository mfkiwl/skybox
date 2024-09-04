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

`include "VX_om_define.vh"

// Module for handling memory requests
module VX_om_mem import VX_gpu_pkg::*; import VX_om_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_LANES = 4,
    parameter TAG_WIDTH = 1
) (
    input wire clk,
    input wire reset,

    // Device configuration
    input om_dcrs_t dcrs,

    // Memory interface
    VX_mem_bus_if.master                            cache_bus_if [OCACHE_NUM_REQS],

    // Request interface
    input wire                                      req_valid,
    input wire [NUM_LANES-1:0]                      req_ds_mask,
    input wire [NUM_LANES-1:0]                      req_c_mask,
    input wire                                      req_rw,
    input wire [NUM_LANES-1:0][`VX_OM_DIM_BITS-1:0] req_pos_x,
    input wire [NUM_LANES-1:0][`VX_OM_DIM_BITS-1:0] req_pos_y,
    input rgba_t [NUM_LANES-1:0]                    req_color,
    input wire [NUM_LANES-1:0][`VX_OM_DEPTH_BITS-1:0] req_depth,
    input wire [NUM_LANES-1:0][`VX_OM_STENCIL_BITS-1:0] req_stencil,
    input wire [NUM_LANES-1:0]                      req_face,
    input wire [TAG_WIDTH-1:0]                      req_tag,
    output wire                                     req_ready,
    output wire                                     write_notify,

    // Response interface
    output wire                                     rsp_valid,
    output wire [NUM_LANES-1:0]                     rsp_mask,
    output rgba_t [NUM_LANES-1:0]                   rsp_color,
    output wire [NUM_LANES-1:0][`VX_OM_DEPTH_BITS-1:0] rsp_depth,
    output wire [NUM_LANES-1:0][`VX_OM_STENCIL_BITS-1:0] rsp_stencil,
    output wire [TAG_WIDTH-1:0]                     rsp_tag,
    input wire                                      rsp_ready
);

    localparam NUM_REQS    = OM_MEM_REQS;
    localparam W_ADDR_BITS = (`OM_ADDR_BITS + 6) - 2;

    wire                        mreq_valid, mreq_valid_r;
    wire                        mreq_rw, mreq_rw_r;
    wire [NUM_REQS-1:0]         mreq_mask, mreq_mask_r;
    wire [NUM_REQS-1:0][OCACHE_ADDR_WIDTH-1:0] mreq_addr, mreq_addr_r;
    wire [NUM_REQS-1:0][31:0]   mreq_data, mreq_data_r;
    wire [NUM_REQS-1:0][3:0]    mreq_byteen, mreq_byteen_r;
    wire [TAG_WIDTH-1:0]        mreq_tag, mreq_tag_r;
    wire                        mreq_ready_r;
    wire                        mreq_stall;

    wire                        mrsp_valid;
    wire [NUM_REQS-1:0]         mrsp_mask;
    wire [NUM_REQS-1:0][31:0]   mrsp_data;
    wire [TAG_WIDTH-1:0]        mrsp_tag;
    wire                        mrsp_ready;

    `UNUSED_VAR (dcrs)

    wire [3:0] color_byteen = dcrs.cbuf_writemask;
    wire [2:0] depth_byteen = {3{dcrs.depth_writemask}};
    wire [NUM_LANES-1:0] stencil_byteen;
    for (genvar i = 0;  i < NUM_LANES; ++i) begin
        assign stencil_byteen[i] = (dcrs.stencil_writemask[req_face[i]] != 0);
    end

    wire mul_enable;

    // depth/stencil values submission
    for (genvar i = 0;  i < NUM_LANES; ++i) begin
        wire [31:0] m_y_pitch;
        `UNUSED_VAR (m_y_pitch)

        VX_multiplier #(
            .A_WIDTH (`VX_OM_DIM_BITS),
            .B_WIDTH (`VX_OM_PITCH_BITS),
            .R_WIDTH (32),
            .LATENCY (`LATENCY_IMUL)
        ) multiplier (
            .clk    (clk),
            .enable (mul_enable),
            .dataa  (req_pos_y[i]),
            .datab  (dcrs.zbuf_pitch),
            .result (m_y_pitch)
        );

        wire [W_ADDR_BITS-1:0] baddr, baddr_s;
        assign baddr = {dcrs.zbuf_addr, 4'b0} + W_ADDR_BITS'(req_pos_x[i]);

        wire [3:0] byteen = req_rw ? {stencil_byteen[i], depth_byteen} : 4'b1111;
        wire [31:0] data = {req_stencil[i], req_depth[i]};
        wire mask = req_ds_mask[i];

        VX_shift_register #(
            .DATAW (1 + 4 + W_ADDR_BITS + 32),
            .DEPTH (`LATENCY_IMUL)
        ) shift_reg (
            .clk      (clk),
            `UNUSED_PIN (reset),
            .enable   (mul_enable),
            .data_in  ({mask,         byteen,         baddr,   data}),
            .data_out ({mreq_mask[i], mreq_byteen[i], baddr_s, mreq_data[i]})
        );

        wire [W_ADDR_BITS-1:0] addr = baddr_s + W_ADDR_BITS'(m_y_pitch[31:2]);
        assign mreq_addr[i] = OCACHE_ADDR_WIDTH'(addr);
    end

    // blend color submission
    for (genvar i = NUM_LANES; i < NUM_REQS; ++i) begin
        wire [31:0] m_y_pitch;
        `UNUSED_VAR (m_y_pitch)

        VX_multiplier #(
            .A_WIDTH (`VX_OM_DIM_BITS),
            .B_WIDTH (`VX_OM_PITCH_BITS),
            .R_WIDTH (32),
            .LATENCY (`LATENCY_IMUL)
        ) multiplier (
            .clk    (clk),
            .enable (mul_enable),
            .dataa  (req_pos_y[i - NUM_LANES]),
            .datab  (dcrs.cbuf_pitch),
            .result (m_y_pitch)
        );

        wire [W_ADDR_BITS-1:0] baddr, baddr_s;
        assign baddr = {dcrs.cbuf_addr, 4'b0} + W_ADDR_BITS'(req_pos_x[i - NUM_LANES]);

        wire [3:0]  byteen = req_rw ? color_byteen : 4'b1111;
        wire [31:0] data = req_color[i - NUM_LANES];
        wire mask = req_c_mask[i - NUM_LANES];

        VX_shift_register #(
            .DATAW (1 + 4 + W_ADDR_BITS + 32),
            .DEPTH (`LATENCY_IMUL)
        ) shift_reg (
            .clk      (clk),
            `UNUSED_PIN (reset),
            .enable   (mul_enable),
            .data_in  ({mask,         byteen,         baddr,    data}),
            .data_out ({mreq_mask[i], mreq_byteen[i], baddr_s,  mreq_data[i]})
        );

        wire [W_ADDR_BITS-1:0] addr = baddr_s + W_ADDR_BITS'(m_y_pitch[31:2]);
        assign mreq_addr[i] = OCACHE_ADDR_WIDTH'(addr);
    end

    VX_shift_register #(
        .DATAW  (1 + 1 + TAG_WIDTH),
        .DEPTH  (`LATENCY_IMUL),
        .RESETW (1)
    ) shift_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (mul_enable),
        .data_in  ({req_valid,  req_rw,  req_tag}),
        .data_out ({mreq_valid, mreq_rw, mreq_tag})
    );

    assign req_ready = mul_enable;

    assign mul_enable = ~(mreq_valid && mreq_stall);

    VX_pipe_register #(
        .DATAW	(1 + 1 + NUM_REQS * (1 + 4 + OCACHE_ADDR_WIDTH + 32) + TAG_WIDTH),
        .RESETW (1)
    ) mreq_pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable	  (~mreq_stall),
        .data_in  ({mreq_valid,   mreq_rw,   mreq_mask,   mreq_byteen,   mreq_addr,   mreq_data,   mreq_tag}),
        .data_out ({mreq_valid_r, mreq_rw_r, mreq_mask_r, mreq_byteen_r, mreq_addr_r, mreq_data_r, mreq_tag_r})
    );

    assign mreq_stall = mreq_valid_r && ~mreq_ready_r;

    VX_lsu_mem_if #(
        .NUM_LANES (OCACHE_NUM_REQS),
        .DATA_SIZE (4),
        .TAG_WIDTH (OCACHE_TAG_WIDTH)
    ) mem_bus_if();

    VX_mem_scheduler #(
        .INSTANCE_ID  ($sformatf("%s-memsched", INSTANCE_ID)),
        .CORE_REQS    (NUM_REQS),
        .MEM_CHANNELS (OCACHE_NUM_REQS),
        .WORD_SIZE    (4),
        .ADDR_WIDTH   (OCACHE_ADDR_WIDTH),
        .FLAGS_WIDTH  (`MEM_REQ_FLAGS_WIDTH),
        .TAG_WIDTH    (TAG_WIDTH),
        .CORE_QUEUE_SIZE(`OM_MEM_QUEUE_SIZE),
        .UUID_WIDTH   (`UUID_WIDTH),
        .RSP_PARTIAL  (0),
        .MEM_OUT_BUF  (0),
        .CORE_OUT_BUF (2)
    ) mem_scheduler (
        .clk            (clk),
        .reset          (reset),

        // Input request
        .core_req_valid (mreq_valid_r),
        .core_req_rw    (mreq_rw_r),
        .core_req_mask  (mreq_mask_r),
        .core_req_byteen(mreq_byteen_r),
        .core_req_addr  (mreq_addr_r),
        .core_req_flags ((NUM_REQS*`MEM_REQ_FLAGS_WIDTH)'(0)),
        .core_req_data  (mreq_data_r),
        .core_req_tag   (mreq_tag_r),
        `UNUSED_PIN (core_req_empty),
        .core_req_ready (mreq_ready_r),
        .core_write_notify  (write_notify),

        // Output response
        .core_rsp_valid (mrsp_valid),
        .core_rsp_mask  (mrsp_mask),
        .core_rsp_data  (mrsp_data),
        .core_rsp_tag   (mrsp_tag),
        `UNUSED_PIN (core_rsp_sop),
        `UNUSED_PIN (core_rsp_eop),
        .core_rsp_ready (mrsp_ready),

        // Memory request
        .mem_req_valid  (mem_bus_if.req_valid),
        .mem_req_rw     (mem_bus_if.req_data.rw),
        .mem_req_mask   (mem_bus_if.req_data.mask),
        .mem_req_byteen (mem_bus_if.req_data.byteen),
        .mem_req_addr   (mem_bus_if.req_data.addr),
        .mem_req_flags  (mem_bus_if.req_data.flags),
        .mem_req_data   (mem_bus_if.req_data.data),
        .mem_req_tag    (mem_bus_if.req_data.tag),
        .mem_req_ready  (mem_bus_if.req_ready),

        // Memory response
        .mem_rsp_valid  (mem_bus_if.rsp_valid),
        .mem_rsp_mask   (mem_bus_if.rsp_data.mask),
        .mem_rsp_data   (mem_bus_if.rsp_data.data),
        .mem_rsp_tag    (mem_bus_if.rsp_data.tag),
        .mem_rsp_ready  (mem_bus_if.rsp_ready)
    );

    VX_lsu_adapter #(
        .NUM_LANES    (OCACHE_NUM_REQS),
        .DATA_SIZE    (4),
        .TAG_WIDTH    (OCACHE_TAG_WIDTH),
        .TAG_SEL_BITS (OCACHE_TAG_WIDTH - `UUID_WIDTH),
        .REQ_OUT_BUF  (0),
        .RSP_OUT_BUF  (0)
    ) lsu_adapter (
        .clk        (clk),
        .reset      (reset),
        .lsu_mem_if (mem_bus_if),
        .mem_bus_if (cache_bus_if)
    );

    assign rsp_valid = mrsp_valid;

    assign rsp_mask = (mrsp_mask[0 +: NUM_LANES] | mrsp_mask[NUM_LANES +: NUM_LANES]);

    for (genvar i = 0;  i < NUM_LANES; ++i) begin
        assign rsp_depth[i]   = `VX_OM_DEPTH_BITS'(mrsp_data[i] >> 0) & `VX_OM_DEPTH_BITS'(`VX_OM_DEPTH_MASK);
        assign rsp_stencil[i] = `VX_OM_STENCIL_BITS'(mrsp_data[i] >> `VX_OM_DEPTH_BITS) & `VX_OM_STENCIL_BITS'(`VX_OM_STENCIL_MASK);
    end

    for (genvar i = NUM_LANES; i < NUM_REQS; ++i) begin
        assign rsp_color[i - NUM_LANES] = mrsp_data[i];
    end

    assign rsp_tag = mrsp_tag;

    assign mrsp_ready = rsp_ready;

endmodule
