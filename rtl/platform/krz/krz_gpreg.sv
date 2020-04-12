// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
KRZ General Purpose Registers

Wishbone slave interface
    - Registered Feedback Bus Cycle, Classic
*/

module krz_gpreg 
    import krz_map::*;
(
    input  logic        clk,
    input  logic        rstz,
    input  logic [7:0]  gpreg_adr_i,
    input  logic [31:0] gpreg_dat_i,
    output logic [31:0] gpreg_dat_o,
    input  logic        gpreg_we_i,
    input  logic        gpreg_stb_i,
    output logic        gpreg_ack_o,
    // GPIO
    output logic [15:0] gpio_dir,
    output logic [15:0] gpio_write,
    input  logic [15:0] gpio_read,
    // UART
    output logic [15:0] uart_prescaler,
    output logic        uart_tx_clear,
    input  logic [15:0] uart_tx_size,
    input  logic        uart_tx_full,
    input  logic        uart_tx_empty
);

logic [5:0] addr;
logic we;
logic ack;

logic [31:0] scratch;
logic [23:0] bootvec;

// ============================================================

// GPREG address is word aligned
assign addr = gpreg_adr_i[7:2];

// Write enable
assign we = gpreg_we_i;

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        scratch <= '0;
        bootvec <= '0;              // bootrom start address
        gpio_dir <= '0;             // default inputs
        gpio_write <= '0;           // default = 0x00
        uart_prescaler <= 16'd207;  // 115200 Hz
        uart_tx_clear <= 1'b0;
    end
    else if (gpreg_stb_i & ~ack) begin
        /* verilator lint_off CASEINCOMPLETE */
        case(addr)
            KRZ_SCRATCH:
                if (we) scratch <= gpreg_dat_i;
                else gpreg_dat_o <= scratch;

            KRZ_BOOTVEC:
                if (we) bootvec <= gpreg_dat_i[23:0];
                else gpreg_dat_o <= {8'h0, bootvec};

            KRZ_GPIO_DIR:
                if (we) gpio_dir <= gpreg_dat_i[15:0];
                else gpreg_dat_o <= {16'h0, gpio_dir};

            KRZ_GPIO_WRITE:
                if (we) gpio_write <= gpreg_dat_i[15:0];
                else gpreg_dat_o <= {16'h0, gpio_write};

            KRZ_GPIO_READ: // Read-Only
                if (~we) gpreg_dat_o <= {16'h0, gpio_read};

            KRZ_UART_PRESCALER:
                if (we) uart_prescaler <= gpreg_dat_i[15:0];
                else gpreg_dat_o <= {16'h0, uart_prescaler};

            KRZ_UART_STATUS: // Read-Only
                if (~we) gpreg_dat_o <= {
                    14'h0, uart_tx_full, uart_tx_empty, uart_tx_size};

            KRZ_UART_CTRL:
                if (we) uart_tx_clear <= gpreg_dat_i[0];
                // else gpreg_dat_o <= {31'h0, uart_tx_clear};
        endcase
        /* verilator lint_on CASEINCOMPLETE */
    end
    else if (ack) begin
        // Clear one-shots
        uart_tx_clear <= 1'b0;
    end
end

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) ack <= 1'b0;
    else if (gpreg_stb_i & ~ack) ack <= 1'b1;
    else ack <= 1'b0;
end

assign gpreg_ack_o = ack;

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , gpreg_adr_i[1:0]
};
`endif

endmodule
