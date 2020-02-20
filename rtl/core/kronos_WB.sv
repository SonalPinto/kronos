// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RISC-V 32I Write Back Unit

This is the last stage of the Kronos pipeline and is responsible for these functions:
- Write Back register data
- Load data from memory as per load size and sign extend if requested
- Store data to memory
- Branch unconditionally
- Branch conditionally as per value of result1

WB_CTRL
    rd          : register write select
    rd_write    : register write enable
    branch      : unconditional branch
    branch_cond : conditional branch
    ld_size     : memory load size - byte, half-word or word
    ld_sign     : sign extend loaded data
    st          : store
    illegal     : illegal instruction
*/

module kronos_WB
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    // IF/ID interface
    input  pipeEXWB_t   execute,
    input  logic        pipe_in_vld,
    output logic        pipe_in_rdy,
    // REG Write
    output logic [31:0] regwr_data,
    output logic [4:0]  regwr_sel,
    output logic        regwr_en,
    // Branch
    output logic [31:0] branch_target,
    output logic        branch
);

logic wb_valid;

enum logic [1:0] {
    WRITE,
    CATCH
} state, next_state;

// ============================================================
// Write Back Sequencer
// 
// Register Write and Branch execute in 1 cycle
// Load/Store take ##-## cycles depending on data alignment

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= WRITE;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        WRITE: if (pipe_in_vld) begin
            if (execute.illegal) next_state = CATCH;
        end
    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

assign pipe_in_rdy = (state == WRITE) && ~execute.illegal;
assign wb_valid = pipe_in_rdy && pipe_in_vld;

// ============================================================
// Register Write

assign regwr_data = execute.result1;
assign regwr_sel = execute.rd;
assign regwr_en = wb_valid && execute.rd_write;

// ============================================================
// Branch
// Set PC to result2, if unconditional branch or condition valid (result1 from alu comparator is 1)

assign branch_target = execute.result2;
assign branch = wb_valid && (execute.branch || (execute.branch_cond && execute.result1[0]));

endmodule
