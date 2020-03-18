// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RISC-V Machine-Level CSRs v1.11

This is a partial implementation with the following CSRs:
- Machine Hardware Performance Counters
    * mcycle/mcycleh
    * minstret/minstreth

The module also acts as an interruptor funneling the various interrupt source
spec'd in the privileged machine-level architecture. Namely, External, Timer 
and Software interrupts
*/

module kronos_csr
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    // WB Controls
    input  logic [31:0] IR,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    input  logic        csr_start,
    output logic [4:0]  csr_rd,
    output logic        csr_write,
    output logic        done,
    // external
    input  logic        instret
);

logic [1:0] op;
logic [11:0] addr;
logic [31:0] twdata;

logic [31:0] csr_rd_data, csr_wr_data;
logic csr_rd_vld, csr_wr_vld;
logic csr_rd_en, csr_wr_en;
logic csr_write_ok;

logic mcycle_wrenl, mcycle_wrenh;
logic mcycle_rd_vld;
logic [63:0] mcycle;

logic minstret_wrenl, minstret_wrenh;
logic minstret_rd_vld;
logic [63:0] minstret;

enum logic [1:0] {
    IDLE,
    READ,
    WRITE
} state, next_state;

// ============================================================
// CSR Sequencer

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        IDLE: begin
            // Atomic Read/Modify/Write
            if (csr_start) next_state = READ;
        end
        READ: if (csr_rd_vld) next_state = WRITE;
        WRITE: next_state = IDLE;
    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Stow controls
always_ff @(posedge clk) begin
    if (state == IDLE && csr_start) begin
        // Extract CSR instruction parameters from the IR
        op <= IR[13:12];        // funct3[1:0]
        addr <= IR[31-:12];
        csr_rd <= IR[11:7];

        twdata <= wr_data;

        // Cancel the CSR write for csrrc/rs if rs1=0
        csr_wr_vld <= ~((IR[14:12] == 3'b010 || IR[14:12] == 3'b011) && IR[19:15] == '0);

        // Cancel the CSR register writeback for rd == 0
        csr_write_ok <= IR[11:7] != '0;
    end
end

// aggregate all read-valid sources
assign csr_rd_vld = mcycle_rd_vld && minstret_rd_vld;

// CSR read/write access
assign csr_rd_en = state == READ && csr_rd_vld;
assign csr_wr_en = state == WRITE && csr_wr_vld;

// Register write back
assign csr_write = state == WRITE && csr_write_ok;
always_ff @(posedge clk) begin
    if (csr_rd_en) rd_data <= csr_rd_data;
end

// CSR work done
assign done = state == WRITE;

// ============================================================
// CSR Read
always_comb begin
    csr_rd_data  = '0;
    /* verilator lint_off CASEINCOMPLETE */
    case(addr)
        MCYCLE      : csr_rd_data = mcycle[31:0];
        MINSTRET    : csr_rd_data = minstret[31:0];
        MCYCLEH     : csr_rd_data = mcycle[63:32];
        MINSTRETH   : csr_rd_data = minstret[63:32];
    endcase // addr
    /* verilator lint_on CASEINCOMPLETE */
end

// ============================================================
// CSR Write
always_comb begin
    // Modify latched rd_data as per op
    // RS: Set - wr_data as a set mask
    // RC: Clear - wr_data as a clear mask
    // Rw/Default: wr_data as write data
    case (op)
        CSR_RS: csr_wr_data = rd_data | twdata;
        CSR_RC: csr_wr_data = rd_data & ~twdata;
        default: csr_wr_data = twdata;
    endcase
end

// ============================================================
// Hardware Performance Monitors

// mcycle, 64b Machine cycle counter
assign mcycle_wrenl = csr_wr_en && addr == MCYCLE;
assign mcycle_wrenh = csr_wr_en && addr == MCYCLEH;

kronos_counter64 u_hpmcounter0 (
    .clk      (clk          ),
    .rstz     (rstz         ),
    .incr     (1'b1         ),
    .load_data(csr_wr_data  ),
    .load_low (mcycle_wrenl ),
    .load_high(mcycle_wrenh ),
    .count    (mcycle       ),
    .count_vld(mcycle_rd_vld)
);

// minstret, 64b Machine instructions-retired counter
assign minstret_wrenl = csr_wr_en && addr == MINSTRET;
assign minstret_wrenh = csr_wr_en && addr == MINSTRETH;

kronos_counter64 u_hpmcounter1 (
    .clk      (clk            ),
    .rstz     (rstz           ),
    .incr     (instret        ),
    .load_data(csr_wr_data    ),
    .load_low (minstret_wrenl ),
    .load_high(minstret_wrenh ),
    .count    (minstret       ),
    .count_vld(minstret_rd_vld)
);

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , IR[6:0]
};
`endif

endmodule
