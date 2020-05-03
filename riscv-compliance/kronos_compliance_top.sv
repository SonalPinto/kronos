// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

module kronos_compliance_top (
  input  logic        clk,
  input  logic        rstz,
  // IO probes
  output logic [31:0] instr_addr,
  output logic [31:0] instr_data,
  output logic        instr_req,
  output logic        instr_ack,
  output logic [31:0] data_addr,
  output logic [31:0] data_rd_data,
  output logic [31:0] data_wr_data,
  output logic [3:0]  data_mask,
  output logic        data_wr_en,
  output logic        data_req,
  output logic        data_ack
);

logic [31:0] mem_addr;
logic [31:0] mem_wr_data;
logic [31:0] mem_rd_data;
logic mem_en, mem_wr_en;
logic [3:0] mem_mask;

kronos_core u_dut (
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

// Arbitrate memory access
// Data has Priority
always_comb begin
  mem_en      = instr_req || data_req;
  mem_wr_en   = data_req && data_wr_en;

  mem_addr    = data_req ? data_addr : instr_addr;

  mem_wr_data = data_wr_data;

  // mask is only used for write
  mem_mask    = data_mask;

  instr_data = mem_rd_data;
  data_rd_data = mem_rd_data;
end

always_ff @(posedge clk) begin
  instr_ack <= instr_req & ~data_req;
  data_ack <= data_req;
end

generic_spram #(.KB(8)) u_mem (
  .clk  (clk        ),
  .addr (mem_addr   ),
  .wdata(mem_wr_data),
  .rdata(mem_rd_data),
  .en   (mem_en     ),
  .wr_en(mem_wr_en  ),
  .mask (mem_mask   )
);

endmodule
