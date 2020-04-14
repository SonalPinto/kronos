// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

8-bit UART (Serial) TX with TX Queue

- Wishbone slave, 8b data bus
- Control and status
    * baud rate (default 115200) = clk/(prescaler+1)
    * clear TX Queue
    * Size of the TX Queue

Wishbone slave interface
    - Registered Feedback Bus Cycle, Advanced
*/

module wb_uart_tx #(
    parameter BUFFER=32,
    parameter PRESCALER_WIDTH = 16
)(
    input  logic        clk,
    input  logic        rstz,
    // UART TX
    output logic        tx,
    // Control and Status
    input  logic [PRESCALER_WIDTH-1:0]  prescaler,
    input  logic                        clear,
    output logic [$clog2(BUFFER):0]     size,
    // data interface
    input  logic [7:0]  dat_i,
    input  logic        we_i,
    input  logic        stb_i,
    output logic        ack_o
);

logic ack;
logic txq_full, txq_empty;
logic [$clog2(BUFFER):0] txq_size;

logic txq_din_vld, txq_din_rdy;
logic txq_dout_vld, txq_dout_rdy;
logic [7:0] txq_din, txq_dout;

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
    .clear   (clear       ),
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
assign txq_din_vld = stb_i & we_i & ack;

// register the ACK, always ack
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) ack <= 1'b0;
    else ack <= stb_i & we_i;
end

// Advanced synchronous terminated burst
assign ack_o = stb_i & ack;

// size is already registered in the fifo
assign size = txq_size;

// ============================================================
// UART TX Phy

uart_tx #(
    .PRESCALER_WIDTH(PRESCALER_WIDTH)
) u_tx (
    .clk      (clk         ),
    .rstz     (rstz        ),
    .tx       (tx          ),
    .prescaler(prescaler   ),
    .din      (txq_dout    ),
    .din_vld  (txq_dout_vld),
    .din_rdy  (txq_dout_rdy)
);

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , txq_din_rdy
    , txq_full
    , txq_empty
};
`endif

endmodule