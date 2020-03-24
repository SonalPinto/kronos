// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
4KB Single Port SRAM for iCEBreaker FPGA

Features:    
    - 1K x 32
    - only word accessible (addr[1:0] is ignored)
    - Can be initialized while building

There are 30 EBR or Embedded Block Ram (256x16) in iCE40UP5K.
This module cascades 8 of them to construct the main memory for the system.
The EBR are arranged as a 4x2 grid.
*/

module icebreaker_lite_memory (
    input  logic                        clk,
    input  logic [31:0]                 addr,
    input  logic [31:0]                 wdata,
    output logic [31:0]                 rdata,
    input  logic                        en,
    input  logic                        wr_en,
    input  logic [3:0]                  wr_mask
);

// instance 1Kx32 memory - which will be inferred as EBR with appropriate muxing
logic [31:0] MEM [1024];

// There are 1K words (10b)
logic [9:0] word_addr;

// Extract word address from the physical address
assign word_addr = addr[2+:10];

always_ff @(posedge clk) begin
    if (en) begin
        if (wr_en) begin
            for (int i=0; i<4; i++) begin
                if (wr_mask[i]) MEM[word_addr][i*8+:8] <= wdata[i*8+:8];
            end
        end
        else rdata <= MEM[word_addr];
    end
end

// Initialize EBR if program is defined
`ifdef PROGRAM
    `define q(_s) `"_s`"
    initial begin
        $readmemh(`q(`PROGRAM), MEM);
    end
`endif

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , addr[31:12]
    , addr[1:0]
};
`endif

endmodule
