// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Generic Single Port SRAM

Features:    
    - Byte-accessible, 32-bit wide
    - word-aligned, i.e. addr[1:0] is ignored
    - Mask should be used to access specific bytes
    - Can be initialized while building using the macro PROGRAM

Note: For FPGA, this will be inferred as EBR
There are 30 EBR or Embedded Block Ram (256x16) in iCE40UP5K.
For each KB, this module will use 2 EBR, i.e. 4KB will use 4x2 = 8 EBR
*/

module generic_spsram #(
    parameter AWIDTH = 32,
    parameter KB = 4
)(
    input  logic                        clk,
    input  logic [AWIDTH-1:0]           addr,
    input  logic [31:0]                 wdata,
    output logic [31:0]                 rdata,
    input  logic                        en,
    input  logic                        wr_en,
    input  logic [3:0]                  mask
);

localparam NWORDS = 256 * KB;
localparam NWORDS_WIDTH = $clog2(NWORDS);

// instance (256*KB)x32 memory - which will be inferred as EBR with appropriate muxing
logic [31:0] MEM [NWORDS];

// There are 256*KB words
logic [NWORDS_WIDTH-1:0] word_addr;

// Extract word address from the physical address
assign word_addr = addr[2+:NWORDS_WIDTH];

always_ff @(posedge clk) begin
    if (en) begin
        if (wr_en) begin
            for (int i=0; i<4; i++) begin
                if (mask[i]) MEM[word_addr][i*8+:8] <= wdata[i*8+:8];
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
    , addr[AWIDTH-1:NWORDS_WIDTH]
    , addr[1:0]
};
`endif

endmodule
