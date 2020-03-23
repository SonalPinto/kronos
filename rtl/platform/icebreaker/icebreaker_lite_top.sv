// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Simple implementation of the Kronos RV32I core for the iCEBreaker FGPA platform

The board houses a Lattice iCE40UP5K. This implementation straps the Kronos core
onto a 4KB EBR-based memory through a simple arbitrated system bus.

*/

module icebreaker_lite_top (
    input  logic RSTN,
    output logic LEDG
);

logic clk, rstz;

logic [31:0] instr_addr;
logic [31:0] instr_data;
logic instr_req;
logic instr_gnt;
logic [31:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_wr_mask;
logic data_rd_req;
logic data_wr_req;
logic data_gnt;

logic [31:0] mem_addr;
logic [31:0] mem_rd_data;
logic [31:0] mem_wr_data;
logic mem_en;
logic mem_wr_en;
logic [3:0] mem_wr_mask;

logic [31:0] gpio_addr;
logic [31:0] gpio_rd_data;
logic [31:0] gpio_wr_data;
logic gpio_en;
logic gpio_wr_en;

logic [1:0] reset_sync;

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
// Kronos + System
// ============================================================

kronos_core u_core (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .instr_addr  (instr_addr  ),
    .instr_data  (instr_data  ),
    .instr_req   (instr_req   ),
    .instr_gnt   (instr_gnt   ),
    .data_addr   (data_addr   ),
    .data_rd_data(data_rd_data),
    .data_wr_data(data_wr_data),
    .data_wr_mask(data_wr_mask),
    .data_rd_req (data_rd_req ),
    .data_wr_req (data_wr_req ),
    .data_gnt    (data_gnt    )
);

icebreaker_system_bus_lite u_sysbus (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .instr_addr  (instr_addr  ),
    .instr_data  (instr_data  ),
    .instr_req   (instr_req   ),
    .instr_gnt   (instr_gnt   ),
    .data_addr   (data_addr   ),
    .data_rd_data(data_rd_data),
    .data_wr_data(data_wr_data),
    .data_wr_mask(data_wr_mask),
    .data_rd_req (data_rd_req ),
    .data_wr_req (data_wr_req ),
    .data_gnt    (data_gnt    ),
    .mem_addr    (mem_addr    ),
    .mem_rd_data (mem_rd_data ),
    .mem_wr_data (mem_wr_data ),
    .mem_en      (mem_en      ),
    .mem_wr_en   (mem_wr_en   ),
    .mem_wr_mask (mem_wr_mask ),
    .gpio_addr   (gpio_addr   ),
    .gpio_rd_data(gpio_rd_data),
    .gpio_wr_data(gpio_wr_data),
    .gpio_en     (gpio_en     ),
    .gpio_wr_en  (gpio_wr_en  )
);

icebreaker_memory_lite u_mem (
    .clk    (clk        ),
    .addr   (mem_addr   ),
    .wdata  (mem_wr_data),
    .rdata  (mem_rd_data),
    .en     (mem_en     ),
    .wr_en  (mem_wr_en  ),
    .wr_mask(mem_wr_mask)
);


// ============================================================
// GPIO
// ============================================================
always_ff @(posedge clk) begin
    if (gpio_en) begin
        if (gpio_wr_en) begin
            case(gpio_addr[7:2])
                6'h00: gpio_ledg <= gpio_wr_data[0];
            endcase // gpio_addr
        end
        else begin
            case(gpio_addr[7:2])
                6'h00: gpio_rd_data <= {31'b0, gpio_ledg};
            endcase // gpio_addr
        end
    end
end

// inverted
assign LEDG = ~gpio_ledg;

endmodule
