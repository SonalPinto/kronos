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
  output logic        branch
);

logic [31:0] result;
logic [4:0] rd;

logic wb_valid;

enum logic {
  STEADY
} state, next_state;

// ============================================================
// EX Sequencer
always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) state <= STEADY;
  else state <= next_state;
end

always_comb begin
  next_state = state;
end

assign decode_rdy = state == STEADY;

// Direct write-back is always valid in continued steady state
assign wb_valid = decode_vld && decode_rdy;

// IR Segments
assign rd  = decode.ir[11:7];

// ============================================================
// ALU
kronos_alu u_alu (
  .op1   (decode.op1  ),
  .op2   (decode.op2  ),
  .aluop (decode.aluop),
  .result(result      )
);

// ============================================================
// Register Write Back
always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    regwr_en <= 1'b0;
  end
  else begin
    if (wb_valid && decode.regwr_alu) begin
      // Write back ALU result
      regwr_en <= 1'b1;
      regwr_sel <= rd;
      regwr_data <= result;
    end
    else begin
      regwr_en <= 1'b0;
    end
  end
end

// ============================================================
// Jump and Branch
assign branch_target = decode.addr;
assign branch = wb_valid && decode.branch;

endmodule
