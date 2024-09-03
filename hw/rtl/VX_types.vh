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

`ifndef VX_TYPES_VH
`define VX_TYPES_VH

// Device configuration registers /////////////////////////////////////////////

`define VX_CSR_ADDR_BITS                12
`define VX_DCR_ADDR_BITS                12

`define VX_DCR_BASE_STATE_BEGIN         12'h001
`define VX_DCR_BASE_STARTUP_ADDR0       12'h001
`define VX_DCR_BASE_STARTUP_ADDR1       12'h002
`define VX_DCR_BASE_STARTUP_ARG0        12'h003
`define VX_DCR_BASE_STARTUP_ARG1        12'h004
`define VX_DCR_BASE_MPM_CLASS           12'h005
`define VX_DCR_BASE_STATE_END           12'h006

`define VX_DCR_BASE_STATE(addr)         ((addr) - `VX_DCR_BASE_STATE_BEGIN)
`define VX_DCR_BASE_STATE_COUNT         (`VX_DCR_BASE_STATE_END-`VX_DCR_BASE_STATE_BEGIN)

// Machine Performance-monitoring counters classes ////////////////////////////

`define VX_DCR_MPM_CLASS_NONE           0
`define VX_DCR_MPM_CLASS_CORE           1
`define VX_DCR_MPM_CLASS_MEM            2
`define VX_DCR_MPM_CLASS_TEX            3
`define VX_DCR_MPM_CLASS_RASTER         4
`define VX_DCR_MPM_CLASS_OM             5

// User Floating-Point CSRs ///////////////////////////////////////////////////

`define VX_CSR_FFLAGS                   12'h001
`define VX_CSR_FRM                      12'h002
`define VX_CSR_FCSR                     12'h003

`define VX_CSR_SATP                     12'h180

`define VX_CSR_PMPCFG0                  12'h3A0
`define VX_CSR_PMPADDR0                 12'h3B0

`define VX_CSR_MSTATUS                  12'h300
`define VX_CSR_MISA                     12'h301
`define VX_CSR_MEDELEG                  12'h302
`define VX_CSR_MIDELEG                  12'h303
`define VX_CSR_MIE                      12'h304
`define VX_CSR_MTVEC                    12'h305

`define VX_CSR_MSCRATCH                 12'h340
`define VX_CSR_MEPC                     12'h341
`define VX_CSR_MCAUSE                   12'h342

`define VX_CSR_MNSTATUS                 12'h744

`define VX_CSR_MPM_BASE                 12'hB00
`define VX_CSR_MPM_BASE_H               12'hB80
`define VX_CSR_MPM_USER                 12'hB03
`define VX_CSR_MPM_USER_H               12'hB83

// Machine Performance-monitoring core counters (Standard) ////////////////////

`define VX_CSR_MCYCLE                   12'hB00
`define VX_CSR_MCYCLE_H                 12'hB80
`define VX_CSR_MPM_RESERVED             12'hB01
`define VX_CSR_MPM_RESERVED_H           12'hB81
`define VX_CSR_MINSTRET                 12'hB02
`define VX_CSR_MINSTRET_H               12'hB82

// Machine Performance-monitoring core counters (class 1) /////////////////////

// PERF: pipeline
`define VX_CSR_MPM_SCHED_ID             12'hB03
`define VX_CSR_MPM_SCHED_ID_H           12'hB83
`define VX_CSR_MPM_SCHED_ST             12'hB04
`define VX_CSR_MPM_SCHED_ST_H           12'hB84
`define VX_CSR_MPM_IBUF_ST              12'hB05
`define VX_CSR_MPM_IBUF_ST_H            12'hB85
`define VX_CSR_MPM_SCRB_ST              12'hB06
`define VX_CSR_MPM_SCRB_ST_H            12'hB86
`define VX_CSR_MPM_SCRB_ALU             12'hB07
`define VX_CSR_MPM_SCRB_ALU_H           12'hB87
`define VX_CSR_MPM_SCRB_FPU             12'hB08
`define VX_CSR_MPM_SCRB_FPU_H           12'hB88
`define VX_CSR_MPM_SCRB_LSU             12'hB09
`define VX_CSR_MPM_SCRB_LSU_H           12'hB89
`define VX_CSR_MPM_SCRB_SFU             12'hB0A
`define VX_CSR_MPM_SCRB_SFU_H           12'hB8A
`define VX_CSR_MPM_OPDS_ST              12'hB0B
`define VX_CSR_MPM_OPDS_ST_H            12'hB8B
// PERF: memory
`define VX_CSR_MPM_IFETCHES             12'hB0C
`define VX_CSR_MPM_IFETCHES_H           12'hB8C
`define VX_CSR_MPM_LOADS                12'hB0D
`define VX_CSR_MPM_LOADS_H              12'hB8D
`define VX_CSR_MPM_STORES               12'hB0E
`define VX_CSR_MPM_STORES_H             12'hB8E
`define VX_CSR_MPM_IFETCH_LT            12'hB1F
`define VX_CSR_MPM_IFETCH_LT_H          12'hB9F
`define VX_CSR_MPM_LOAD_LT              12'hB10
`define VX_CSR_MPM_LOAD_LT_H            12'hB90
// SFU: scoreboard
`define VX_CSR_MPM_SCRB_WCTL            12'hB11
`define VX_CSR_MPM_SCRB_WCTL_H          12'hB91
`define VX_CSR_MPM_SCRB_CSRS            12'hB12
`define VX_CSR_MPM_SCRB_CSRS_H          12'hB92
`define VX_CSR_MPM_SCRB_TEX             12'hB13
`define VX_CSR_MPM_SCRB_TEX_H           12'hB93
`define VX_CSR_MPM_SCRB_OM              12'hB14
`define VX_CSR_MPM_SCRB_OM_H            12'hB94
`define VX_CSR_MPM_SCRB_RASTER          12'hB15
`define VX_CSR_MPM_SCRB_RASTER_H        12'hB95

// Machine Performance-monitoring memory counters
// PERF: icache
`define VX_CSR_MPM_ICACHE_READS         12'hB03     // total reads
`define VX_CSR_MPM_ICACHE_READS_H       12'hB83
`define VX_CSR_MPM_ICACHE_MISS_R        12'hB04     // read misses
`define VX_CSR_MPM_ICACHE_MISS_R_H      12'hB84
`define VX_CSR_MPM_ICACHE_MSHR_ST       12'hB05     // MSHR stalls
`define VX_CSR_MPM_ICACHE_MSHR_ST_H     12'hB85
// PERF: dcache
`define VX_CSR_MPM_DCACHE_READS         12'hB06     // total reads
`define VX_CSR_MPM_DCACHE_READS_H       12'hB86
`define VX_CSR_MPM_DCACHE_WRITES        12'hB07     // total writes
`define VX_CSR_MPM_DCACHE_WRITES_H      12'hB87
`define VX_CSR_MPM_DCACHE_MISS_R        12'hB08     // read misses
`define VX_CSR_MPM_DCACHE_MISS_R_H      12'hB88
`define VX_CSR_MPM_DCACHE_MISS_W        12'hB09     // write misses
`define VX_CSR_MPM_DCACHE_MISS_W_H      12'hB89
`define VX_CSR_MPM_DCACHE_BANK_ST       12'hB0A     // bank conflicts
`define VX_CSR_MPM_DCACHE_BANK_ST_H     12'hB8A
`define VX_CSR_MPM_DCACHE_MSHR_ST       12'hB0B     // MSHR stalls
`define VX_CSR_MPM_DCACHE_MSHR_ST_H     12'hB8B
// PERF: l2cache
`define VX_CSR_MPM_L2CACHE_READS        12'hB0C     // total reads
`define VX_CSR_MPM_L2CACHE_READS_H      12'hB8C
`define VX_CSR_MPM_L2CACHE_WRITES       12'hB0D     // total writes
`define VX_CSR_MPM_L2CACHE_WRITES_H     12'hB8D
`define VX_CSR_MPM_L2CACHE_MISS_R       12'hB0E     // read misses
`define VX_CSR_MPM_L2CACHE_MISS_R_H     12'hB8E
`define VX_CSR_MPM_L2CACHE_MISS_W       12'hB0F     // write misses
`define VX_CSR_MPM_L2CACHE_MISS_W_H     12'hB8F
`define VX_CSR_MPM_L2CACHE_BANK_ST      12'hB10     // bank conflicts
`define VX_CSR_MPM_L2CACHE_BANK_ST_H    12'hB90
`define VX_CSR_MPM_L2CACHE_MSHR_ST      12'hB11     // MSHR stalls
`define VX_CSR_MPM_L2CACHE_MSHR_ST_H    12'hB91
// PERF: l3cache
`define VX_CSR_MPM_L3CACHE_READS        12'hB12     // total reads
`define VX_CSR_MPM_L3CACHE_READS_H      12'hB92
`define VX_CSR_MPM_L3CACHE_WRITES       12'hB13     // total writes
`define VX_CSR_MPM_L3CACHE_WRITES_H     12'hB93
`define VX_CSR_MPM_L3CACHE_MISS_R       12'hB14     // read misses
`define VX_CSR_MPM_L3CACHE_MISS_R_H     12'hB94
`define VX_CSR_MPM_L3CACHE_MISS_W       12'hB15     // write misses
`define VX_CSR_MPM_L3CACHE_MISS_W_H     12'hB95
`define VX_CSR_MPM_L3CACHE_BANK_ST      12'hB16     // bank conflicts
`define VX_CSR_MPM_L3CACHE_BANK_ST_H    12'hB96
`define VX_CSR_MPM_L3CACHE_MSHR_ST      12'hB17     // MSHR stalls
`define VX_CSR_MPM_L3CACHE_MSHR_ST_H    12'hB97
// PERF: memory
`define VX_CSR_MPM_MEM_READS            12'hB18     // total reads
`define VX_CSR_MPM_MEM_READS_H          12'hB98
`define VX_CSR_MPM_MEM_WRITES           12'hB19     // total writes
`define VX_CSR_MPM_MEM_WRITES_H         12'hB99
`define VX_CSR_MPM_MEM_LT               12'hB1A     // memory latency
`define VX_CSR_MPM_MEM_LT_H             12'hB9A
`define VX_CSR_MPM_MEM_BANK_CNTR        12'hB1E     // memory bank requests
`define VX_CSR_MPM_MEM_BANK_CNTR_H      12'hB9E
`define VX_CSR_MPM_MEM_BANK_TICK        12'hB1F     // memory ticks
`define VX_CSR_MPM_MEM_BANK_TICK_H      12'hB9F
// PERF: lmem
`define VX_CSR_MPM_LMEM_READS           12'hB1B     // memory reads
`define VX_CSR_MPM_LMEM_READS_H         12'hB9B
`define VX_CSR_MPM_LMEM_WRITES          12'hB1C     // memory writes
`define VX_CSR_MPM_LMEM_WRITES_H        12'hB9C
`define VX_CSR_MPM_LMEM_BANK_ST         12'hB1D     // bank conflicts
`define VX_CSR_MPM_LMEM_BANK_ST_H       12'hB9D

// Machine Performance-monitoring memory counters (class 3) ///////////////////
// <Add your own counters: use addresses hB03..B1F, hB83..hB9F>

// Machine Performance-monitoring texture counters
// PERF: texture unit
`define VX_CSR_MPM_TEX_READS            12'hB03     // texture accesses
`define VX_CSR_MPM_TEX_READS_H          12'hB83
`define VX_CSR_MPM_TEX_LAT              12'hB04     // texture latency
`define VX_CSR_MPM_TEX_LAT_H            12'hB84
`define VX_CSR_MPM_TEX_ST               12'hB05     // texture latency
`define VX_CSR_MPM_TEX_ST_H             12'hB85
// PERF: texture cache
`define VX_CSR_MPM_TCACHE_READS         12'hB06     // total reads
`define VX_CSR_MPM_TCACHE_READS_H       12'hB86
`define VX_CSR_MPM_TCACHE_MISS_R        12'hB07     // read misses
`define VX_CSR_MPM_TCACHE_MISS_R_H      12'hB87
`define VX_CSR_MPM_TCACHE_BANK_ST       12'hB08     // bank stalls
`define VX_CSR_MPM_TCACHE_BANK_ST_H     12'hB88
`define VX_CSR_MPM_TCACHE_MSHR_ST       12'hB09     // MSHR stalls
`define VX_CSR_MPM_TCACHE_MSHR_ST_H     12'hB89

// Machine Performance-monitoring raster counters
// PERF: raster unit
`define VX_CSR_MPM_RASTER_READS         12'hB03     // raster accesses
`define VX_CSR_MPM_RASTER_READS_H       12'hB83
`define VX_CSR_MPM_RASTER_LAT           12'hB04     // raster latency
`define VX_CSR_MPM_RASTER_LAT_H         12'hB84
`define VX_CSR_MPM_RASTER_ST            12'hB05     // raster stall cycles
`define VX_CSR_MPM_RASTER_ST_H          12'hB85
// PERF: raster cache
`define VX_CSR_MPM_RCACHE_READS         12'hB06     // total reads
`define VX_CSR_MPM_RCACHE_READS_H       12'hB86
`define VX_CSR_MPM_RCACHE_MISS_R        12'hB07     // read misses
`define VX_CSR_MPM_RCACHE_MISS_R_H      12'hB87
`define VX_CSR_MPM_RCACHE_BANK_ST       12'hB08     // bank stalls
`define VX_CSR_MPM_RCACHE_BANK_ST_H     12'hB88
`define VX_CSR_MPM_RCACHE_MSHR_ST       12'hB09     // MSHR stalls
`define VX_CSR_MPM_RCACHE_MSHR_ST_H     12'hB89

// Machine Performance-monitoring OM counters
// PERF: om unit
`define VX_CSR_MPM_OM_READS             12'hB03     // om memory reads
`define VX_CSR_MPM_OM_READS_H           12'hB83
`define VX_CSR_MPM_OM_WRITES            12'hB04     // om memory writes
`define VX_CSR_MPM_OM_WRITES_H          12'hB84
`define VX_CSR_MPM_OM_LAT               12'hB05     // om memory latency
`define VX_CSR_MPM_OM_LAT_H             12'hB85
`define VX_CSR_MPM_OM_ST                12'hB06     // om stall cycles
`define VX_CSR_MPM_OM_ST_H              12'hB86
// PERF: om cache
`define VX_CSR_MPM_OCACHE_READS         12'hB07     // total reads
`define VX_CSR_MPM_OCACHE_READS_H       12'hB87
`define VX_CSR_MPM_OCACHE_WRITES        12'hB08     // total writes
`define VX_CSR_MPM_OCACHE_WRITES_H      12'hB88
`define VX_CSR_MPM_OCACHE_MISS_R        12'hB09     // read misses
`define VX_CSR_MPM_OCACHE_MISS_R_H      12'hB89
`define VX_CSR_MPM_OCACHE_MISS_W        12'hB0A     // write misses
`define VX_CSR_MPM_OCACHE_MISS_W_H      12'hB8A
`define VX_CSR_MPM_OCACHE_BANK_ST       12'hB0B     // bank stalls
`define VX_CSR_MPM_OCACHE_BANK_ST_H     12'hB8B
`define VX_CSR_MPM_OCACHE_MSHR_ST       12'hB0C     // MSHR stalls
`define VX_CSR_MPM_OCACHE_MSHR_ST_H     12'hB8C

// Machine Information Registers //////////////////////////////////////////////

`define VX_CSR_MVENDORID                12'hF11
`define VX_CSR_MARCHID                  12'hF12
`define VX_CSR_MIMPID                   12'hF13
`define VX_CSR_MHARTID                  12'hF14

// GPGU CSRs

`define VX_CSR_THREAD_ID                12'hCC0
`define VX_CSR_WARP_ID                  12'hCC1
`define VX_CSR_CORE_ID                  12'hCC2
`define VX_CSR_ACTIVE_WARPS             12'hCC3
`define VX_CSR_ACTIVE_THREADS           12'hCC4     // warning! this value is also used in LLVM

`define VX_CSR_NUM_THREADS              12'hFC0
`define VX_CSR_NUM_WARPS                12'hFC1
`define VX_CSR_NUM_CORES                12'hFC2
`define VX_CSR_LOCAL_MEM_BASE           12'hFC3

// Raster unit CSRs

`define VX_CSR_RASTER_BEGIN             12'h7C0
`define VX_CSR_RASTER_POS_MASK          (`VX_CSR_RASTER_BEGIN+0)
`define VX_CSR_RASTER_BCOORD_X0         (`VX_CSR_RASTER_BEGIN+1)
`define VX_CSR_RASTER_BCOORD_X1         (`VX_CSR_RASTER_BEGIN+2)
`define VX_CSR_RASTER_BCOORD_X2         (`VX_CSR_RASTER_BEGIN+3)
`define VX_CSR_RASTER_BCOORD_X3         (`VX_CSR_RASTER_BEGIN+4)
`define VX_CSR_RASTER_BCOORD_Y0         (`VX_CSR_RASTER_BEGIN+5)
`define VX_CSR_RASTER_BCOORD_Y1         (`VX_CSR_RASTER_BEGIN+6)
`define VX_CSR_RASTER_BCOORD_Y2         (`VX_CSR_RASTER_BEGIN+7)
`define VX_CSR_RASTER_BCOORD_Y3         (`VX_CSR_RASTER_BEGIN+8)
`define VX_CSR_RASTER_BCOORD_Z0         (`VX_CSR_RASTER_BEGIN+9)
`define VX_CSR_RASTER_BCOORD_Z1         (`VX_CSR_RASTER_BEGIN+10)
`define VX_CSR_RASTER_BCOORD_Z2         (`VX_CSR_RASTER_BEGIN+11)
`define VX_CSR_RASTER_BCOORD_Z3         (`VX_CSR_RASTER_BEGIN+12)
`define VX_CSR_RASTER_END               (`VX_CSR_RASTER_BEGIN+13)
`define VX_CSR_RASTER_COUNT             (`VX_CSR_RASTER_END-`VX_CSR_RASTER_BEGIN)

// OM unit CSRs

`define VX_CSR_OM_BEGIN                 `VX_CSR_RASTER_END
`define VX_CSR_OM_RT_IDX                (`VX_CSR_OM_BEGIN+0)
`define VX_CSR_OM_SAMPLE_IDX            (`VX_CSR_OM_BEGIN+1)
`define VX_CSR_OM_END                   (`VX_CSR_OM_BEGIN+2)
`define VX_CSR_OM_COUNT                 (`VX_CSR_OM_END-`VX_CSR_OM_BEGIN)

// Texture unit CSRs

`define VX_CSR_TEX_BEGIN                `VX_CSR_OM_END
`define VX_CSR_TEX_END                  (`VX_CSR_TEX_BEGIN+0)
`define VX_CSR_TEX_COUNT                (`VX_CSR_TEX_END-`VX_CSR_TEX_BEGIN)

// Texture Units //////////////////////////////////////////////////////////////

`define VX_TEX_STAGE_COUNT              2
`define VX_TEX_STAGE_BITS               1

`define VX_TEX_SUBPIXEL_BITS            8

`define VX_TEX_DIM_BITS                 15
`define VX_TEX_LOD_MAX                  `VX_TEX_DIM_BITS
`define VX_TEX_LOD_BITS                 4

`define VX_TEX_FXD_BITS                 32
`define VX_TEX_FXD_FRAC                 (`VX_TEX_DIM_BITS+`VX_TEX_SUBPIXEL_BITS)

`define VX_TEX_FILTER_POINT             0
`define VX_TEX_FILTER_BILINEAR          1
`define VX_TEX_FILTER_BITS              1

`define VX_TEX_WRAP_CLAMP               0
`define VX_TEX_WRAP_REPEAT              1
`define VX_TEX_WRAP_MIRROR              2

`define VX_TEX_FORMAT_A8R8G8B8          0
`define VX_TEX_FORMAT_R5G6B5            1
`define VX_TEX_FORMAT_A1R5G5B5          2
`define VX_TEX_FORMAT_A4R4G4B4          3
`define VX_TEX_FORMAT_A8L8              4
`define VX_TEX_FORMAT_L8                5
`define VX_TEX_FORMAT_A8                6

`define VX_DCR_TEX_STATE_BEGIN          (`VX_DCR_BASE_STATE_END)
`define VX_DCR_TEX_STAGE                (`VX_DCR_TEX_STATE_BEGIN+0)
`define VX_DCR_TEX_ADDR                 (`VX_DCR_TEX_STATE_BEGIN+1)
`define VX_DCR_TEX_LOGDIM               (`VX_DCR_TEX_STATE_BEGIN+2)
`define VX_DCR_TEX_FORMAT               (`VX_DCR_TEX_STATE_BEGIN+3)
`define VX_DCR_TEX_FILTER               (`VX_DCR_TEX_STATE_BEGIN+4)
`define VX_DCR_TEX_WRAP                 (`VX_DCR_TEX_STATE_BEGIN+5)
`define VX_DCR_TEX_MIPOFF(lod)          (`VX_DCR_TEX_STATE_BEGIN+6+lod)
`define VX_DCR_TEX_STATE_END            (`VX_DCR_TEX_MIPOFF(`VX_TEX_LOD_MAX)+1)

`define VX_DCR_TEX_STATE(addr)          ((addr) - `VX_DCR_TEX_STATE_BEGIN)
`define VX_DCR_TEX_STATE_COUNT          (`VX_DCR_TEX_STATE_END-`VX_DCR_TEX_STATE_BEGIN)

// Raster Units ///////////////////////////////////////////////////////////////

`define VX_RASTER_DIM_BITS              15
`define VX_RASTER_STRIDE_BITS           16
`define VX_RASTER_PID_BITS              16
`define VX_RASTER_TILECNT_BITS          (2 * (`VX_RASTER_DIM_BITS - `VX_RASTER_TILE_LOGSIZE) + 1)

`define VX_DCR_RASTER_STATE_BEGIN       `VX_DCR_TEX_STATE_END
`define VX_DCR_RASTER_TBUF_ADDR         (`VX_DCR_RASTER_STATE_BEGIN+0)
`define VX_DCR_RASTER_TILE_COUNT        (`VX_DCR_RASTER_STATE_BEGIN+1)
`define VX_DCR_RASTER_PBUF_ADDR         (`VX_DCR_RASTER_STATE_BEGIN+2)
`define VX_DCR_RASTER_PBUF_STRIDE       (`VX_DCR_RASTER_STATE_BEGIN+3)
`define VX_DCR_RASTER_SCISSOR_X         (`VX_DCR_RASTER_STATE_BEGIN+4)
`define VX_DCR_RASTER_SCISSOR_Y         (`VX_DCR_RASTER_STATE_BEGIN+5)
`define VX_DCR_RASTER_STATE_END         (`VX_DCR_RASTER_STATE_BEGIN+6)

`define VX_DCR_RASTER_STATE(addr)       ((addr) - `VX_DCR_RASTER_STATE_BEGIN)
`define VX_DCR_RASTER_STATE_COUNT       (`VX_DCR_RASTER_STATE_END-`VX_DCR_RASTER_STATE_BEGIN)

// Render Output Units ////////////////////////////////////////////////////////

`define VX_OM_DIM_BITS                 15

`define VX_OM_PITCH_BITS               (`VX_OM_DIM_BITS + `CLOG2(4) + 1)

`define VX_OM_DEPTH_BITS               24
`define VX_OM_DEPTH_MASK               ((1 << `VX_OM_DEPTH_BITS) - 1)

`define VX_OM_STENCIL_BITS             8
`define VX_OM_STENCIL_MASK             ((1 << `VX_OM_STENCIL_BITS) - 1)

`define VX_OM_DEPTH_FUNC_ALWAYS        0
`define VX_OM_DEPTH_FUNC_NEVER         1
`define VX_OM_DEPTH_FUNC_LESS          2
`define VX_OM_DEPTH_FUNC_LEQUAL        3
`define VX_OM_DEPTH_FUNC_EQUAL         4
`define VX_OM_DEPTH_FUNC_GEQUAL        5
`define VX_OM_DEPTH_FUNC_GREATER       6
`define VX_OM_DEPTH_FUNC_NOTEQUAL      7
`define VX_OM_DEPTH_FUNC_BITS          3

`define VX_OM_STENCIL_OP_KEEP          0
`define VX_OM_STENCIL_OP_ZERO          1
`define VX_OM_STENCIL_OP_REPLACE       2
`define VX_OM_STENCIL_OP_INCR          3
`define VX_OM_STENCIL_OP_DECR          4
`define VX_OM_STENCIL_OP_INVERT        5
`define VX_OM_STENCIL_OP_INCR_WRAP     6
`define VX_OM_STENCIL_OP_DECR_WRAP     7
`define VX_OM_STENCIL_OP_BITS          3

`define VX_OM_BLEND_MODE_ADD           0
`define VX_OM_BLEND_MODE_SUB           1
`define VX_OM_BLEND_MODE_REV_SUB       2
`define VX_OM_BLEND_MODE_MIN           3
`define VX_OM_BLEND_MODE_MAX           4
`define VX_OM_BLEND_MODE_LOGICOP       5
`define VX_OM_BLEND_MODE_BITS          3

`define VX_OM_BLEND_FUNC_ZERO          0
`define VX_OM_BLEND_FUNC_ONE           1
`define VX_OM_BLEND_FUNC_SRC_RGB       2
`define VX_OM_BLEND_FUNC_ONE_MINUS_SRC_RGB 3
`define VX_OM_BLEND_FUNC_DST_RGB       4
`define VX_OM_BLEND_FUNC_ONE_MINUS_DST_RGB 5
`define VX_OM_BLEND_FUNC_SRC_A         6
`define VX_OM_BLEND_FUNC_ONE_MINUS_SRC_A   7
`define VX_OM_BLEND_FUNC_DST_A         8
`define VX_OM_BLEND_FUNC_ONE_MINUS_DST_A   9
`define VX_OM_BLEND_FUNC_CONST_RGB     10
`define VX_OM_BLEND_FUNC_ONE_MINUS_CONST_RGB 11
`define VX_OM_BLEND_FUNC_CONST_A       12
`define VX_OM_BLEND_FUNC_ONE_MINUS_CONST_A 13
`define VX_OM_BLEND_FUNC_ALPHA_SAT     14
`define VX_OM_BLEND_FUNC_BITS          4

`define VX_OM_LOGIC_OP_CLEAR           0
`define VX_OM_LOGIC_OP_AND             1
`define VX_OM_LOGIC_OP_AND_REVERSE     2
`define VX_OM_LOGIC_OP_COPY            3
`define VX_OM_LOGIC_OP_AND_INVERTED    4
`define VX_OM_LOGIC_OP_NOOP            5
`define VX_OM_LOGIC_OP_XOR             6
`define VX_OM_LOGIC_OP_OR              7
`define VX_OM_LOGIC_OP_NOR             8
`define VX_OM_LOGIC_OP_EQUIV           9
`define VX_OM_LOGIC_OP_INVERT          10
`define VX_OM_LOGIC_OP_OR_REVERSE      11
`define VX_OM_LOGIC_OP_COPY_INVERTED   12
`define VX_OM_LOGIC_OP_OR_INVERTED     13
`define VX_OM_LOGIC_OP_NAND            14
`define VX_OM_LOGIC_OP_SET             15
`define VX_OM_LOGIC_OP_BITS            4

`define VX_DCR_OM_STATE_BEGIN          `VX_DCR_RASTER_STATE_END
`define VX_DCR_OM_CBUF_ADDR            (`VX_DCR_OM_STATE_BEGIN+0)
`define VX_DCR_OM_CBUF_PITCH           (`VX_DCR_OM_STATE_BEGIN+1)
`define VX_DCR_OM_CBUF_WRITEMASK       (`VX_DCR_OM_STATE_BEGIN+2)
`define VX_DCR_OM_ZBUF_ADDR            (`VX_DCR_OM_STATE_BEGIN+3)
`define VX_DCR_OM_ZBUF_PITCH           (`VX_DCR_OM_STATE_BEGIN+4)
`define VX_DCR_OM_DEPTH_FUNC           (`VX_DCR_OM_STATE_BEGIN+5)
`define VX_DCR_OM_DEPTH_WRITEMASK      (`VX_DCR_OM_STATE_BEGIN+6)
`define VX_DCR_OM_STENCIL_FUNC         (`VX_DCR_OM_STATE_BEGIN+7)
`define VX_DCR_OM_STENCIL_ZPASS        (`VX_DCR_OM_STATE_BEGIN+8)
`define VX_DCR_OM_STENCIL_ZFAIL        (`VX_DCR_OM_STATE_BEGIN+9)
`define VX_DCR_OM_STENCIL_FAIL         (`VX_DCR_OM_STATE_BEGIN+10)
`define VX_DCR_OM_STENCIL_REF          (`VX_DCR_OM_STATE_BEGIN+11)
`define VX_DCR_OM_STENCIL_MASK         (`VX_DCR_OM_STATE_BEGIN+12)
`define VX_DCR_OM_STENCIL_WRITEMASK    (`VX_DCR_OM_STATE_BEGIN+13)
`define VX_DCR_OM_BLEND_MODE           (`VX_DCR_OM_STATE_BEGIN+14)
`define VX_DCR_OM_BLEND_FUNC           (`VX_DCR_OM_STATE_BEGIN+15)
`define VX_DCR_OM_BLEND_CONST          (`VX_DCR_OM_STATE_BEGIN+16)
`define VX_DCR_OM_LOGIC_OP             (`VX_DCR_OM_STATE_BEGIN+17)
`define VX_DCR_OM_STATE_END            (`VX_DCR_OM_STATE_BEGIN+18)

`define VX_DCR_OM_STATE(addr)          ((addr) - `VX_DCR_OM_STATE_BEGIN)
`define VX_DCR_OM_STATE_COUNT          (`VX_DCR_OM_STATE_END-`VX_DCR_OM_STATE_BEGIN)

`endif // VX_TYPES_VH
