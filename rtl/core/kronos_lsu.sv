// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Load Store Unit

Control unit that interfaces with "Data" memory and fulfills
Load/Store instructions

Misaligned access which require a boundary cross are handled by the LSU as two aligned accesses.
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
    output logic        data_wr_en,
    output logic        data_req,
    input  logic        data_ack
);

logic [31:0] addr_word_index;
logic [1:0] addr_byte_index;
logic [1:0] offset;

logic boundary_cross;
logic [1:0] mem_size;
logic load_uns;
logic load_write_ok;

logic [3:0][7:0] mdata, rdata, trdata;

logic load_done;
logic [7:0] byte_data;
logic [15:0] half_data;
logic [31:0] load_byte_data;
logic [31:0] load_half_data;
logic [31:0] load_word_data;

logic store_done;
logic [3:0][7:0] sdata, wdata;
logic [1:0][3:0] wmask;
logic [3:0] twmask;

enum logic [2:0] {
    IDLE,
    READ1,
    READ2,
    LOAD,
    WRITE1,
    WRITE2,
    STORE
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

        READ1: if (data_ack) begin
            // Aligned access complete in 1 read, else you need the next word
            if (boundary_cross) next_state = READ2;
            else next_state = LOAD;
        end

        READ2: if (data_ack) next_state = LOAD;

        LOAD: next_state = IDLE;

        WRITE1: if (data_ack) begin
            // Write onto two words if access requires a boundary cross
            if (boundary_cross) next_state = WRITE2;
            else next_state = STORE;
        end

        WRITE2: if (data_ack) next_state = STORE;

        STORE: next_state = IDLE;

    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Address segments
// addr_word_index - is 4B aligned, and is used to interface with Data Memory
// addr_byte_index - represents the byte offset in 4B aligned access
assign addr_word_index = {addr[31:2], 2'b0};
assign addr_byte_index = addr[1:0];

// Address is misaligned if the ADDR % size != 0
// Byte access is always aligned - since bytes are the smalled addressable unit
// Halfword access is unaligned if the byte index is 1 or 3, i.e. addr[1] is set
// Word access is unaligned if the byte index is not 0, i.e. addr[1:0] is non 0
assign addr_misaligned = (data_size == HALF && addr_byte_index[1])
                || (data_size == WORD && |{addr_byte_index});

// Memory access controls
always_ff @(posedge clk or negedge rstz) begin
    if (state == IDLE && start) begin
        // Boundary cross is required if the access needs to happen across two memory addresses
        boundary_cross <= (data_size == HALF && addr_byte_index == 2'b11)
                        || (data_size == WORD && |{addr_byte_index});

        // stow controls
        load_rd <= rd;
        mem_size <= data_size;
        load_uns <= data_uns;

        // Cancel the register write back for rd == 0
        load_write_ok <= rd != '0;

        // LSByte offset
        offset <= addr_byte_index;
    end
end

// ============================================================
// Load

// byte cast
assign mdata = data_rd_data;

// register read data
always_ff @(posedge clk) begin
    // setup write data
    if (data_ack) begin
        // Barrel Rotate Right memory read bytes as per offset
        case(offset)
            2'b00: rdata <= mdata;
            2'b01: rdata <= {mdata[0]  , mdata[3:1]};
            2'b10: rdata <= {mdata[1:0], mdata[3:2]};
            2'b11: rdata <= {mdata[2:0], mdata[3]};
        endcase

        // store for boundary cross access
        trdata <= rdata;
    end
end

// select BYTE data
always_comb begin
    // BYTE loads are always aligned, and don't need a boundary cross
    byte_data = rdata[0];
    
    // Sign extend
    if (load_uns) load_byte_data = {24'b0, byte_data};
    else load_byte_data = {{24{byte_data[7]}}, byte_data};
end

// Select HALF data
always_comb begin
    // HALF loads need a boundary cross if offset is 3
    // Hence for such HALF loads, the load_data is only
    // valid when two reads are done
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
    // WORD loads need a boundary cross if offset is not 0
    // Hence for such WORD loads, you need 2 reads, same as HALF
    case(offset)
        2'b00: load_word_data = rdata;
        2'b01: load_word_data = {rdata[3]  , trdata[2:0]};
        2'b10: load_word_data = {rdata[3:2], trdata[1:0]};
        2'b11: load_word_data = {rdata[3:1], trdata[0]};
    endcase // offset
end

// Setup Load Data
// Some loads take 2 cycles, if boundary cross is required
always_comb begin
    if (mem_size == BYTE) load_data = load_byte_data;
    else if (mem_size == HALF) load_data = load_half_data;
    else load_data = load_word_data;
end

// Load operation done status
assign load_done = state == LOAD;

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
    // and the higher nibble in the second write (for boundary cross)
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
        // Stow mask
        twmask <= wmask[1];
    end
end

// Store operation done status
assign store_done = state == STORE;

// ============================================================
// Memory Interface

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        data_req <= 1'b0;
        data_wr_en <= 1'b0;
    end
    else begin
        /* verilator lint_off CASEINCOMPLETE */
        case (state)
            IDLE: if (start) begin
                data_req <= 1'b1;

                // Memory address - 4B aligned
                data_addr <= addr_word_index;

                // data write
                data_wr_en <= st;
                data_wr_data <= wdata;
                data_wr_mask <= wmask[0];
            end

            READ1,
            WRITE1: if (data_ack) begin
                if (boundary_cross) begin
                    data_req <= 1'b1;

                    // Next address for boundary cross access
                    data_addr <= data_addr + 32'h4;

                    // continue write
                    if (data_wr_en) data_wr_mask <= twmask;
                end
                else begin
                    data_req <= 1'b0;
                    data_wr_en <= 1'b0;
                end
            end

            READ2,
            WRITE2: if (data_ack) begin 
                data_req <= 1'b0;
                data_wr_en <= 1'b0;
            end
        endcase
        /* verilator lint_on CASEINCOMPLETE */
    end
end

// WB Done status
assign done = load_done || store_done;

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , trdata[3]
};
`endif

endmodule