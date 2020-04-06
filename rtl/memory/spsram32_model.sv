// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

// 32-bit byte-addressable Single Port SRAM model

module spsram32_model #(
    parameter WORDS = 256
)(
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    input  logic        en,
    input  logic        wr_en,
    input  logic [3:0]  wr_mask
);

parameter D = $clog2(WORDS);

logic [31:0] MEM [WORDS];
logic [D-1:0] adr;

assign adr = addr[2+:D];

always_ff @(posedge clk) begin
    if (en) begin
        if (wr_en) begin
            for (int i=0; i<4; i++) begin
                if (wr_mask[i]) MEM[adr][i*8+:8] <= wdata[i*8+:8];
            end
        end
        else rdata <= MEM[adr];
    end
end

endmodule