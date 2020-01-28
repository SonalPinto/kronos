/*
   Copyright (c) 2020 Sonal Pinto <sonalpinto@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

// Single Port 32b SRAM model

module spsram32_model #(
    parameter DEPTH = 256
)(
    input  logic                        clk,
    input  logic                        rstz,
    input  logic [31:0]                 addr,
    output logic [31:0]                 data,
    input  logic                        req,
    output logic                        gnt
);

logic [31:0] MEM [DEPTH];

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        data <= '1;
        gnt <= '0;
    end
    else if (req) begin
        gnt <= 1'b1;
        data <= MEM[addr[$clog2(DEPTH)-1:0]];
    end
    else gnt <= 1'b0;
end
endmodule