// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Simple implementation of the Kronos RV32I core for the iCEBreaker FGPA platform

The board houses a Lattice iCE40UP5K. This implementation straps the Kronos core
onto a 4KB EBR-based memory through a simple arbitrated system bus.

IO:
  - LEDG, LEDR - active low
  - 7 Segment Display pmod driver (2 character)

*/

module snowflake_top (
  input  logic RSTN,
  output logic LEDR,
  output logic LEDG,
  output logic CAT,
  output logic AA,
  output logic AB,
  output logic AC,
  output logic AD,
  output logic AE,
  output logic AF,
  output logic AG
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

logic [31:0] mem_addr;
logic [31:0] mem_rd_data;
logic [31:0] mem_wr_data;
logic mem_en;
logic mem_wr_en;
logic [3:0] mem_mask;

logic [31:0] sys_addr;
logic [31:0] sys_rd_data;
logic [31:0] sys_wr_data;
logic sys_en;
logic sys_wr_en;

logic gpio_ledr;
logic gpio_ledg;

logic ssd_en, ssd_sel;
logic [6:0] ssd_a, ssd_b, ssd_disp;

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
// Kronos + System
// ============================================================

kronos_core #(
  .FAST_BRANCH(1),
  .EN_COUNTERS(1),
  .EN_COUNTERS64B(0),
  .CATCH_ILLEGAL_INSTR(0),
  .CATCH_MISALIGNED_JMP(0),
  .CATCH_MISALIGNED_LDST(0)
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

snowflake_system_bus u_sysbus (
  .clk         (clk         ),
  .rstz        (rstz        ),
  .instr_addr  (instr_addr  ),
  .instr_data  (instr_data  ),
  .instr_req   (instr_req   ),
  .instr_ack   (instr_ack   ),
  .data_addr   (data_addr   ),
  .data_rd_data(data_rd_data),
  .data_wr_data(data_wr_data),
  .data_mask   (data_mask   ),
  .data_wr_en  (data_wr_en  ),
  .data_req    (data_req    ),
  .data_ack    (data_ack    ),
  .mem_addr    (mem_addr    ),
  .mem_rd_data (mem_rd_data ),
  .mem_wr_data (mem_wr_data ),
  .mem_en      (mem_en      ),
  .mem_wr_en   (mem_wr_en   ),
  .mem_mask    (mem_mask    ),
  .sys_addr    (sys_addr    ),
  .sys_rd_data (sys_rd_data ),
  .sys_wr_data (sys_wr_data ),
  .sys_en      (sys_en      ),
  .sys_wr_en   (sys_wr_en   )
);

generic_spram #(.KB(4)) u_mem (
  .clk  (clk        ),
  .addr (mem_addr   ),
  .wdata(mem_wr_data),
  .rdata(mem_rd_data),
  .en   (mem_en     ),
  .wr_en(mem_wr_en  ),
  .mask (mem_mask   )
);


// ============================================================
// System
// ============================================================
always_ff @(posedge clk) begin
  if (sys_en) begin
    if (sys_wr_en) begin
      case(sys_addr[7:2])
        6'h00: gpio_ledr <= sys_wr_data[0];
        6'h01: gpio_ledg <= sys_wr_data[0];
        6'h02: ssd_en    <= sys_wr_data[0];
        6'h03: ssd_a     <= sys_wr_data[6:0];
        6'h04: ssd_b     <= sys_wr_data[6:0];
      endcase // sys_addr
    end
    else begin
      case(sys_addr[7:2])
        6'h00: sys_rd_data <= {31'b0, gpio_ledr};
        6'h01: sys_rd_data <= {31'b0, gpio_ledg};
        6'h02: sys_rd_data <= {31'b0, ssd_en};
        6'h03: sys_rd_data <= {25'b0, ssd_a};
        6'h04: sys_rd_data <= {25'b0, ssd_b};
      endcase // sys_addr
    end
  end
end

// LEDs, inverted
assign LEDR = ~gpio_ledr;
assign LEDG = ~gpio_ledg;

// 7-Segment Display PMOD driver
snowflake_7sd_driver u_7sd (
  .clk (clk      ),
  .rstz(rstz     ),
  .en  (ssd_en  ),
  .a   (ssd_a   ),
  .b   (ssd_b   ),
  .disp(ssd_disp),
  .sel (ssd_sel )
);

assign CAT = ssd_sel;
assign {AG, AF, AE, AD, AC, AB, AA} = ssd_disp;

endmodule
