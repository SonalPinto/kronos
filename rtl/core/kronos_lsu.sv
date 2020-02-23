// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Load Store Unit

Control unit that interfaces with "Data" memory and fullfills
Load/Store intstructions

Unaligned access are handled by the LSU as two aligned accesses.
As seen from the outside, the memory access interface is always word aligned.

*/

module kronos_lsu
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    // WB data interface
    input  logic [31:0] addr,
    output logic [31:0] load_data,
    output logic [4:0]  load_rd,
    output logic        load_en,
    input  logic [31:0] store_data,
    // WB Controls
    input  logic        start,
    output logic        done,
    input  logic [4:0]  rd,
    input  logic        ld,
    input  logic        st,
    input  logic [1:0]  data_size,
    input  logic        data_uns,
    // Memory interface
    output logic [31:0] data_addr,
    input  logic [31:0] data_rd_data,
    output logic [31:0] data_wr_data,
    output logic        data_rd_req,
    output logic        data_wr_req,
    input  logic        data_gnt
);

logic [31:0] addr_word_index;
logic [1:0] addr_byte_index;
logic [1:0] offset;

logic is_unaligned;
logic [1:0] mem_size;
logic load_uns;
logic [31:0] mem_addr, mem_addr_next;

logic [3:0][7:0] mdata, tmdata;

logic [7:0] byte_data;
logic [15:0] half_data;
logic [31:0] load_byte_data;
logic [31:0] load_half_data;
logic [31:0] load_word_data;

enum logic [2:0] {
    IDLE,
    READ1,
    READ2,
    LOAD
} state, next_state;

// ============================================================
// LSU Sequencer

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        IDLE: if (start) begin
            if (ld) next_state = READ1;
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
        LOAD: next_state = IDLE;

    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// WB interface
assign load_en = state == LOAD;
assign done = load_en;

// Address segments
// addr_word_index - is 4B aligned, and is used to interface with Data Memory
// addr_byte_index - represents the byte offset in 4B aligned access
assign addr_word_index = {addr[31:2], 2'b0};
assign addr_byte_index = addr[1:0];

// Memory access controls
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        is_unaligned <= 1'b1;
        mem_addr <= '0;
        mem_addr_next <= '0;
    end
    if (state == IDLE) begin
        // Detect unaligned access
        is_unaligned <= (data_size == HALF && addr_byte_index == 2'b11)
                        || (data_size == WORD && addr_byte_index != 2'b00);

        // stow controls
        load_rd <= rd;
        mem_size <= data_size;
        load_uns <= data_uns;

        // Memory address - 4B aligned
        mem_addr <= addr_word_index;
        mem_addr_next <= addr_word_index + 32'h4;

        // LSByte offset
        offset <= addr_byte_index;
    end
end

// ============================================================
// Load

// byte cast
assign mdata = data_rd_data;

// select BYTE data
always_comb begin
    // BYTE loads are always aligned
    byte_data = mdata[offset];
    
    // Sign extend
    if (load_uns) load_byte_data = {24'b0, byte_data};
    else load_byte_data = {{24{byte_data[7]}}, byte_data};
end

// Select HALF data
always_comb begin
    // HALF loads are misaligned if offset is 3
    // Hence for misaligned HALF loads, the load_data is only
    // when two reads are done
    case(offset)
        2'b00: half_data = {mdata[1:0]};
        2'b01: half_data = {mdata[2:1]};
        2'b10: half_data = {mdata[3:2]};
        2'b11: half_data = {mdata[0], tmdata[3]};
    endcase // offset

    // Sign extend
    if (load_uns) load_half_data = {16'b0, half_data};
    else load_half_data = {{16{half_data[15]}}, half_data};
end

// Select WORD data
always_comb begin
    // WORD loads are misaligned if offset is not 0
    // Hence for misaligned WORD loads, you need 2 reads, same as HALF
    case(offset)
        2'b00: load_word_data = mdata;
        2'b01: load_word_data = {mdata[0]  , tmdata[3:1]};
        2'b10: load_word_data = {mdata[1:0], tmdata[3:2]};
        2'b11: load_word_data = {mdata[2:0], tmdata[3]};
    endcase // offset
end

// Setup Load Data
// Some loads take 2 cycles, if misaligned
always_ff @(posedge clk) begin
    if (data_gnt) begin
        // store for misaligned access
        tmdata <= mdata;

        /* verilator lint_off CASEINCOMPLETE */
        case(mem_size)
            BYTE: load_data <= load_byte_data;
            HALF: load_data <= load_half_data;
            WORD: load_data <= load_word_data;
        endcase // mem_size
        /* verilator lint_on CASEINCOMPLETE */
    end
end

// ============================================================
// Memory Inerface
// look-ahead access to the memory (same as fetch stage)
always_comb begin
    if (state == READ1) data_addr = (data_gnt) ? mem_addr_next : mem_addr;
    else if (state == READ2) data_addr = mem_addr_next;
    else data_addr = addr_word_index;
end

assign data_rd_req = (state == IDLE && next_state == READ1)
                    || (state == READ1 && (~data_gnt | is_unaligned))
                    || (state == READ2 && ~data_gnt);

// FIXME - Store
assign data_wr_data = '0;
assign data_wr_req = 1'b0;

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , tmdata[0]
};
`endif

endmodule