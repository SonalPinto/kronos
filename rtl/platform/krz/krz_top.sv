// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos: Zero Degree
*/

module krz_top (
    input  logic    RSTN,
    inout  wire     GPIO0,
    inout  wire     GPIO1,
    output logic    TX
);

logic clk, rstz;
logic [1:0] reset_sync;

logic [31:0] instr_addr;
logic [31:0] instr_data;
logic instr_req;
logic instr_ack;
logic [31:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_mask;
logic data_wr_en;
logic data_req;
logic data_ack;

logic [23:0] bootrom_addr;
logic [31:0] bootrom_rd_data;
logic bootrom_en;

logic [23:0] mem0_addr;
logic [31:0] mem0_rd_data;
logic [31:0] mem0_wr_data;
logic mem0_en;
logic mem0_wr_en;
logic [3:0] mem0_mask;

logic [23:0] mem1_addr;
logic [31:0] mem1_rd_data;
logic [31:0] mem1_wr_data;
logic mem1_en;
logic mem1_wr_en;
logic [3:0] mem1_mask;

logic [23:0] sys_adr;
logic [31:0] sys_rdat;
logic [31:0] sys_wdat;
logic sys_we;
logic [3:0] sys_sel;
logic sys_stb;
logic sys_ack;

logic [7:0] gpreg_adr;
logic [31:0] gpreg_rdat;
logic [31:0] gpreg_wdat;
logic gpreg_we;
logic gpreg_stb;
logic gpreg_ack;

logic [7:0] uart_rdat;
logic [7:0] uart_wdat;
logic uart_we;
logic uart_stb;
logic uart_tx_ack;
logic uart_rx_ack;
logic uart_ack;

logic [15:0] gpio_dir;
logic [15:0] gpio_write;
logic [15:0] gpio_read;

logic [15:0] uart_prescaler;
logic uart_tx_clear;
logic [15:0] uart_tx_size;
logic uart_tx_full;
logic uart_tx_empty;


// ============================================================
// Clock and Reset
// ============================================================

// 24MHz internal oscillator
HSOSC #(.CLKHF_DIV ("0b01")) u_osc (
  .CLKHFPU(1'b1),
  .CLKHFEN(1'b1),
  .CLKHF  (clk) 
);

// synchronize reset
always_ff @(posedge clk or negedge RSTN) begin
    if (~RSTN) reset_sync <= '0;
    else reset_sync <= {reset_sync[0], RSTN};
end
assign rstz = reset_sync[1];

// ============================================================
// Kronos
// ============================================================

kronos_core #(
    .BOOT_ADDR        (32'h0),
    .MCYCLE_IS_32BIT  (1'b1 ),
    .MINSTRET_IS_32BIT(1'b1 )
) u_core (
    .clk               (clk         ),
    .rstz              (rstz        ),
    .instr_addr        (instr_addr  ),
    .instr_data        (instr_data  ),
    .instr_req         (instr_req   ),
    .instr_ack         (instr_ack   ),
    .data_addr         (data_addr   ),
    .data_rd_data      (data_rd_data),
    .data_wr_data      (data_wr_data),
    .data_mask         (data_mask   ),
    .data_wr_en        (data_wr_en  ),
    .data_req          (data_req    ),
    .data_ack          (data_ack    ),
    .software_interrupt(1'b0        ),
    .timer_interrupt   (1'b0        ),
    .external_interrupt(1'b0        )
);

// ============================================================
// Primary Crossbar and Memory
// ============================================================

krz_xbar u_xbar (
    .clk            (clk             ),
    .rstz           (rstz            ),
    .instr_addr     (instr_addr[23:0]),
    .instr_data     (instr_data      ),
    .instr_req      (instr_req       ),
    .instr_ack      (instr_ack       ),
    .data_addr      (data_addr[23:0] ),
    .data_rd_data   (data_rd_data    ),
    .data_wr_data   (data_wr_data    ),
    .data_mask      (data_mask       ),
    .data_wr_en     (data_wr_en      ),
    .data_req       (data_req        ),
    .data_ack       (data_ack        ),
    .bootrom_addr   (bootrom_addr    ),
    .bootrom_rd_data(bootrom_rd_data ),
    .bootrom_en     (bootrom_en      ),
    .mem0_addr      (mem0_addr       ),
    .mem0_rd_data   (mem0_rd_data    ),
    .mem0_wr_data   (mem0_wr_data    ),
    .mem0_en        (mem0_en         ),
    .mem0_wr_en     (mem0_wr_en      ),
    .mem0_mask      (mem0_mask       ),
    .mem1_addr      (mem1_addr       ),
    .mem1_rd_data   (mem1_rd_data    ),
    .mem1_wr_data   (mem1_wr_data    ),
    .mem1_en        (mem1_en         ),
    .mem1_wr_en     (mem1_wr_en      ),
    .mem1_mask      (mem1_mask       ),
    .sys_adr_o      (sys_adr       ),
    .sys_dat_i      (sys_rdat       ),
    .sys_dat_o      (sys_wdat       ),
    .sys_we_o       (sys_we        ),
    .sys_sel_o      (sys_sel       ),
    .sys_stb_o      (sys_stb       ),
    .sys_ack_i      (sys_ack       )
);

ice40up_ebr4K #(.AWIDTH(24)) u_bootrom (
    .clk    (~clk           ),
    .addr   (bootrom_addr   ),
    .wdata  (32'h0          ),
    .rdata  (bootrom_rd_data),
    .en     (bootrom_en     ),
    .wr_en  (1'b0           ),
    .mask   (4'hF           )
);

ice40up_sram64K #(.AWIDTH(24)) u_mem0 (
    .clk  (~clk        ),
    .addr (mem0_addr   ),
    .wdata(mem0_wr_data),
    .rdata(mem0_rd_data),
    .en   (mem0_en     ),
    .wr_en(mem0_wr_en  ),
    .mask (mem0_mask   )
);

ice40up_sram64K #(.AWIDTH(24)) u_mem1 (
    .clk  (~clk        ),
    .addr (mem1_addr   ),
    .wdata(mem1_wr_data),
    .rdata(mem1_rd_data),
    .en   (mem1_en     ),
    .wr_en(mem1_wr_en  ),
    .mask (mem1_mask   )
);

// ============================================================
// System
// ============================================================

// System Bus
krz_sysbus u_sysbus (
    .clk        (clk       ),
    .rstz       (rstz      ),
    .sys_adr_i  (sys_adr   ),
    .sys_dat_i  (sys_wdat  ),
    .sys_dat_o  (sys_rdat  ),
    .sys_we_i   (sys_we    ),
    .sys_sel_i  (sys_sel   ),
    .sys_stb_i  (sys_stb   ),
    .sys_ack_o  (sys_ack   ),
    .gpreg_adr_o(gpreg_adr ),
    .gpreg_dat_i(gpreg_rdat),
    .gpreg_dat_o(gpreg_wdat),
    .gpreg_we_o (gpreg_we  ),
    .gpreg_stb_o(gpreg_stb ),
    .gpreg_ack_i(gpreg_ack ),
    .uart_dat_i (uart_rdat ),
    .uart_dat_o (uart_wdat ),
    .uart_we_o  (uart_we   ),
    .uart_stb_o (uart_stb  ),
    .uart_ack_i (uart_ack  )
);

// General Purpose Registers
krz_gpreg u_gpr (
    .clk           (clk           ),
    .rstz          (rstz          ),
    .gpreg_adr_i   (gpreg_adr     ),
    .gpreg_dat_i   (gpreg_wdat    ),
    .gpreg_dat_o   (gpreg_rdat    ),
    .gpreg_we_i    (gpreg_we      ),
    .gpreg_stb_i   (gpreg_stb     ),
    .gpreg_ack_o   (gpreg_ack     ),
    .gpio_dir      (gpio_dir      ),
    .gpio_write    (gpio_write    ),
    .gpio_read     (gpio_read     ),
    .uart_prescaler(uart_prescaler),
    .uart_tx_clear (uart_tx_clear ),
    .uart_tx_size  (uart_tx_size  ),
    .uart_tx_full  (uart_tx_full  ),
    .uart_tx_empty (uart_tx_empty )
);

// UART TX
uart_tx #(.BUFFER(64)) u_uart_tx (
    .clk      (clk           ),
    .rstz     (rstz          ),
    .tx       (TX            ),
    .prescaler(uart_prescaler),
    .clear    (uart_tx_clear ),
    .full     (uart_tx_full  ),
    .empty    (uart_tx_empty ),
    .size     (uart_tx_size  ),
    .dat_i    (uart_wdat     ),
    .we_i     (uart_we       ),
    .stb_i    (uart_stb      ),
    .ack_o    (uart_tx_ack   )
);

assign uart_rx_ack = 1'b0;
assign uart_rdat = '0;
assign uart_ack = uart_tx_ack | uart_rx_ack;

// Bidirectional GPIO
krz_debounce u_debounce (
    .clk     (clk       ),
    .read    (gpio_read ),
    .gpio_in ({
        14'h0,
        GPIO1,
        GPIO0
    })
);

assign GPIO0 = gpio_dir[0] ? gpio_write[0] : 1'bz;
assign GPIO1 = gpio_dir[1] ? gpio_write[1] : 1'bz;

endmodule