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
    ld          : load
    st          : store
    data_size   : memory access size - byte, half-word or word
    data_sign   : sign extend memory data (only for load)
    illegal     : illegal instruction

Unaligned Access
----------------
Unaligned access are handled by the WB stage as two aligned accesses.
As seen from the outside, the memory access interface is always word aligned.

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
    output logic        data_rd_req,
    output logic        data_wr_req,
    input  logic        data_gnt
);

logic wb_valid;

// load controls
logic is_unaligned;
logic [31:0] mem_addr, mem_addr_next;
logic [1:0] byte_index;
logic [31:0] load_data;
logic [4:0] load_rd;

enum logic [2:0] {
    WRITE,
    READ1,
    READ2,
    LOAD,
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
            else if (execute.ld) next_state = READ1;
        end

        READ1: if (data_gnt) begin
            // Aligned access complete in 1 read, else you need the next word
            if (is_unaligned) next_state = READ2;
            else next_state = LOAD;
        end

        READ2: if (data_gnt) begin
            // Conclude unaligned read access
            next_state = LOAD;
        end

        // Write back load data
        LOAD: next_state = WRITE;

    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

assign pipe_in_rdy = (state == WRITE) && ~execute.illegal;
assign wb_valid = pipe_in_rdy && pipe_in_vld && ~execute.ld;

// ============================================================
// Load

// Memory access controls
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        is_unaligned <= 1'b1;
        mem_addr <= '0;
        mem_addr_next <= '0;
    end
    if (state == WRITE) begin
        // Detect unaligned access
        is_unaligned <= (execute.data_size == HALF && byte_index == 2'b11)
                        || (execute.data_size == WORD && byte_index != 2'b00);

        // Load destination
        load_rd <= execute.rd;

        // Memory address
        mem_addr <= execute.result1;
        mem_addr_next <= execute.result1 + 32'h4;
    end
end

// Memory interfacing
// look-ahead access to the memory (same as fetch stage)
always_comb begin
    if (state == READ1) data_addr = (data_gnt) ? mem_addr_next : mem_addr;
    else if (state == READ2) data_addr = mem_addr_next;
    else data_addr = execute.result1;
end

assign data_rd_req = (state == WRITE && next_state == READ1)
                    || (state == READ1 && (~data_gnt | is_unaligned))
                    || (state == READ2 && ~data_gnt);


// FIXME - Store
assign data_wr_data = '0;
assign data_wr_req = 1'b0;


// ============================================================
// Register Write
// Registers are written either directly or from memory loads
// Direct writes are commited in 1 cycle
// Loads will take 2 cycles for aligned access and 3 for unaligned access

assign regwr_data = (state == LOAD) ? load_data : execute.result1;
assign regwr_sel  = (state == LOAD) ? load_rd   : execute.rd;
assign regwr_en   = (state == LOAD) ? 1'b1      : (wb_valid && execute.rd_write);

// ============================================================
// Branch
// Set PC to result2, if unconditional branch or condition valid (result1 from alu comparator is 1)

assign branch_target = execute.result2;
assign branch = wb_valid && (execute.branch || (execute.branch_cond && execute.result1[0]));

endmodule
