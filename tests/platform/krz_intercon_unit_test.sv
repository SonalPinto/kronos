// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_krz_intercon_ut;

logic clk;
logic rstz;
logic [23:0] instr_addr;
logic [31:0] instr_data;
logic instr_req;
logic instr_ack;
logic [23:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_wr_mask;
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
logic [3:0] mem0_wr_mask;
logic [23:0] mem1_addr;
logic [31:0] mem1_rd_data;
logic [31:0] mem1_wr_data;
logic mem1_en;
logic mem1_wr_en;
logic [3:0] mem1_wr_mask;

krz_intercon u_dut (
    .clk            (clk            ),
    .rstz           (rstz           ),
    .instr_addr     (instr_addr     ),
    .instr_data     (instr_data     ),
    .instr_req      (instr_req      ),
    .instr_ack      (instr_ack      ),
    .data_addr      (data_addr      ),
    .data_rd_data   (data_rd_data   ),
    .data_wr_data   (data_wr_data   ),
    .data_wr_mask   (data_wr_mask   ),
    .data_wr_en     (data_wr_en     ),
    .data_req       (data_req       ),
    .data_ack       (data_ack       ),
    .bootrom_addr   (bootrom_addr   ),
    .bootrom_rd_data(bootrom_rd_data),
    .bootrom_en     (bootrom_en     ),
    .mem0_addr      (mem0_addr      ),
    .mem0_rd_data   (mem0_rd_data   ),
    .mem0_wr_data   (mem0_wr_data   ),
    .mem0_en        (mem0_en        ),
    .mem0_wr_en     (mem0_wr_en     ),
    .mem0_wr_mask   (mem0_wr_mask   ),
    .mem1_addr      (mem1_addr      ),
    .mem1_rd_data   (mem1_rd_data   ),
    .mem1_wr_data   (mem1_wr_data   ),
    .mem1_en        (mem1_en        ),
    .mem1_wr_en     (mem1_wr_en     ),
    .mem1_wr_mask   (mem1_wr_mask   )
);

spsram32_model #(.DEPTH(256)) u_imem (
    .clk    (~clk       ),
    .addr   (instr_addr),
    .wdata  (32'b0     ),
    .rdata  (instr_data),
    .en     (instr_req ),
    .wr_en  (1'b0      ),
    .wr_mask(4'b0      )
);

endmodule
