// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

8-bit UART (Serial) TX

Runtime configurable baud rate (default 115200) = clk/(prescaler+1)

Serial Protocol

+-----+         +----+----+----+----+----+----+----+----+--------+
      | START=0 | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP=1
      +---------+----+----+----+----+----+----+----+----+

+ 1 extra stop bit

*/

module uart_tx #(
    parameter PRESCALER_WIDTH = 16
)(
    input  logic        clk,
    input  logic        rstz,
    // UART TX PHY
    output logic        tx,
    // Config
    input  logic [PRESCALER_WIDTH-1:0] prescaler,
    // Data interface
    input  logic [7:0]  din,
    input  logic        din_vld,
    output logic        din_rdy
);

logic [PRESCALER_WIDTH-1:0] timer;
logic tick;

logic [3:0] state;
logic init, done, active;

logic [9:0] buffer;

// ============================================================
// UART TX Sequencer

// 12-state counter that starts when there's data to transmit
// and counts up on UART ticks
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz)
        state <= '0;
    else if (din_vld && state == '0)
        state <= state + 1'b1;
    else if (active && tick)
        state <= (done) ? '0 : state + 1'b1;
end

// sequence control signals
assign active = state != '0;
assign init = din_vld && state == '0;
assign done = state == 4'd11 && tick;

// inform host to prepare the next byte
always_ff @(posedge clk) begin
    din_rdy <= init;
end

// Bit timer
assign tick = timer == prescaler;
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz)
		timer <= '0;
	else if (init)
        timer <= '0;
    else if (active)
        timer <= tick ? '0 : timer + 1'b1;
end

// Transmit buffer
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz)
        buffer <= '1;
    else if (init)
        buffer <= {1'b1, din, 1'b0};
    else if (active && tick)
        buffer <= {1'b1, buffer[9:1]};
end

assign tx = buffer[0];

endmodule