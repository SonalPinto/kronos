// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Branch Comparator
*/

module kronos_branch 
  import kronos_types::*;
(
  input  logic [2:0]  op,
  input  logic [31:0] rs1,
  input  logic [31:0] rs2,
  output logic        branch
);
logic [1:0] result;
logic uns;

assign uns = op[1];

always_comb begin
  if (rs1 == rs2) result = 2'b00;
  else if (uns && rs1 < rs2) result = 2'b01;
  else if (~uns && $signed(rs1) < $signed(rs2)) result = 2'b01;
  else result = 2'b10;
end

// ============================================================
// Decode result
always_comb begin
  unique case (op)
    BEQ: branch = result == EQ;
    BNE: branch = result != EQ;
    BGE,
    BGEU: branch = result != LT;
    default: branch = result == LT; // BLT, BLTU
  endcase // op
end

endmodule
