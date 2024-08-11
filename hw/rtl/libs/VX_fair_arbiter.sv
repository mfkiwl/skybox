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

`include "VX_platform.vh"

`TRACING_OFF
module VX_fair_arbiter #(
    parameter NUM_REQS     = 1,
    parameter LOG_NUM_REQS = `LOG2UP(NUM_REQS)
) (
    input  wire                     clk,
    input  wire                     reset,
    input  wire [NUM_REQS-1:0]      requests,
    output wire [LOG_NUM_REQS-1:0]  grant_index,
    output wire [NUM_REQS-1:0]      grant_onehot,
    output wire                     grant_valid,
    input  wire                     grant_ready
);
    if (NUM_REQS == 1)  begin

        `UNUSED_VAR (clk)
        `UNUSED_VAR (reset)
        `UNUSED_VAR (grant_ready)

        assign grant_index  = '0;
        assign grant_onehot = requests;
        assign grant_valid  = requests[0];

    end else begin

        reg [NUM_REQS-1:0] reqs_mask;

        wire [NUM_REQS-1:0] masked_reqs = requests & reqs_mask;
        wire [NUM_REQS-1:0] requests_qual = (| masked_reqs) ? masked_reqs : requests;

        always @(posedge clk) begin
            if (reset) begin
                reqs_mask <= '1;
            end else if (grant_valid && grant_ready) begin
                reqs_mask <= (| reqs_mask) ? (reqs_mask & ~grant_onehot) : ~grant_onehot;
            end
        end

        VX_priority_encoder #(
            .N (NUM_REQS)
        ) priority_enc (
            .data_in    (requests_qual),
            .index_out  (grant_index),
            .onehot_out (grant_onehot),
            .valid_out  (grant_valid)
        );

    end

endmodule
`TRACING_ON
