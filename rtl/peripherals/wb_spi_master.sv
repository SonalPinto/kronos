// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

8-bit Full-Duplex SPI Master with RX/TX Queue

- Wishbone slave, 8b data bus
- Control and status
    * CPOL/CPHA (All SPI Modes Supported)
    * SPI clock rate = clk/(2 * prescaler+1)
    * clear TX/RX Queue
    * Size of the TX/RX Queue
- Peek at RX Queue without reading it
- No Chip Select - implementation left to the Host

Wishbone slave interface
    - Registered Feedback Bus Cycle, Advanced

*/

module wb_spi_master #(
    parameter BUFFER=32
)(
    input  logic        clk,
    input  logic        rstz,
    // SPI PHY
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    // Control and Status
    input  logic [15:0] prescaler,
    input  logic        cpol,
    input  logic        cpha,
    input  logic        tx_clear,
    input  logic        rx_clear,
    output logic [15:0] tx_size,
    output logic [15:0] rx_size,
    // data interface
    input  logic [7:0]  dat_i,
    output logic [7:0]  dat_o,
    input  logic        we_i,
    input  logic        stb_i,
    output logic        ack_o
);

logic txq_ack;

logic txq_full, txq_empty;
logic [$clog2(BUFFER):0] txq_size;

logic txq_din_vld, txq_din_rdy;
logic txq_dout_vld, txq_dout_rdy;
logic [7:0] txq_din, txq_dout;

logic rxq_ack;

logic rxq_full, rxq_empty;
logic [$clog2(BUFFER):0] rxq_size;

logic rxq_din_vld, rxq_din_rdy;
logic rxq_dout_vld, rxq_dout_rdy;
logic [7:0] rxq_din, rxq_dout;


// ============================================================
// TX Queue
// Shove data straight into the TX fifo
// If the fifo is full, the new data is quietly dropped

fifo #(
    .WIDTH(8     ),
    .DEPTH(BUFFER)
) u_txq (
    .clk     (clk         ),
    .rstz    (rstz        ),
    .clear   (tx_clear    ),
    .size    (txq_size    ),
    .full    (txq_full    ),
    .empty   (txq_empty   ),
    .din     (txq_din     ),
    .din_vld (txq_din_vld ),
    .din_rdy (txq_din_rdy ),
    .dout    (txq_dout    ),
    .dout_vld(txq_dout_vld),
    .dout_rdy(txq_dout_rdy)
);

assign txq_din = dat_i;
assign txq_din_vld = stb_i & we_i & txq_ack;

// ============================================================
// RX Queue
// Send out data from the RX fifo when requested
// If the fifo is empty, the send out zeros

fifo #(
    .WIDTH(8     ),
    .DEPTH(BUFFER)
) u_rxq (
    .clk     (clk         ),
    .rstz    (rstz        ),
    .clear   (rx_clear    ),
    .size    (rxq_size    ),
    .full    (rxq_full    ),
    .empty   (rxq_empty   ),
    .din     (rxq_din     ),
    .din_vld (rxq_din_vld ),
    .din_rdy (rxq_din_rdy ),
    .dout    (rxq_dout    ),
    .dout_vld(rxq_dout_vld),
    .dout_rdy(rxq_dout_rdy)
);

assign dat_o = rxq_dout;
assign rxq_dout_rdy = stb_i & ~we_i & rxq_ack;

// ============================================================
// Host Interface

// register the Read/Write ACK, always ack
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        txq_ack <= 1'b0;
        rxq_ack <= 1'b0;
    end
    else begin
        txq_ack <= stb_i & we_i;
        rxq_ack <= stb_i & ~we_i;
    end
end

// size is already registered in the fifo
assign tx_size = { {{16-$clog2(BUFFER)-1}{1'b0}}, txq_size};
assign rx_size = { {{16-$clog2(BUFFER)-1}{1'b0}}, rxq_size};

// Advanced synchronous terminated burst
assign ack_o = stb_i & (txq_ack | rxq_ack);

// ============================================================
// SPI Master Phy

spi_master u_spim (
    .clk      (clk         ),
    .rstz     (rstz        ),
    .sclk     (sclk        ),
    .mosi     (mosi        ),
    .miso     (miso        ),
    .prescaler(prescaler   ),
    .cpol     (cpol        ),
    .cpha     (cpha        ),
    .din      (txq_dout    ),
    .din_vld  (txq_dout_vld),
    .din_rdy  (txq_dout_rdy),
    .dout     (rxq_din     ),
    .dout_vld (rxq_din_vld )
);

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , txq_din_rdy
    , txq_full
    , txq_empty
    , rxq_dout_vld
    , rxq_din_rdy
    , rxq_full
    , rxq_empty
};
`endif

endmodule