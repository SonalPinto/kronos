// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Write Back Unit

This is the last stage of the Kronos pipeline and is responsible for these functions:
- Write Back register data
- Load data from memory as per load size and sign extend if requested
- Store data to memory
- Branch unconditionally
- Branch conditionally as per value of result1
- Trapping exceptions and interrupts and setting up CSR for jumping to trap handler
- Returning from trap handler

Misaligned access is handled by the LSU and will never throw the
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
    csr         : CSR R/W instruction
    ecall       : environment call
    ret         : machine return
    wfi         : wait for interrupt
    funct3      : Context based parameter
        - csr_op    : CSR operation, rw/set/clr

*/

module kronos_WB
    import kronos_types::*;
#(
    parameter BOOT_ADDR = 32'h0
)(
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
    output logic        data_wr_en,
    output logic        data_req,
    input  logic        data_ack,
    // Interrupt sources
    input  logic        software_interrupt,
    input  logic        timer_interrupt,
    input  logic        external_interrupt
);

logic wb_valid;
logic direct_write, direct_jump;
logic branch_success;

logic lsu_start, lsu_done;
logic [31:0] load_data;
logic [4:0] load_rd;
logic load_write;
logic lsu_addr_misaligned;

logic [31:0] csr_rd_data;
logic csr_start;
logic [4:0] csr_rd;
logic csr_write;
logic csr_done;

logic exception_caught;
logic [3:0] tcause;
logic [31:0] tvalue;

logic system_call;

logic activate_trap, return_trap;
logic [31:0] trap_cause, trap_addr, trap_value, trapped_pc;
logic trap_jump;

logic instret;
logic core_interrupt;
logic [3:0] core_interrupt_cause;

enum logic [2:0] {
    STEADY,
    LSU,
    CSR,
    TRAP,
    RETURN,
    WFI,
    JUMP
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
            if (core_interrupt || exception_caught) 
                                                next_state = TRAP;
            else if (execute.ecall || execute.ebreak)
                                                next_state = TRAP;
            else if (execute.ret)               next_state = RETURN;
            else if (execute.wfi)               next_state = WFI;
            else if (execute.csr)               next_state = CSR;
            else if (execute.ld || execute.st)  next_state = LSU;
        end

        LSU: if (lsu_done) next_state = STEADY;

        CSR: if (csr_done) next_state = STEADY;

        WFI: if (core_interrupt) next_state = TRAP;

        TRAP: next_state = JUMP;

        RETURN: next_state = JUMP;

        JUMP: if (trap_jump) next_state = STEADY;

    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Always accept execute stage pipeline in steady state
assign pipe_in_rdy = state == STEADY;

// Direct write-back is always valid in continued steady state
assign wb_valid = pipe_in_vld && state == STEADY && ~exception_caught && ~core_interrupt;

// ============================================================
/*
Register Write
Registers are written by multiple sources
     - directly as per the instruction
     - memory load
     - CSR

Direct writes are committed in the same cycle as execute goes valid
and is evaluated as a safe direct write

Loads (and  store) will take 2 cycle for aligned access and 3 for boundary cross
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
// branch for trap handler jumps (to/from) as well

assign branch_target = trap_jump ? trap_addr : execute.result2;
assign branch_success = execute.branch || (execute.branch_cond && execute.result1[0]);
assign direct_jump = wb_valid && branch_success;

assign branch = direct_jump || trap_jump;

// ============================================================
// Load Store Unit

assign lsu_start = wb_valid && (execute.ld || execute.st);

kronos_lsu u_lsu (
    .clk            (clk                ),
    .rstz           (rstz               ),
    .addr           (execute.result1    ),
    .load_data      (load_data          ),
    .load_rd        (load_rd            ),
    .load_write     (load_write         ),
    .store_data     (execute.result2    ),
    .start          (lsu_start          ),
    .done           (lsu_done           ),
    .rd             (execute.rd         ),
    .ld             (execute.ld         ),
    .st             (execute.st         ),
    .data_size      (execute.funct3[1:0]),
    .data_uns       (execute.funct3[2]  ),
    .addr_misaligned(lsu_addr_misaligned),
    .data_addr      (data_addr          ),
    .data_rd_data   (data_rd_data       ),
    .data_wr_data   (data_wr_data       ),
    .data_wr_mask   (data_wr_mask       ),
    .data_wr_en     (data_wr_en         ),
    .data_req       (data_req           ),
    .data_ack       (data_ack           )
);

// ============================================================
// CSR

// CSR Read/Modify/Write instructions
assign csr_start = wb_valid && execute.csr;

// instruction retired event
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) instret <= 1'b0;
    else instret <= direct_write 
                    || direct_jump 
                    || lsu_done 
                    || csr_done
                    || (system_call && trap_jump);
end

kronos_csr #(.BOOT_ADDR(BOOT_ADDR)) u_csr (
    .clk                 (clk                 ),
    .rstz                (rstz                ),
    .IR                  (execute.result1     ),
    .wr_data             (execute.result2     ),
    .rd_data             (csr_rd_data         ),
    .csr_start           (csr_start           ),
    .csr_rd              (csr_rd              ),
    .csr_write           (csr_write           ),
    .done                (csr_done            ),
    .instret             (instret             ),
    .activate_trap       (activate_trap       ),
    .return_trap         (return_trap         ),
    .trapped_pc          (trapped_pc          ),
    .trap_cause          (trap_cause          ),
    .trap_value          (trap_value          ),
    .trap_addr           (trap_addr           ),
    .trap_jump           (trap_jump           ),
    .software_interrupt  (software_interrupt  ),
    .timer_interrupt     (timer_interrupt     ),
    .external_interrupt  (external_interrupt  ),
    .core_interrupt      (core_interrupt      ),
    .core_interrupt_cause(core_interrupt_cause)
);

assign activate_trap = state == TRAP;
assign return_trap = state == RETURN;

// ============================================================
// Trap Handling

// Catch direct exceptions/interrupts
// The WB sequencer will only respond to them at the STEADY_STATE
always_comb begin
    exception_caught = 1'b0;
    tcause = '0;
    tvalue = '0;

    if (execute.is_illegal) begin
        // Illegal instructions detected by the decoder
        exception_caught = 1'b1;
        tcause[3:0] = ILLEGAL_INSTR;
        tvalue = execute.result1; // IR
    end
    else if (branch_success && branch_target[1:0] != 2'b00) begin
        // Instructions can only be jumped to at 4B boundary
        // And this only needs to be checked for unconditional jumps 
        // or successful branches
        exception_caught = 1'b1;
        tcause[3:0] = INSTR_ADDR_MISALIGNED;
        tvalue = branch_target;
    end
    /*
    else if (execute.ld && lsu_addr_misaligned) begin
        exception_caught = 1'b1;
        tcause[3:0] = LOAD_ADDR_MISALIGNED;
        tvalue = execute.result1;
    end
    else if (execute.st && lsu_addr_misaligned) begin
        exception_caught = 1'b1;
        tcause[3:0] = STORE_ADDR_MISALIGNED;
        tvalue = execute.result1;
    end
    */
end

// setup for trap
always_ff @(posedge clk) begin
    if (pipe_in_vld && state == STEADY) begin
        if (core_interrupt) begin
            trap_cause <= {1'b1, 27'b0, core_interrupt_cause};
            trap_value <= '0;
        end
        else if (exception_caught) begin
            trap_cause <= {28'b0, tcause};
            trap_value <= tvalue;
        end
        else if (execute.ecall) begin
            trap_cause <= {28'b0, ECALL_MACHINE};
            trap_value <= '0;
        end
        else if (execute.ebreak) begin
            trap_cause <= {28'b0, BREAKPOINT};
            trap_value <= execute.pc;
        end 
    end
    else if (state == WFI) begin
        if (core_interrupt) begin
            trap_cause <= {1'b1, 27'b0, core_interrupt_cause};
            trap_value <= '0;
        end
    end
end

// stow pc
always_ff @(posedge clk) begin
    if (pipe_in_vld && state == STEADY) trapped_pc <= execute.pc;
end

// mark system call instructions for instret
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) system_call <= 1'b0;
    else if (pipe_in_vld && state == STEADY) begin
        if (execute.ecall || execute.ebreak || execute.ret || execute.wfi) begin
            system_call <= 1'b1;
        end
        else begin
            system_call <= 1'b0;
        end
    end
end


// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , lsu_addr_misaligned
};
`endif

endmodule
