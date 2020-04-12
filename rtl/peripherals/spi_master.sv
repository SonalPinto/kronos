// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

8-bit Full-Duplex SPI Master

- Control and status
    * CPOL/CPHA (All SPI Modes Supported)
    * SPI clock rate = clk/(2 * prescaler+1)

The SCLK sets its idle value based on CPOL

*/

module spi_master (
    input  logic        clk,
    input  logic        rstz,
    // SPI PHY
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    // Config
    input  logic [15:0] prescaler,
    input  logic        cpol,
    input  logic        cpha,
    // Data interface
    input  logic [7:0]  din,
    input  logic        din_vld,
    output logic        din_rdy,
    output logic [7:0]  dout,
    output logic        dout_vld
);

logic [15:0] timer;
logic tick;

logic [4:0] state;
logic init, done, active;

logic [7:0] tx_buffer, rx_buffer;

// ============================================================
// SPI Master Sequencer

// 17-state counter that starts when there's data to transmit,
// and counts up on SPI ticks.
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= '0;
    else if (din_vld && state == '0) state <= state + 1'b1;
    else if (active && tick) state <= (done) ? '0 : state + 1'b1;
end

// sequence control signals
assign active = state != '0;
assign init = din_vld && state == '0;
assign done = state == 5'd16 && tick;

// inform host to prepare the next byte
assign din_rdy = init;

// Bit timer
assign tick = timer == prescaler;
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) timer <= '0;
    else if (init) timer <= '0;
    else if (active) timer <= tick ? '0 : timer + 1'b1;
end

// ============================================================
// SPI CLK

// The sclk sets its idle state as per CPOL.
// In an active transmission, the first edge is set
// as per CPOL/CPHA config. And, subsequent edges toggle on ticks.
// Until the last edge, where it reverts to CPOL
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) sclk <= 1'b0;
    else if (init) sclk <= cpol ? ~cpha : cpha;
    else if (active) begin
        if (tick) sclk <= done ? cpol : ~sclk;
    end
    else sclk <= cpol;
end

// ============================================================
// SPI MOSI

// Shift out bits on every odd state, hence on the even state, the MOSI is stable
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) tx_buffer <= '0;
    else if (init) tx_buffer <= din;
    else if (tick && ~state[0]) tx_buffer <= tx_buffer << 1;
end

assign mosi = tx_buffer[7];

// ============================================================
// SPI MISO

// Shift in bits on every even state, expecting the slave has kept MISO stable
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) rx_buffer <= '0;
    else if (init) rx_buffer <= '0;
    else if (tick && state[0] && ~done) rx_buffer <= {rx_buffer[6:0], miso};
end

assign dout = rx_buffer;
assign dout_vld = done;

endmodule