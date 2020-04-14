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
    input  logic [5:0]  adr_i,
    input  logic [31:0] dat_i,
    output logic [31:0] dat_o,
    input  logic        we_i,
    input  logic        stb_i,
    output logic        ack_o,
    // GPIO
    output logic [15:0] gpio_dir,
    output logic [15:0] gpio_write,
    input  logic [15:0] gpio_read,
    // UART
    output logic [11:0] uart_prescaler,
    output logic        uart_tx_clear,
    input  logic [7:0]  uart_tx_size,
    // SPIM
    output logic [7:0]  spim_prescaler,
    output logic        spim_cpol,
    output logic        spim_cpha,
    output logic        spim_tx_clear,
    output logic        spim_rx_clear,
    input  logic [7:0]  spim_tx_size,
    input  logic [7:0]  spim_rx_size
);

logic ack;
logic [31:0] scratch;
logic [23:0] bootvec;

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        scratch <= '0;
        bootvec <= 24'h100000;      // 1M location in Flash

        gpio_dir <= '0;             // default inputs
        gpio_write <= '0;           // default = 0x00

        uart_prescaler <= 12'd207;  // 115200 Hz
        uart_tx_clear <= 1'b0;

        spim_prescaler <= 8'd11;   // 1MHz
        spim_cpol <= 1'b0;          // Mode-0
        spim_cpha <= 1'b0;
        spim_tx_clear <= 1'b0;
        spim_rx_clear <= 1'b0;
    end
    else if (stb_i & ~ack) begin
        /* verilator lint_off CASEINCOMPLETE */
        case(adr_i)
            // ------------------------------------------------
            KRZ_SCRATCH:
                if (we_i) scratch <= dat_i;
                else dat_o <= scratch;

            // ------------------------------------------------
            KRZ_BOOTVEC:
                if (we_i) bootvec <= dat_i[23:0];
                else dat_o <= {8'h0, bootvec};

            // ------------------------------------------------
            KRZ_GPIO_DIR:
                if (we_i) gpio_dir <= dat_i[15:0];
                else dat_o <= {16'h0, gpio_dir[15:0]};

            KRZ_GPIO_WRITE:
                if (we_i) gpio_write <= dat_i[15:0];
                else dat_o <= {16'h0, gpio_write[15:0]};

            KRZ_GPIO_READ:
                if (~we_i) dat_o <= {16'h0, gpio_read[15:0]};

            // ------------------------------------------------
            KRZ_UART_CTRL:
                if (we_i) begin
                    uart_prescaler <= dat_i[11:0];
                    uart_tx_clear <= dat_i[12];
                end
                else begin
                    dat_o <= {20'h0, uart_prescaler};
                end

            KRZ_UART_STATUS: // Read-Only
                if (~we_i) dat_o <= {24'h0, uart_tx_size};

            // ------------------------------------------------
            KRZ_SPIM_CTRL:
                if (we_i) begin
                    spim_prescaler <= dat_i[7:0];
                    spim_cpol <= dat_i[8];
                    spim_cpha <= dat_i[9];
                    spim_tx_clear <= dat_i[10];
                    spim_rx_clear <= dat_i[11];
                end
                else begin
                    dat_o <= {22'h0, spim_cpha, spim_cpol, spim_prescaler};
                end
            
            KRZ_SPIM_STATUS: // Read-Only
                if (~we_i) dat_o <= {16'h0, spim_rx_size, spim_tx_size};

        endcase
        /* verilator lint_on CASEINCOMPLETE */
    end
    else if (ack) begin
        // Clear one-shots
        uart_tx_clear <= 1'b0;
        spim_tx_clear <= 1'b0;
        spim_rx_clear <= 1'b0;
    end
end

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) ack <= 1'b0;
    else if (stb_i & ~ack) ack <= 1'b1;
    else ack <= 1'b0;
end

assign ack_o = ack;

endmodule
