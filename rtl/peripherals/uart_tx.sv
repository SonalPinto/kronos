// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

8-bit UART (Serial) TX

Runtime configurable baud rate (default 115200) = clk/(prescaler+1)

Serial Protocol

+-----+         +----+----+----+----+----+----+----+----+--------+
      | START=0 | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP=1
      +---------+----+----+----+----+----+----+----+----+

- Two Additional idle cycles (at HIGH) at the end, for a total of
12 cycles per byte

*/

module uart_tx (
    input  logic        clk,
    input  logic        rstz,
    // UART TX PHY
    output logic        tx,
    // Config
    input  logic [15:0] prescaler,
    // Data interface
    input  logic [7:0]  din,
    input  logic        din_vld,
    output logic        din_rdy
);

logic init, done;
logic [15:0] timer;
logic tick;

logic [10:0] buffer;
logic [11:0] tracker;

enum logic {
    IDLE,
    TRANSMIT
} state, next_state;

// ============================================================
// UART TX sequencer
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: if (din_vld) next_state = TRANSMIT;
        TRANSMIT: if(done) next_state = IDLE;
    endcase // state
end

// start transmission, and inform host to present the next byte
assign init = (state == IDLE) && din_vld;
assign din_rdy = init;

// Bit timer
assign tick = timer == prescaler;
always_ff @(posedge clk) begin
    if (init) timer <= '0;
    else if (state == TRANSMIT) timer <= tick ? '0 : timer + 1'b1;
end

// Transmit buffer
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        tx <= 1'b1;
    end
    else if (init) begin
        {buffer, tx} <= {3'b111, din, 1'b0};
        tracker <= 12'b1;
    end
    else if (state == TRANSMIT && tick) begin
        {buffer, tx} <= {1'b1, buffer};
        tracker <= tracker << 1'b1;
    end
end

// End transmission
assign done = tracker[11] && tick;

endmodule