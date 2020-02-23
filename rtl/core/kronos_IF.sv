// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RISC-V 32I Instruction Fetch

Simple Pipelined Fetch with single cycle throughput, One Block Lookahead fetch
*/

module kronos_IF
    import kronos_types::*;
#(
    parameter PC_START = 32'h0
)(
    input  logic    clk,
    input  logic    rstz,
    // Instruction interface
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_data,
    output logic        instr_req,
    input  logic        instr_gnt,
    // IF/ID interface
    output pipeIFID_t   fetch,
    output logic        pipe_out_vld,
    input  logic        pipe_out_rdy,
    // BRANCH
    input logic [31:0]  branch_target,
    input logic         branch
);

logic [31:0] pc, pc_last;
logic update_pc;
logic fetch_rdy, fetch_vld;

enum logic [1:0] {
    INIT,
    FETCH,
    STALL
} state, next_state;


// ============================================================
// Program Counter (PC) Generation
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pc <= PC_START;
        pc_last <= '0;
    end
    else begin
        if (update_pc) begin
            pc <= branch ? branch_target : (pc + 32'h4);
            pc_last <= pc;
        end
    end
end

assign update_pc = next_state == FETCH;

// ============================================================
//  Instruction Fetch

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= INIT;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        INIT: next_state = FETCH;

        FETCH:
            if (instr_gnt && fetch_rdy) next_state = FETCH;
            else next_state = STALL;

        STALL:
            if (instr_gnt && fetch_rdy) next_state = FETCH;

    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// FIXME - Swap this out to a skid buffer ?
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        fetch_vld <= '0;
    end
    else begin
        if (instr_gnt && fetch_rdy && (state == FETCH || state == STALL)) begin
            fetch.pc <= pc_last;
            fetch.ir <= instr_data;
            fetch_vld <= 1'b1;
        end
        else if (fetch_vld && pipe_out_rdy) begin
            fetch_vld <= 1'b0;
        end
    end
end

assign fetch_rdy = ~fetch_vld | pipe_out_rdy;

// Memory Interface
assign instr_addr = (next_state != FETCH) ? pc_last : pc;
assign instr_req = fetch_rdy;

// Next Stage pipe interface
assign pipe_out_vld = fetch_vld;

endmodule
