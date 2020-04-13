// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*

KRZ System Peripheral Bus

- Multiplex access to the system peripherals
- Bridge 32-bit transactions from the KRZ Crossbar to 8-bit peripherals,
  as well as 32-bit ones.
- The 32b transactions for 8b peripherals are sequenced as per byte selections in SEL.
- The ADR from the core needs to be word aligned, and the SEL can only be one of:
    0001 : 1 byte
    0011 : 2 bytes
    1111 : 4 bytes
- 32b peripherals always execute word transactions (SEL is ignored, but should be 0xF)
- The bus errors out when the addr is invalid (unknown peripheral or invalid SEL)

For system address map, see: krz_map

Crossbar facing: Wishbone slave interface
    - Registered Feedback Bus Cycle, Classic
*/

module krz_sysbus
    import krz_map::*;
(
    input  logic        clk,
    input  logic        rstz,
    // Crossbar
    input  logic [23:0] sys_adr_i,
    input  logic [31:0] sys_dat_i,
    output logic [31:0] sys_dat_o,
    input  logic        sys_we_i,
    input  logic [3:0]  sys_sel_i,
    input  logic        sys_stb_i,
    output logic        sys_ack_o,
    // Peripheral Common Bus
    output logic [7:0]  perif_adr_o,
    output logic [31:0] perif_dat_o,
    output logic        perif_we_o,
    // Peripheral STB
    output logic        gpreg_stb_o,
    output logic        uart_stb_o,
    output logic        spim_stb_o,
    // Peripheral ACK
    input  logic        gpreg_ack_i,
    input  logic        uart_ack_i,
    input  logic        spim_ack_i,
     // Peripheral read data
    input  logic [31:0] gpreg_dat_i,
    input  logic [7:0]  uart_dat_i,
    input  logic [7:0]  spim_dat_i
);

logic mask_valid, addr_valid;
logic sys_req_valid;

logic sys_rd_req, sys_wr_req;
logic gpreg_rd_req, gpreg_wr_req;
logic uart_rd_req, uart_wr_req;
logic spim_rd_req, spim_wr_req;

logic [7:0] addr;
logic [31:0] data, read_data;
logic [3:0] mask;
logic ack;

enum logic [1:0] {
    NONE,
    GPREG,
    UART,
    SPIM
} gnt;

logic is_write;

enum logic [2:0] {
    IDLE,
    READ8,
    WRITE8,
    READ32,
    WRITE32,
    ACK,
    ERROR
} state, next_state;

// ============================================================
// Arbiter

// Check if the system bus transaction is valid
assign mask_valid = sys_sel_i == 4'h1 || sys_sel_i == 4'h3 || sys_sel_i == 4'hF;
assign addr_valid = sys_adr_i[1:0] == 2'b00;
assign sys_req_valid = mask_valid & addr_valid;

assign sys_rd_req = sys_stb_i & ~sys_we_i;
assign sys_wr_req = sys_stb_i &  sys_we_i;

// 0x800100: GPREG
assign gpreg_rd_req  = sys_rd_req & sys_adr_i[PAGE_GPREG+8];
assign gpreg_wr_req  = sys_wr_req & sys_adr_i[PAGE_GPREG+8];

// 0x800200: UART
assign uart_rd_req = sys_rd_req & sys_adr_i[PAGE_UART+8];
assign uart_wr_req = sys_wr_req & sys_adr_i[PAGE_UART+8];

// 0x800400: SPIM
assign spim_rd_req = sys_rd_req & sys_adr_i[PAGE_SPIM+8];
assign spim_wr_req = sys_wr_req & sys_adr_i[PAGE_SPIM+8];

// Register grant and peripheral bus STB
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        gnt <= NONE;
        gpreg_stb_o <= 1'b0;
        uart_stb_o <= 1'b0;
        spim_stb_o <= 1'b0;
    end
    else begin
        if (state == IDLE && sys_stb_i && sys_req_valid) begin 
            if (gpreg_rd_req || gpreg_wr_req) begin
                gnt <= GPREG;
                gpreg_stb_o <= 1'b1;
            end
            else if (uart_rd_req || uart_wr_req) begin
                gnt <= UART;
                uart_stb_o <= 1'b1;
            end
            else if (spim_rd_req || spim_wr_req) begin
                gnt <= SPIM;
                spim_stb_o <= 1'b1;
            end
        end
        else if (next_state == ACK) begin
            gnt <= NONE;
            gpreg_stb_o <= 1'b0;
            uart_stb_o <= 1'b0;
            spim_stb_o <= 1'b0;
        end
    end
end

// ============================================================
// Transaction sequencer
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        IDLE: if (sys_stb_i) begin

            if (~sys_req_valid) next_state = ERROR;
            else if (gpreg_rd_req) next_state = READ32;
            else if (gpreg_wr_req) next_state = WRITE32;
            else if (uart_rd_req || spim_rd_req) next_state = READ8;
            else if (uart_wr_req || spim_wr_req) next_state = WRITE8;
            else next_state = ERROR;

        end

        READ32,
        WRITE32: if (ack) next_state = ACK;
        
        READ8,
        WRITE8: if (ack && ~mask[1]) next_state = ACK;

        ACK: next_state = IDLE;

        ERROR: next_state = ERROR;
    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Register peripheral bus IO
always_ff @(posedge clk) begin
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        IDLE: if (sys_stb_i && sys_req_valid) begin
            // Initialize
            if (sys_wr_req) begin
                is_write <= 1'b1;
                data <= sys_dat_i;
            end
            else begin
                is_write <= 1'b0;
                data <= '0;
            end

            addr <= sys_adr_i[7:0];
            mask <= sys_sel_i;
        end

        READ32: if (ack) begin
            // Read word from peripherals
            data <= read_data;
        end

        WRITE8: if (ack) begin
            // Shift out bytes, one at a time
            data <= {8'h0, data[31:8]};

            // Track bytes remaining by left shifting the mask
            mask <= {1'b0, mask[3:1]};
        end

        READ8: if (ack) begin
            // Shift in bytes
            data <= {data[23:0], read_data[7:0]};
            // Track bytes
            mask <= {1'b0, mask[3:1]};
        end
    endcase // state
end

// ============================================================
// Peripheral Wiring

assign perif_adr_o = addr;
assign perif_dat_o = data;
assign perif_we_o  = is_write;

// Mux the read data and ACK from the peripherals
always_comb begin
    case (gnt)
        GPREG  : begin
            ack = gpreg_ack_i;
            read_data = gpreg_dat_i;
        end
        UART    : begin
            ack = uart_ack_i;
            read_data = {24'h0, uart_dat_i};
        end
        SPIM    : begin
            ack = spim_ack_i;
            read_data = {24'h0, spim_dat_i};
        end
        default : begin
            ack = 1'b0;
            read_data = '0;
        end
    endcase // gnt
end

// ============================================================
// Crossbar Wiring

// Register a clean ACK signal for the crossbar
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) sys_ack_o <= 1'b0;
    else if (next_state == ACK) sys_ack_o <= 1'b1;
    else sys_ack_o <= 1'b0;
end

assign sys_dat_o = data;


// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , mask[0]
};
`endif

endmodule