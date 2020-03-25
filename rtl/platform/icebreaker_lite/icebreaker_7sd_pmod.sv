// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Controller for 1BitSquared 7 Segment Display PMOD

Ref: https://1bitsquared.com/collections/fpga/products/pmod-7-segment-display
Sch: https://github.com/icebreaker-fpga/icebreaker-pmod/blob/master/7segment/v1.1a/7segment-sch.pdf

      A
     ---
  F | G | B
     ---
  E |   | C
     ---
      D

0 : 7'b1000000
1 : 7'b1111001
2 : 7'b0100100
3 : 7'b0110000
4 : 7'b0011001
5 : 7'b0010010
6 : 7'b0000010
7 : 7'b1111000
8 : 7'b0000000
9 : 7'b0010000
A : 7'b0001000
B : 7'b0000011
C : 7'b1000110
D : 7'b0100001
E : 7'b0000110
F : 7'b0001110

*/

module icebreaker_7sd_pmod (
    input  logic        clk,
    input  logic        rstz,
    input  logic        en,
    input  logic [6:0]  a,
    input  logic [6:0]  b,
    output logic [6:0]  disp,
    output logic        sel
);

logic [15:0] timer;
logic rollover, tick;

// timer
always_ff @(posedge clk) begin
    timer <= timer + 1'b1;
    rollover <= timer[15];
end

// 2.7ms = 2**16 * (1/24MHz)
assign tick = rollover & ~timer[15];

// display output mux
always_ff @(posedge clk) begin
    if (~rstz || ~en) begin
        sel <= 1'b0;
        disp <= '1; // anode, blanks display
    end
    else if (tick) begin
        sel <= ~sel;
        disp <= (sel) ? b : a;
    end
end

endmodule