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
    // SPIM
    output logic [15:0] spim_prescaler,
    output logic        spim_cpol,
    output logic        spim_cpha,
    output logic        spim_tx_clear,
    output logic        spim_rx_clear,
    input  logic [15:0] spim_tx_size,
    input  logic [15:0] spim_rx_size
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
        bootvec <= 24'h100000;    // 1M location in Flash

        gpio_dir <= '0;             // default inputs
        gpio_write <= '0;           // default = 0x00

        uart_prescaler <= 16'd207;  // 115200 Hz
        uart_tx_clear <= 1'b0;

        spim_prescaler <= 16'd11;   // 1MHz
        spim_cpol <= 1'b0;          // Mode-0
        spim_cpha <= 1'b0;
        spim_tx_clear <= 1'b0;
        spim_rx_clear <= 1'b0;
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

            KRZ_UART_CTRL:
                if (we) begin
                    uart_prescaler <= gpreg_dat_i[15:0];
                    uart_tx_clear <= gpreg_dat_i[16];
                end
                else begin
                    gpreg_dat_o <= {16'h0, uart_prescaler};
                end

            KRZ_UART_STATUS: // Read-Only
                if (~we) gpreg_dat_o <= {16'h0, uart_tx_size};

            KRZ_SPIM_CTRL:
                if (we) begin
                    spim_prescaler <= gpreg_dat_i[15:0];
                    spim_cpol <= gpreg_dat_i[16];
                    spim_cpha <= gpreg_dat_i[17];
                    spim_tx_clear <= gpreg_dat_i[18];
                    spim_rx_clear <= gpreg_dat_i[19];
                end
                else begin
                    gpreg_dat_o <= {14'h0, spim_cpha, spim_cpol, spim_prescaler};
                end
            
            KRZ_SPIM_STATUS: // Read-Only
                if (~we) gpreg_dat_o <= {spim_rx_size, spim_tx_size};

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
