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

Unaligned access is handled by the LSU and will never throw the
Load/Store address aligned exception

WB_CTRL
    rd          : register write select
    rd_write    : register write enable
    branch      : unconditional branch
    branch_cond : conditional branch
    ld          : load
    st          : store
    data_size   : memory access size - byte, half-word or word
    data_sign   : sign extend memory data (only for load)

Exceptions
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
    output logic        branch,
    // Data interface
    output logic [31:0] data_addr,
    input  logic [31:0] data_rd_data,
    output logic [31:0] data_wr_data,
    output logic [3:0]  data_wr_mask,
    output logic        data_rd_req,
    output logic        data_wr_req,
    input  logic        data_gnt
);

logic wb_valid;
logic direct_write;
logic branch_success;

logic exception_caught;
logic [3:0] exception_cause, exception_cause_next;

logic lsu_start, lsu_done;
logic [31:0] load_data;
logic [4:0] load_rd;
logic load_en;

enum logic [1:0] {
    STEADY,
    LSU,
    TRAP
} state, next_state;

// ============================================================
// Write Back Sequencer
// 
// Register Write and Branch execute in 1 cycle
// Load/Store take 2-3 cycles depending on data alignment

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= STEADY;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        STEADY: if (pipe_in_vld) begin
            if (exception_caught) next_state = TRAP;
            else if (execute.ld || execute.st) next_state = LSU;
        end

        LSU: if (lsu_done) next_state = STEADY;

    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Always accept execute stage pipeline in steady state
assign pipe_in_rdy = state == STEADY;

// Direct write-back is always valid in continued steady state
assign wb_valid = pipe_in_vld && state == STEADY && ~exception_caught;

// ============================================================
// Load Store Unit

assign lsu_start = wb_valid && (execute.ld || execute.st);

kronos_lsu u_lsu (
    .clk         (clk              ),
    .rstz        (rstz             ),
    .addr        (execute.result1  ),
    .load_data   (load_data        ),
    .load_rd     (load_rd          ),
    .load_en     (load_en          ),
    .store_data  (execute.result2  ),
    .start       (lsu_start        ),
    .done        (lsu_done         ),
    .rd          (execute.rd       ),
    .ld          (execute.ld       ),
    .st          (execute.st       ),
    .data_size   (execute.data_size),
    .data_uns    (execute.data_uns ),
    .data_addr   (data_addr        ),
    .data_rd_data(data_rd_data     ),
    .data_wr_data(data_wr_data     ),
    .data_wr_mask(data_wr_mask     ),
    .data_rd_req (data_rd_req      ),
    .data_wr_req (data_wr_req      ),
    .data_gnt    (data_gnt         )
);

// ============================================================
// Register Write
// Registers are written either directly or from memory loads
// Direct writes are commited in the same cycle as execute goes valid
// and is evaluated as a safe direct write
// Loads will take 1 cycle for aligned access and 2 for unaligned access

assign direct_write = wb_valid && execute.rd_write && ~execute.ld;

assign regwr_data = (load_en) ? load_data : execute.result1;
assign regwr_sel  = (load_en) ? load_rd   : execute.rd;
assign regwr_en   = (load_en) ? 1'b1      : direct_write;

// ============================================================
// Branch
// Set PC to result2, if unconditional branch or condition valid (result1 from alu comparator is 1)

assign branch_target = execute.result2;
assign branch_success = execute.branch || (execute.branch_cond && execute.result1[0]);

assign branch = wb_valid && branch_success;

// ============================================================
// Exceptions

// Catch exceptions from various sources around the core and inform
// the WB sequencer about it, so it can prompt the CLIC to invoke
// the trap handler
always_comb begin
    exception_caught = 1'b0;
    exception_cause_next = '0;
    if (pipe_in_vld && state == STEADY) begin
        if (execute.is_illegal) begin
            // Illegal instructions detected by the decoder
            exception_caught = 1'b1;
            exception_cause_next = ILLEGAL_INSTR;
        end
        else if (branch_success && branch_target[1:0] != 2'b00) begin
            // Instructions can only be jumped to at 4B boundary
            // And this only needs to be checked for unconditional jumps 
            // or successful branches
            exception_caught = 1'b1;
            exception_cause_next = INSTR_ADDR_MISALIGNED;
        end
    end
end

always_ff @(posedge clk) begin
    if (exception_caught) exception_cause <= exception_cause_next;
end

endmodule
