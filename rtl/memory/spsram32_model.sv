// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


// Single Port 32b SRAM model


module spsram32_model #(
    parameter DEPTH = 256
)(
    input  logic                        clk,
    input  logic [31:0]                 addr,
    input  logic [31:0]                 wdata,
    output logic [31:0]                 rdata,
    input  logic                        en,
    input  logic                        wr_en,
    input  logic [3:0]                  wr_mask
);

parameter D = $clog2(DEPTH);

logic [31:0] MEM [DEPTH];

always_ff @(posedge clk) begin
    if (en) begin
        if (wr_en) begin
            for (int i=0; i<4; i++) begin
                if (wr_mask[i]) MEM[addr[D-1:0]][i*8+:8] <= wdata[i*8+:8];
            end
        end
        else rdata <= MEM[addr[D-1:0]];
    end
end

endmodule