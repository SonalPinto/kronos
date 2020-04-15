// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
64KB Single Port SRAM for iCEBreaker FPGA

Features:    
    - 16K x 32
    - Byte-accessible, 32-bit wide
    - word-aligned, i.e. addr[1:0] is ignored

There are four SP256K (16K x 16) single port SRAM hard macros in iCE40UP5K.
This module cascades 2 of them to construct a 32-bit wide memory.

Two of these can be used as two independently accessible banks of sram.

*/

module ice40up_sram64K #(
    parameter AWIDTH = 32
)(
    input  logic                        clk,
    input  logic [AWIDTH-1:0]           addr,
    input  logic [31:0]                 wdata,
    output logic [31:0]                 rdata,
    input  logic                        en,
    input  logic                        wr_en,
    input  logic [3:0]                  mask
);

// There are 16K words (14b)
logic [13:0] word_addr;

// Extract word address from the physical address
assign word_addr = addr[2+:14];

generate
    genvar j;
    for (j=0; j<2; j++) begin : MEMINST
        logic [3:0] maskwe;

        assign maskwe = {{2{mask[j*2+1]}}, {2{mask[j*2]}}};

        SP256K u_spsram (
            // Read/write address
            .AD       (word_addr),
            // Data input
            .DI       (wdata[j*16 +: 16]),
            // Write enable mask. Each bit corresponds to one nibble of the data input           
            .MASKWE   (maskwe),
            // Write enable, active high           
            .WE       (wr_en),
            // Chip select, active high
            .CS       (en),
            // Read/write clock
            .CK       (clk),
            // Enable low leakage mode, with no change in the output state. Active high
            .STDBY    (1'b0),
            // Enable sleep mode, with the data outputs pulled low. Active high
            .SLEEP    (1'b0),
            // Enable power off mode, with no memory content retention. Active low
            .PWROFF_N (1'b1),             
            // Data output
            .DO       (rdata[j*16 +: 16])
        );
    end
endgenerate

endmodule