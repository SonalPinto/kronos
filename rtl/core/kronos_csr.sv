// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RISC-V Machine-Level CSRs v1.11

This is a partial implementation with the following CSRs:
- Machine Hardware Performance Counters
    * mcycle/mcycleh
    * minstret/minstreth

The CSR have an sram-like read/write interface for implementing the system CSR 
instructions

The module also acts as an interruptor funneling the various interrupt source
spec'd in the privileged machine-level architecture. Namely, External, Timer 
and Software interrupts
*/

module kronos_csr
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    // CSR RW interface
    input  logic [11:0] addr,
    input  logic [1:0]  op,
    output logic [31:0] rd_data,
    input  logic [31:0] wr_data,
    input  logic        rd_req,
    input  logic        wr_req,
    output logic        gnt
);

logic [31:0] csr_rd_data, csr_wr_data;
logic csr_rd_vld;

logic mcycle_wrenl, mcycle_wrenh;
logic mcycle_rd_vld;
logic [63:0] mcycle;

// ============================================================
// Access Sequencer
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        gnt <= 1'b0;
    end
    else begin
        // CSR RW Operations
        if (rd_req) begin
            rd_data <= csr_rd_data;
            gnt <= csr_rd_vld;
        end
        else if (wr_req) begin
            gnt <= 1'b1;
        end
        else gnt <= 1'b0;
    end
end

// aggreate all read-valid sources
assign csr_rd_vld = mcycle_rd_vld;

// ============================================================
// CSR Read
always_comb begin
    csr_rd_data  = '0;
    /* verilator lint_off CASEINCOMPLETE */
    case(addr)
        MCYCLE      : csr_rd_data = mcycle[31:0];
        // MINSTRET    : csr_rd_data = minstret[31:0];
        MCYCLEH     : csr_rd_data = mcycle[63:32];
        // MINSTRETH   : csr_rd_data = minstret[63:32];
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
        CSR_RS: csr_wr_data = rd_data | wr_data;
        CSR_RC: csr_wr_data = rd_data & ~wr_data;
        default: csr_wr_data = wr_data;
    endcase
end

// ============================================================
// Hardware Performance Monitors

// mcycle, 64b Machine cycle counter
assign mcycle_wrenl = wr_req && addr == MCYCLE;
assign mcycle_wrenh = wr_req && addr == MCYCLEH;

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

endmodule
