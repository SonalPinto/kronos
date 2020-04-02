// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
128KB Single Port SRAM for iCEBreaker FPGA

Features:    
    - 32K x 32
    - only word accessible (addr[1:0] is ignored)

There are four SP256K (16K x 16) single port SRAM hard macros in iCE40UP5K.
This module cascades all of them to construct the main memory for the system.
The SP256K are arranged as a 2x2 grid.
*/

module ice40up_memory (
    input  logic                        clk,
    input  logic [31:0]                 addr,
    input  logic [31:0]                 wdata,
    output logic [31:0]                 rdata,
    input  logic                        en,
    input  logic                        wr_en,
    input  logic [3:0]                  wr_mask
);

// There are 32K words (15b)
logic [14:0] word_addr;
logic bank, rmux;
logic [1:0][31:0] bank_rdata;

// Extract word address from the physical address
assign word_addr = addr[2+:15];

// Bank selection
assign bank = word_addr[14];

generate
    genvar i,j;
    for (i=0; i<2; i++) begin : MEMBANK
        for (j=0; j<2; j++) begin : MEMINST
            logic cs;
            logic we;
            logic [3:0] maskwe;

            assign cs = (bank == i) & en;
            assign we = cs & wr_en;
            assign maskwe = {{2{wr_mask[j*2+1]}}, {2{wr_mask[j*2]}}};

            SP256K u_spsram (
                // Read/write address
                .AD       (word_addr[13:0]),
                // Data input
                .DI       (wdata[j*16 +: 16]),
                // Write enable mask. Each bit corresponds to one nibble of the data input           
                .MASKWE   (maskwe),
                // Write enable, active high           
                .WE       (we),
                // Chip select, active high
                .CS       (cs),
                // Read/write clock
                .CK       (clk),
                // Enable low leakage mode, with no change in the output state. Active high
                .STDBY    (1'b0),
                // Enable sleep mode, with the data outputs pulled low. Active high
                .SLEEP    (1'b0),
                // Enable power off mode, with no memory content retention. Active low
                .PWROFF_N (1'b1),             
                // Data output
                .DO       (bank_rdata[i][j*16 +: 16])
            );
        end
    end
endgenerate

// read mux needs latched
always_ff @(posedge clk) begin
    if (en) rmux <= bank;
end

assign rdata = bank_rdata[rmux];

endmodule