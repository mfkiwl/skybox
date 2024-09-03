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

`include "VX_define.vh"

module VX_sfu_unit import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,

`ifdef PERF_ENABLE
    VX_mem_perf_if.slave    mem_perf_if,
    VX_pipeline_perf_if.slave pipeline_perf_if,
`endif

    input base_dcrs_t       base_dcrs,

    // Inputs
    VX_dispatch_if.slave    dispatch_if [`ISSUE_WIDTH],

`ifdef EXT_F_ENABLE
    VX_fpu_csr_if.slave     fpu_csr_if [`NUM_FPU_BLOCKS],
`endif
    VX_commit_csr_if.slave  commit_csr_if,
    VX_sched_csr_if.slave   sched_csr_if,

`ifdef EXT_TEX_ENABLE
    VX_tex_bus_if.master    tex_bus_if,
`ifdef PERF_ENABLE
    VX_tex_perf_if.slave    perf_tex_if,
`endif
`endif

`ifdef EXT_RASTER_ENABLE
    VX_raster_bus_if.slave  raster_bus_if,
`ifdef PERF_ENABLE
    VX_raster_perf_if.slave perf_raster_if,
`endif
`endif

`ifdef EXT_OM_ENABLE
    VX_om_bus_if.master     om_bus_if,
`ifdef PERF_ENABLE
    VX_om_perf_if.slave     perf_om_if,
`endif
`endif

    // Outputs
    VX_commit_if.master     commit_if [`ISSUE_WIDTH],
    VX_warp_ctl_if.master   warp_ctl_if
);
   `UNUSED_SPARAM (INSTANCE_ID)
    localparam BLOCK_SIZE   = 1;
    localparam NUM_LANES    = `NUM_SFU_LANES;
    localparam PE_COUNT     = 1 + 1 + `EXT_TEX_ENABLED + `EXT_RASTER_ENABLED + `EXT_OM_ENABLED;
    localparam PE_SEL_BITS  = `CLOG2(PE_COUNT);
    localparam PE_IDX_WCTL  = 0;
    localparam PE_IDX_CSRS  = 1;
    localparam PE_IDX_RASTER= PE_IDX_CSRS + `EXT_RASTER_ENABLED;
    localparam PE_IDX_OM    = PE_IDX_RASTER + `EXT_OM_ENABLED;
    localparam PE_IDX_TEX   = PE_IDX_OM + `EXT_TEX_ENABLED;

    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_execute_if[BLOCK_SIZE]();

    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_commit_if[BLOCK_SIZE]();

    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (3)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (reset),
        .dispatch_if(dispatch_if),
        .execute_if (per_block_execute_if)
    );

    // Warp control block
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) pe_execute_if[PE_COUNT]();

    VX_commit_if#(
        .NUM_LANES (NUM_LANES)
    ) pe_commit_if[PE_COUNT]();

    reg [PE_SEL_BITS-1:0] pe_select;
    always @(*) begin
        pe_select = PE_IDX_WCTL;
        if (`INST_SFU_IS_CSR(per_block_execute_if[0].data.op_type))
            pe_select = PE_IDX_CSRS;
        else if (per_block_execute_if[0].data.op_type == `INST_SFU_TEX)
            pe_select = PE_IDX_TEX;
        else if (per_block_execute_if[0].data.op_type == `INST_SFU_OM)
            pe_select = PE_IDX_OM;
        else if (per_block_execute_if[0].data.op_type == `INST_SFU_RASTER)
            pe_select = PE_IDX_RASTER;
    end

    VX_pe_switch #(
        .PE_COUNT   (PE_COUNT),
        .NUM_LANES  (NUM_LANES),
        .ARBITER    ("R"),
        .REQ_OUT_BUF(0),
        .RSP_OUT_BUF(3)
    ) pe_switch (
        .clk        (clk),
        .reset      (reset),
        .pe_sel     (pe_select),
        .execute_in_if (per_block_execute_if[0]),
        .commit_out_if (per_block_commit_if[0]),
        .execute_out_if (pe_execute_if),
        .commit_in_if (pe_commit_if)
    );

    `RESET_RELAY (wctl_reset, reset);

    VX_wctl_unit #(
        .INSTANCE_ID ($sformatf("%s-wctl", INSTANCE_ID)),
        .NUM_LANES (NUM_LANES)
    ) wctl_unit (
        .clk        (clk),
        .reset      (wctl_reset),
        .execute_if (pe_execute_if[PE_IDX_WCTL]),
        .warp_ctl_if(warp_ctl_if),
        .commit_if  (pe_commit_if[PE_IDX_WCTL])
    );

`ifdef EXT_TEX_ENABLE
    VX_sfu_csr_if tex_csr_if();
`endif

`ifdef EXT_RASTER_ENABLE
    VX_sfu_csr_if raster_csr_if();
`endif

`ifdef EXT_OM_ENABLE
    VX_sfu_csr_if om_csr_if();
`endif

    `RESET_RELAY (csr_reset, reset);

    VX_csr_unit #(
        .INSTANCE_ID ($sformatf("%s-csr", INSTANCE_ID)),
        .CORE_ID   (CORE_ID),
        .NUM_LANES (NUM_LANES)
    ) csr_unit (
        .clk            (clk),
        .reset          (csr_reset),

        .base_dcrs      (base_dcrs),

    `ifdef PERF_ENABLE
        .mem_perf_if    (mem_perf_if),
        .pipeline_perf_if(pipeline_perf_if),
    `endif

    `ifdef EXT_TEX_ENABLE
        .tex_csr_if     (tex_csr_if),
    `ifdef PERF_ENABLE
        .perf_tex_if    (perf_tex_if),
    `endif
    `endif

    `ifdef EXT_RASTER_ENABLE
        .raster_csr_if  (raster_csr_if),
    `ifdef PERF_ENABLE
        .perf_raster_if (perf_raster_if),
    `endif
    `endif

    `ifdef EXT_OM_ENABLE
        .om_csr_if      (om_csr_if),
    `ifdef PERF_ENABLE
        .perf_om_if     (perf_om_if),
    `endif
    `endif

    `ifdef EXT_F_ENABLE
        .fpu_csr_if     (fpu_csr_if),
    `endif

        .sched_csr_if   (sched_csr_if),
        .commit_csr_if  (commit_csr_if),
        .execute_if     (pe_execute_if[PE_IDX_CSRS]),
        .commit_if      (pe_commit_if[PE_IDX_CSRS])
    );

`ifdef EXT_TEX_ENABLE

    `RESET_RELAY (tex_reset, reset);

    VX_tex_agent #(
        .CORE_ID   (CORE_ID),
        .NUM_LANES (NUM_LANES)
    ) tex_agent (
        .clk        (clk),
        .reset      (tex_reset),
        .execute_if (pe_execute_if[PE_IDX_TEX]),
        .tex_csr_if (tex_csr_if),
        .tex_bus_if (tex_bus_if),
        .commit_if  (pe_commit_if[PE_IDX_TEX])
    );

`endif

`ifdef EXT_RASTER_ENABLE

    `RESET_RELAY (raster_reset, reset);

    VX_raster_agent #(
        .CORE_ID   (CORE_ID),
        .NUM_LANES (NUM_LANES)
    ) raster_agent (
        .clk        (clk),
        .reset      (raster_reset),
        .execute_if (pe_execute_if[PE_IDX_RASTER]),
        .raster_csr_if(raster_csr_if),
        .raster_bus_if(raster_bus_if),
        .commit_if  (pe_commit_if[PE_IDX_RASTER])
    );

`endif

`ifdef EXT_OM_ENABLE

    `RESET_RELAY (om_reset, reset);

    VX_om_agent #(
        .CORE_ID   (CORE_ID),
        .NUM_LANES (NUM_LANES)
    ) om_agent (
        .clk        (clk),
        .reset      (om_reset),
        .execute_if (pe_execute_if[PE_IDX_OM]),
        .om_csr_if  (om_csr_if),
        .om_bus_if  (om_bus_if),
        .commit_if  (pe_commit_if[PE_IDX_OM])
    );

`endif

    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (3)
    ) gather_unit (
        .clk        (clk),
        .reset      (reset),
        .commit_in_if (per_block_commit_if),
        .commit_out_if (commit_if)
    );

endmodule
