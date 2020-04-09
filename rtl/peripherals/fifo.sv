// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

Parameterizable FIFO
With a slave write interface and master read interface

Native AXI4-Stream interface, Wishbone compatible

din         ---  DAT_I
din_vld     ---  STB_I
din_rdy     ---  ACK_O
dout        ---  DAT_O
dout_vld    ---  STB_O
dout_rdy    ---  ACK_I

Also has full, empty and size status indicators.
The actual size is N+1, because the output is registered.

*/

module fifo #(
    parameter WIDTH=8,
    parameter DEPTH=32
)(
    input  logic                        clk,
    input  logic                        rstz,
    input  logic                        clear,
    output logic [$clog2(DEPTH):0]      size,
    output logic                        full,
    output logic                        empty,
    input  logic [WIDTH-1:0]            din,
    input  logic                        din_vld,
    output logic                        din_rdy,
    output logic [WIDTH-1:0]            dout,
    output logic                        dout_vld,
    input  logic                        dout_rdy
);

localparam PW = $clog2(DEPTH);

logic [WIDTH-1:0] MEM [DEPTH];

logic [PW-1:0] wraddr, rdaddr;
logic [PW:0] wrptr, rdptr;
logic wr_en, rd_en;

// ------------------------------------------------------------
// Write

// write into the fiofo if the fifo is not full
assign wr_en = din_vld && ~full;

assign wraddr = wrptr[PW-1:0];

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) wrptr <= '0;
    else if (clear) wrptr <= '0;
    else if (wr_en) begin
        MEM[wraddr] <= din;

        wrptr <= wrptr + 1'b1;
    end
end

assign din_rdy = wr_en;

// ------------------------------------------------------------
// Read

// read from the non-empty fifo if the output buffer is empty
// or the output slave is ready to absorb the currently valid output buffer
assign rd_en = (~dout_vld | dout_rdy) & ~empty;

assign rdaddr = rdptr[PW-1:0];

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        rdptr <= '0;
        dout_vld <= 1'b0;
    end
    else if (clear) begin
        rdptr <= '0;
        dout_vld <= 1'b0;
    end
    else begin
        if (rd_en) begin
            dout <= MEM[rdaddr];
            dout_vld <= 1'b1;

            rdptr <= rdptr + 1'b1;
        end
        else if (dout_vld && dout_rdy)
            dout_vld <= 1'b0;
    end
end

// ------------------------------------------------------------
// Status
// Full status doesn't use an adder chain!
assign full = (wrptr[PW] != rdptr[PW]) && (wrptr[PW-1:0] == rdptr[PW-1:0]);
assign empty = rdptr == wrptr;

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) size <= '0;
    else if (clear) size <= '0;
    else begin
        if (wr_en && ~(dout_vld && dout_rdy)) size <= size + 1'b1;
        else if (~wr_en && (dout_vld && dout_rdy)) size <= size - 1'b1;
    end
end

endmodule
