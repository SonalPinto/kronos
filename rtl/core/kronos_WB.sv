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
    funct3      : Context based parameter
        - data_size : memory access size - byte, half-word or word
        - data_sign : sign extend memory data (only for load)

System Controls
    system      : system instruction
    ecall       : environment call
    funct3      : Context based parameter
        - csr_op    : CSR operation, rw/set/clr

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
logic [3:0] exception_cause, exception_cause_reg;

logic lsu_start, lsu_done;
logic [31:0] load_data;
logic [4:0] load_rd;
logic load_write;

logic [31:0] csr_rd_data;
logic csr_start;
logic [4:0] csr_rd;
logic csr_write;
logic csr_done;

logic instret;

enum logic [2:0] {
    STEADY,
    LSU,
    CSR,
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
            else if (execute.system) next_state = CSR;
        end
        LSU: if (lsu_done) next_state = STEADY;
        CSR: if (csr_done) next_state = STEADY;
    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Always accept execute stage pipeline in steady state
assign pipe_in_rdy = state == STEADY;

// Direct write-back is always valid in continued steady state
assign wb_valid = pipe_in_vld && state == STEADY && ~exception_caught;

// ============================================================
/*
Register Write
Registers are written by multiple sources
     - directly as per the instruction
     - memory load
     - CSR

Direct writes are commited in the same cycle as execute goes valid
and is evaluated as a safe direct write

Loads will take 1 cycle for aligned access and 2 for unaligned 
immediate memory access (longer for far memory, i.e memory mapped,
flash, etc)

CSR read+modify+write takes 3-4 cycles
*/

assign direct_write = wb_valid && execute.rd_write;

always_comb begin
    regwr_data = execute.result1;
    regwr_sel  = execute.rd;
    regwr_en   = 1'b0;

    if (csr_write) begin
        regwr_data = csr_rd_data;
        regwr_sel  = csr_rd;
        regwr_en   = 1'b1;
    end
    else if (load_write) begin
        regwr_data = load_data;
        regwr_sel  = load_rd;
        regwr_en   = 1'b1;
    end
    else if (direct_write) begin
        regwr_en   = 1'b1;
    end
end

// ============================================================
// Branch
// Set PC to result2, if unconditional branch or condition valid (result1 from alu comparator is 1)

assign branch_target = execute.result2;
assign branch_success = execute.branch || (execute.branch_cond && execute.result1[0]);

assign branch = wb_valid && branch_success;

// ============================================================
// Load Store Unit

assign lsu_start = wb_valid && (execute.ld || execute.st);

kronos_lsu u_lsu (
    .clk         (clk                ),
    .rstz        (rstz               ),
    .addr        (execute.result1    ),
    .load_data   (load_data          ),
    .load_rd     (load_rd            ),
    .load_write  (load_write         ),
    .store_data  (execute.result2    ),
    .start       (lsu_start          ),
    .done        (lsu_done           ),
    .rd          (execute.rd         ),
    .ld          (execute.ld         ),
    .st          (execute.st         ),
    .data_size   (execute.funct3[1:0]),
    .data_uns    (execute.funct3[2]  ),
    .data_addr   (data_addr          ),
    .data_rd_data(data_rd_data       ),
    .data_wr_data(data_wr_data       ),
    .data_wr_mask(data_wr_mask       ),
    .data_rd_req (data_rd_req        ),
    .data_wr_req (data_wr_req        ),
    .data_gnt    (data_gnt           )
);

// ============================================================
// CSR

// CSR Read/Modify/Write System instructions
assign csr_start = wb_valid && execute.system;

// instruction retired event
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) instret <= 1'b0;
    else instret <= direct_write 
                    || branch 
                    || lsu_done 
                    || csr_done;
end

kronos_csr u_csr (
    .clk      (clk            ),
    .rstz     (rstz           ),
    .IR       (execute.result1),
    .wr_data  (execute.result2),
    .rd_data  (csr_rd_data    ),
    .csr_start(csr_start      ),
    .csr_rd   (csr_rd         ),
    .csr_write(csr_write      ),
    .done     (csr_done       ),
    .instret  (instret        )
);

// ============================================================
// Exceptions

// Catch exceptions from various sources around the core and inform
// the WB sequencer about it, so it can prompt the THU to invoke
// the trap handler
always_comb begin
    exception_caught = 1'b0;
    exception_cause = '0;
    if (pipe_in_vld && state == STEADY) begin
        if (execute.is_illegal) begin
            // Illegal instructions detected by the decoder
            exception_caught = 1'b1;
            exception_cause = ILLEGAL_INSTR;
        end
        else if (branch_success && branch_target[1:0] != 2'b00) begin
            // Instructions can only be jumped to at 4B boundary
            // And this only needs to be checked for unconditional jumps 
            // or successful branches
            exception_caught = 1'b1;
            exception_cause = INSTR_ADDR_MISALIGNED;
        end
    end
end

always_ff @(posedge clk) begin
    if (exception_caught) exception_cause_reg <= exception_cause;
end

endmodule
