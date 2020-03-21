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
    output logic        load_write,
    input  logic [31:0] store_data,
    // WB Controls
    input  logic        start,
    output logic        done,
    input  logic [4:0]  rd,
    input  logic        ld,
    input  logic        st,
    input  logic [1:0]  data_size,
    input  logic        data_uns,
    output logic        addr_misaligned,
    // Memory interface
    output logic [31:0] data_addr,
    input  logic [31:0] data_rd_data,
    output logic [31:0] data_wr_data,
    output logic [3:0]  data_wr_mask,
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
logic load_write_ok;
logic [31:0] mem_addr, mem_addr_next;

logic [3:0][7:0] mdata, rdata, trdata;

logic load_done;
logic [7:0] byte_data;
logic [15:0] half_data;
logic [31:0] load_byte_data;
logic [31:0] load_half_data;
logic [31:0] load_word_data;

logic store_done;
logic [3:0][7:0] sdata, wdata, twdata;
logic [1:0][3:0] wmask, twmask;

enum logic [2:0] {
    IDLE,
    READ1,
    READ2,
    WRITE1,
    WRITE2
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
            else if (st) next_state = WRITE1;
        end

        READ1: if (data_gnt) begin
            // Aligned access complete in 1 read, else you need the next word
            if (is_unaligned) next_state = READ2;
            else next_state = IDLE;
        end

        READ2: if (data_gnt) next_state = IDLE;

        WRITE1: if (data_gnt) begin
            // Write onto two words if access is unaligned
            if (is_unaligned) next_state = WRITE2;
            else next_state = IDLE;
        end

        WRITE2: if (data_gnt) next_state = IDLE;

    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Address segments
// addr_word_index - is 4B aligned, and is used to interface with Data Memory
// addr_byte_index - represents the byte offset in 4B aligned access
assign addr_word_index = {addr[31:2], 2'b0};
assign addr_byte_index = addr[1:0];

assign addr_misaligned = (data_size == HALF && addr_byte_index == 2'b11)
                        || (data_size == WORD && addr_byte_index != 2'b00);

// Memory access controls
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        is_unaligned <= 1'b1;
        mem_addr <= '0;
        mem_addr_next <= '0;
    end
    else if (state == IDLE && start) begin
        // Detect unaligned access
        is_unaligned <= addr_misaligned;

        // stow controls
        load_rd <= rd;
        mem_size <= data_size;
        load_uns <= data_uns;

        // Cancel the register writeback for rd == 0
        load_write_ok <= rd != '0;

        // Memory address - 4B aligned
        mem_addr <= addr_word_index;
        mem_addr_next <= addr_word_index + 32'h4;

        // LSByte offset
        offset <= addr_byte_index;
    end
end

// ============================================================
// Load

always_comb begin
    // byte cast
    mdata = data_rd_data;

    // setup write data
    // Barrel Rotate Right memory read bytes as per offset
    case(offset)
        2'b00: rdata = mdata;
        2'b01: rdata = {mdata[0]  , mdata[3:1]};
        2'b10: rdata = {mdata[1:0], mdata[3:2]};
        2'b11: rdata = {mdata[2:0], mdata[3]};
    endcase
end

// select BYTE data
always_comb begin
    // BYTE loads are always aligned
    byte_data = rdata[0];
    
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
        2'b00,
        2'b01,
        2'b10: half_data = rdata[1:0];
        2'b11: half_data = {rdata[1], trdata[0]};
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
        2'b00: load_word_data = rdata;
        2'b01: load_word_data = {rdata[3]  , trdata[2:0]};
        2'b10: load_word_data = {rdata[3:2], trdata[1:0]};
        2'b11: load_word_data = {rdata[3:1], trdata[0]};
    endcase // offset
end

always_ff @(posedge clk) begin
    if (data_gnt) begin
        // store for misaligned access
        trdata <= rdata;
    end
end

// Setup Load Data
// Some loads take 2 cycles, if misaligned
always_comb begin
    if (mem_size == BYTE) load_data = load_byte_data;
    else if (mem_size == HALF) load_data = load_half_data;
    else load_data = load_word_data;
end

// Load operation done status
assign load_done = (state == READ1 || state == READ2) && next_state == IDLE;

// Cancel register write back if destination is x0
assign load_write = load_done && load_write_ok;

// ============================================================
// Store

always_comb begin
    // byte cast
    sdata = store_data;

    // setup write data
    // Barrel Rotate Left store_data bytes as per offset
    case(addr_byte_index)
        2'b00: wdata = sdata;
        2'b01: wdata = {sdata[2:0], sdata[3]};
        2'b10: wdata = {sdata[1:0], sdata[3:2]};
        2'b11: wdata = {sdata[0]  , sdata[3:1]};
    endcase

    // Setup write byte-level mask
    // The lower nibble is used as a mask in the first write
    // and the higher nibble in the second write (for unaligned access only)
    if (data_size == BYTE) begin
        wmask = 8'h1 << addr_byte_index;
    end
    else if (data_size == HALF) begin
        wmask = 8'h3 << addr_byte_index;
    end
    else begin
        wmask = 8'hF << addr_byte_index;
    end
end

always_ff @(posedge clk) begin
    if (state == IDLE && start) begin
        // Stow data/mask
        twdata <= wdata;
        twmask <= wmask;
    end
end

// Store operation done status
assign store_done = (state == WRITE1 || state == WRITE2) && next_state == IDLE;

// ============================================================
// Memory Inerface
// look-ahead access to the memory (same as fetch stage)
always_comb begin
    if (state == READ1 || state == WRITE1) begin
        data_addr = (data_gnt) ? mem_addr_next : mem_addr;
    end
    else if (state == READ2 || state == WRITE2) begin
        data_addr = mem_addr_next;
    end 
    else begin 
        data_addr = addr_word_index;
    end
end

assign data_rd_req = (state == IDLE && next_state == READ1)
                    || (state == READ1 && (~data_gnt | is_unaligned))
                    || (state == READ2 && ~data_gnt);

assign data_wr_req = (state == IDLE && next_state == WRITE1)
                    || (state == WRITE1 && (~data_gnt | is_unaligned))
                    || (state == WRITE2 && ~data_gnt);

always_comb begin
    if (state == WRITE1) begin
        data_wr_mask = (data_gnt) ? twmask[1] : twmask[0];
        data_wr_data = twdata;
    end
    else if (state == WRITE2) begin
        data_wr_mask = twmask[1];
        data_wr_data = twdata;
    end 
    else begin 
        data_wr_mask = wmask[0];
        data_wr_data = wdata;
    end
end

// WB Done status
assign done = load_done | store_done;

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , trdata[3]
};
`endif

endmodule