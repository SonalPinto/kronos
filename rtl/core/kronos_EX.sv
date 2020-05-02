// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Execution Unit
*/

module kronos_EX
  import kronos_types::*;
(
  input  logic        clk,
  input  logic        rstz,
  // ID/EX
  input  pipeIDEX_t   decode,
  input  logic        decode_vld,
  output logic        decode_rdy,
  // REG Write
  output logic [31:0] regwr_data,
  output logic [4:0]  regwr_sel,
  output logic        regwr_en,
  // Branch
  output logic [31:0] branch_target,
  output logic        branch,
  // Data interface
  output logic [31:0] data_addr,
  input  logic [31:0] data_rd_data,
  output logic [31:0] data_wr_data,
  output logic [3:0]  data_mask,
  output logic        data_wr_en,
  output logic        data_req,
  input  logic        data_ack
);

logic [31:0] result;
logic [4:0] rd;
logic [3:0] funct3;

logic wb_rdy, lsu_rdy;
logic [31:0] load_data;
logic regwr_lsu;

enum logic [2:0] {
  STEADY,
  CSR,
  TRAP,
  RETURN,
  WFI,
  JUMP
} state, next_state;

// ============================================================
// IR Segments
assign OP = decode.ir[6:2];
assign rd  = decode.ir[11:7];
assign funct3 = decode.ir[14:12];

// ============================================================
// EX Sequencer
always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) state <= STEADY;
  else state <= next_state;
end

always_comb begin
  next_state = state;
  /* verilator lint_off CASEINCOMPLETE */
  unique case (state)
    STEADY: if (decode_vld) begin
      if (decode.misaligned) next_state = TRAP;
      else if (decode.system) begin
      end 
    end
  endcase // state
  /* verilator lint_on CASEINCOMPLETE */
end

// Direct write-back is always ready in continued steady state
assign wb_rdy = state == STEADY && decode_vld && ~decode.system;

// Next instructions
assign decode_rdy = wb_rdy || lsu_rdy;

// ============================================================
// ALU
kronos_alu u_alu (
  .op1   (decode.op1  ),
  .op2   (decode.op2  ),
  .aluop (decode.aluop),
  .result(result      )
);

// ============================================================
// LSU
kronos_lsu u_lsu (
  .decode      (decode      ),
  .decode_vld  (decode_vld  ),
  .decode_rdy  (lsu_rdy     ),
  .load_data   (load_data   ),
  .regwr_lsu   (regwr_lsu   ),
  .data_addr   (data_addr   ),
  .data_rd_data(data_rd_data),
  .data_wr_data(data_wr_data),
  .data_mask   (data_mask   ),
  .data_wr_en  (data_wr_en  ),
  .data_req    (data_req    ),
  .data_ack    (data_ack    )
);

// ============================================================
// Register Write Back

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    regwr_en <= 1'b0;
  end
  else begin
    if (wb_rdy && decode.regwr_alu) begin
      // Write back ALU result
      regwr_en <= 1'b1;
      regwr_sel <= rd;
      regwr_data <= result;
    end
    else if (lsu_rdy && regwr_lsu) begin
      // Write back Load Data
      regwr_en <= 1'b1;
      regwr_sel <= rd;
      regwr_data <= load_data;
    end
    else begin
      regwr_en <= 1'b0;
    end
  end
end

// ============================================================
// Jump and Branch
assign branch_target = decode.addr;
assign branch = wb_rdy && decode.branch;

endmodule
