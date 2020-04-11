// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos: Zero Degree
*/

module krz_top (
    input  logic RSTN,
    output logic LEDR,
    output logic LEDG
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

logic [23:0] sys_adr_o;
logic [31:0] sys_dat_i;
logic [31:0] sys_dat_o;
logic sys_we_o;
logic [3:0] sys_sel_o;
logic sys_stb_o;
logic sys_ack_i;

logic gpio_ledr;
logic gpio_ledg;


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
    .sys_adr_o      (sys_adr_o       ),
    .sys_dat_i      (sys_dat_i       ),
    .sys_dat_o      (sys_dat_o       ),
    .sys_we_o       (sys_we_o        ),
    .sys_sel_o      (sys_sel_o       ),
    .sys_stb_o      (sys_stb_o       ),
    .sys_ack_i      (sys_ack_i       )
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
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        sys_ack_i <= 1'b0;
    end
    else begin
        if (sys_stb_o) begin
            if (sys_we_o) begin
                case(sys_adr_o[7:2])
                    6'h00: gpio_ledr <= sys_dat_o[0];
                    6'h01: gpio_ledg <= sys_dat_o[0];
                endcase // sys_adr_o
            end
            else begin
                case(sys_adr_o[7:2])
                    6'h00: sys_dat_i <= {31'b0, gpio_ledr};
                    6'h01: sys_dat_i <= {31'b0, gpio_ledg};
                endcase // sys_adr_o
            end

            sys_ack_i <= 1'b1;
        end
        else sys_ack_i <= 1'b0;
    end
end

// LEDs, inverted
assign LEDR = ~gpio_ledr;
assign LEDG = ~gpio_ledg;

endmodule
