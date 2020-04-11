// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

8-bit UART (Serial) TX

- Wishbone slave, 8b data
- runtime configurable baud rate (default 115200)
    clk/(prescaler+1)
- transmission control and status

Wishbone slave interface
    - Registered Feedback Bus Cycle, Advanced

*/

module uart_tx #(
    parameter BUFFER=32
)(
    input  logic        clk,
    input  logic        rstz,
    // UART TX
    output logic        tx,
    // Control
    input  logic [15:0] prescaler,
    input  logic        clear,
    output logic        full,
    output logic        empty,
    output logic [15:0] size,
    // data interface
    input  logic [7:0]  dat_i,
    input  logic        we_i,
    input  logic        stb_i,
    output logic        ack_o
);

logic ack;
logic tfull, tempty;
logic [$clog2(BUFFER):0] tsize;

logic fifo_wr_vld, fifo_wr_rdy;
logic fifo_rd_vld, fifo_rd_rdy;
logic [7:0] fifo_wr_data, fifo_rd_data;

logic init, done;
logic [15:0] timer;
logic tick;

logic [9:0] buffer;
logic [10:0] tracker;

enum logic {
    IDLE,
    TRANSMIT
} state, next_state;

// ============================================================
// Buffer in the data straight into a FIFO
// If the fifo is full, the new data is quietly dropped
fifo #(
    .WIDTH(8     ),
    .DEPTH(BUFFER)
) u_buffer (
    .clk     (clk         ),
    .rstz    (rstz        ),
    .clear   (clear       ),
    .size    (tsize       ),
    .full    (tfull       ),
    .empty   (tempty      ),
    .din     (fifo_wr_data),
    .din_vld (fifo_wr_vld ),
    .din_rdy (fifo_wr_rdy ),
    .dout    (fifo_rd_data),
    .dout_vld(fifo_rd_vld ),
    .dout_rdy(fifo_rd_rdy )
);

assign fifo_wr_data = dat_i;
assign fifo_wr_vld = stb_i & we_i & ack;

// register these signals before sending them out
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        ack <= 1'b0;
    end
    else begin
        full <= tfull;
        empty <= tempty;

        // always ack
        ack <= stb_i & we_i;
    end
end

// Advanced synchronous terminated burst
assign ack_o = stb_i & ack;

// size is already registered in the fifo
assign size = { {{16-$clog2(BUFFER)-1}{1'b0}}, tsize};

// ============================================================
// UART TX sequencer
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: if (fifo_rd_vld) next_state = TRANSMIT;
        TRANSMIT: if(done) next_state = IDLE;
    endcase // state
end

// init transmission, and move onto the next byte in the fifo
assign fifo_rd_rdy = init;
assign init = (state == IDLE) && fifo_rd_vld;

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
    if (init) begin
        {tx, buffer} <= {1'b0, fifo_rd_data, 1'b1, 1'b1};
        tracker <= 11'b1;
    end
    else if (state == TRANSMIT && tick) begin
        {tx, buffer} <= {buffer, 1'b1};
        tracker <= {tracker[9:0], 1'b0};
    end
end

// End transmission
assign done = tracker[10] && tick;

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , fifo_wr_rdy
};
`endif

endmodule