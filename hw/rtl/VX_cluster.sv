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

`ifdef EXT_TEX_ENABLE
`include "VX_tex_define.vh"
`endif

`ifdef EXT_RASTER_ENABLE
`include "VX_raster_define.vh"
`endif

`ifdef EXT_OM_ENABLE
`include "VX_om_define.vh"
`endif

module VX_cluster import VX_gpu_pkg::*; #(
    parameter CLUSTER_ID = 0,
    parameter `STRING INSTANCE_ID = ""
) (
    `SCOPE_IO_DECL

    // Clock
    input  wire                 clk,
    input  wire                 reset,

`ifdef PERF_ENABLE
    VX_mem_perf_if.slave        mem_perf_if,
`endif

    // DCRs
    VX_dcr_bus_if.slave         dcr_bus_if,

    // Memory (TODO: Verilator bug where using mem_bus2_if name avoid a crash)
    VX_mem_bus_if.master        mem_bus2_if,

    // Status
    output wire                 busy
);

`ifdef SCOPE
    localparam scope_socket = 0;
    `SCOPE_IO_SWITCH (`NUM_SOCKETS);
`endif

`ifdef PERF_ENABLE
    VX_mem_perf_if mem_perf_tmp_if();
    assign mem_perf_tmp_if.icache  = 'x;
    assign mem_perf_tmp_if.dcache  = 'x;
    assign mem_perf_tmp_if.l3cache = mem_perf_if.l3cache;
    assign mem_perf_tmp_if.lmem    = 'x;
    assign mem_perf_tmp_if.mem     = mem_perf_if.mem;
`endif

`ifdef GBAR_ENABLE

    VX_gbar_bus_if per_socket_gbar_bus_if[`NUM_SOCKETS]();
    VX_gbar_bus_if gbar_bus_if();

    VX_gbar_arb #(
        .NUM_REQS (`NUM_SOCKETS),
        .OUT_BUF  ((`NUM_SOCKETS > 2) ? 1 : 0) // bgar_unit has no backpressure
    ) gbar_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (per_socket_gbar_bus_if),
        .bus_out_if (gbar_bus_if)
    );

    VX_gbar_unit #(
        .INSTANCE_ID ($sformatf("gbar%0d", CLUSTER_ID))
    ) gbar_unit (
        .clk         (clk),
        .reset       (reset),
        .gbar_bus_if (gbar_bus_if)
    );

`endif

`ifdef EXT_RASTER_ENABLE

    VX_raster_bus_if #(
        .NUM_LANES (`NUM_SFU_LANES)
    ) per_socket_raster_bus_if[`NUM_SOCKETS]();

`ifdef PERF_ENABLE
    VX_raster_perf_if perf_raster_if[`NUM_SOCKETS]();
`endif

`endif

`ifdef EXT_TEX_ENABLE

    VX_tex_bus_if #(
        .NUM_LANES (`NUM_SFU_LANES),
        .TAG_WIDTH (`TEX_REQ_ARB1_TAG_WIDTH)
    ) per_socket_tex_bus_if[`NUM_SOCKETS]();

`ifdef PERF_ENABLE
    VX_tex_perf_if perf_tex_if[`NUM_SOCKETS]();
`endif

`endif

`ifdef EXT_OM_ENABLE

    VX_om_bus_if #(
        .NUM_LANES (`NUM_SFU_LANES)
    ) per_socket_om_bus_if[`NUM_SOCKETS]();

`ifdef PERF_ENABLE
    VX_om_perf_if perf_om_if[`NUM_SOCKETS]();
`endif

`endif

    VX_mem_bus_if #(
        .DATA_SIZE (L2_WORD_SIZE),
        .TAG_WIDTH (L2_TAG_WIDTH)
    ) l2_mem_bus_if[L2_NUM_REQS]();

    VX_mem_bus_if #(
        .DATA_SIZE (`L1_LINE_SIZE),
        .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    ) per_socket_mem_bus_if[`NUM_SOCKETS]();

    for (genvar i = 0; i < `NUM_SOCKETS; ++i) begin
        `ASSIGN_VX_MEM_BUS_IF_X (l2_mem_bus_if[L1_MEM_L2_IDX + i], per_socket_mem_bus_if[i], L2_TAG_WIDTH, L1_MEM_ARB_TAG_WIDTH);
    end

    `RESET_RELAY (graphics_reset, reset);

    VX_graphics #(
        .CLUSTER_ID (CLUSTER_ID)
    ) graphics (
        .clk   (clk),
        .reset (graphics_reset),

    `ifdef EXT_RASTER_ENABLE
        .per_socket_raster_bus_if (per_socket_raster_bus_if),
    `ifdef PERF_ENABLE
        .perf_raster_if (perf_raster_if),
        .perf_rcache (mem_perf_tmp_if.rcache),
    `endif
        .rcache_mem_bus_if (l2_mem_bus_if[RCACHE_MEM_L2_IDX]),
    `endif

    `ifdef EXT_TEX_ENABLE
        .per_socket_tex_bus_if (per_socket_tex_bus_if),
    `ifdef PERF_ENABLE
        .perf_tex_if (perf_tex_if),
        .perf_tcache (mem_perf_tmp_if.tcache),
    `endif
        .tcache_mem_bus_if (l2_mem_bus_if[TCACHE_MEM_L2_IDX]),
    `endif

    `ifdef EXT_OM_ENABLE
        .per_socket_om_bus_if (per_socket_om_bus_if),
    `ifdef PERF_ENABLE
        .perf_om_if (perf_om_if),
        .perf_ocache (mem_perf_tmp_if.ocache),
    `endif
        .ocache_mem_bus_if (l2_mem_bus_if[OCACHE_MEM_L2_IDX]),
    `endif

        .dcr_bus_if (dcr_bus_if)
    );

    `RESET_RELAY (l2_reset, reset);

    VX_cache_wrap #(
        .INSTANCE_ID    ($sformatf("%s-l2cache", INSTANCE_ID)),
        .CACHE_SIZE     (`L2_CACHE_SIZE),
        .LINE_SIZE      (`L2_LINE_SIZE),
        .NUM_BANKS      (`L2_NUM_BANKS),
        .NUM_WAYS       (`L2_NUM_WAYS),
        .WORD_SIZE      (L2_WORD_SIZE),
        .NUM_REQS       (L2_NUM_REQS),
        .CRSQ_SIZE      (`L2_CRSQ_SIZE),
        .MSHR_SIZE      (`L2_MSHR_SIZE),
        .MRSQ_SIZE      (`L2_MRSQ_SIZE),
        .MREQ_SIZE      (`L2_WRITEBACK ? `L2_MSHR_SIZE : `L2_MREQ_SIZE),
        .TAG_WIDTH      (L2_TAG_WIDTH),
        .WRITE_ENABLE   (1),
        .WRITEBACK      (`L2_WRITEBACK),
        .DIRTY_BYTES    (`L2_WRITEBACK),
        .UUID_WIDTH     (`UUID_WIDTH),
        .CORE_OUT_BUF   (3),
        .MEM_OUT_BUF    (3),
        .NC_ENABLE      (1),
        .PASSTHRU       (!`L2_ENABLED)
    ) l2cache (
        .clk            (clk),
        .reset          (l2_reset),
    `ifdef PERF_ENABLE
        .cache_perf     (mem_perf_tmp_if.l2cache),
    `endif
        .core_bus_if    (l2_mem_bus_if),
        .mem_bus_if     (mem_bus2_if)
    );

    ///////////////////////////////////////////////////////////////////////////

    VX_dcr_bus_if socket_dcr_bus_tmp_if();
    wire is_dcr_base_addr = (dcr_bus_if.write_addr >= `VX_DCR_BASE_STATE_BEGIN && dcr_bus_if.write_addr < `VX_DCR_BASE_STATE_END);
    assign socket_dcr_bus_tmp_if.write_valid = dcr_bus_if.write_valid && is_dcr_base_addr;
    assign socket_dcr_bus_tmp_if.write_addr  = dcr_bus_if.write_addr;
    assign socket_dcr_bus_tmp_if.write_data  = dcr_bus_if.write_data;

    wire [`NUM_SOCKETS-1:0] per_socket_busy;

    VX_dcr_bus_if socket_dcr_bus_if();
    `BUFFER_DCR_BUS_IF (socket_dcr_bus_if, socket_dcr_bus_tmp_if, (`NUM_SOCKETS > 1));

    // Generate all sockets
    for (genvar socket_id = 0; socket_id < `NUM_SOCKETS; ++socket_id) begin : sockets

        `RESET_RELAY (socket_reset, reset);

        VX_socket #(
            .SOCKET_ID ((CLUSTER_ID * `NUM_SOCKETS) + socket_id),
            .INSTANCE_ID ($sformatf("%s-socket%0d", INSTANCE_ID, socket_id))
        ) socket (
            `SCOPE_IO_BIND  (scope_socket+socket_id)

            .clk            (clk),
            .reset          (socket_reset),

        `ifdef PERF_ENABLE
            .mem_perf_if    (mem_perf_tmp_if),
        `endif

            .dcr_bus_if     (socket_dcr_bus_if),

            .mem_bus_if     (per_socket_mem_bus_if[socket_id]),

        `ifdef EXT_RASTER_ENABLE
        `ifdef PERF_ENABLE
            .perf_raster_if (perf_raster_if[socket_id]),
        `endif
            .raster_bus_if  (per_socket_raster_bus_if[socket_id]),
        `endif

        `ifdef EXT_TEX_ENABLE
        `ifdef PERF_ENABLE
            .perf_tex_if    (perf_tex_if[socket_id]),
        `endif
            .tex_bus_if     (per_socket_tex_bus_if[socket_id]),
        `endif

        `ifdef EXT_OM_ENABLE
        `ifdef PERF_ENABLE
            .perf_om_if     (perf_om_if[socket_id]),
        `endif
            .om_bus_if      (per_socket_om_bus_if[socket_id]),
        `endif

        `ifdef GBAR_ENABLE
            .gbar_bus_if    (per_socket_gbar_bus_if[socket_id]),
        `endif

            .busy           (per_socket_busy[socket_id])
        );
    end

    `BUFFER_EX(busy, (| per_socket_busy), 1'b1, (`NUM_SOCKETS > 1));

endmodule
