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

logic uns;
logic eq, lt;

assign uns = op[1];
assign eq = rs1 == rs2;
assign lt = uns ? (rs1 < rs2) : ($signed(rs1) < $signed(rs2));

always_comb begin
  unique case (op)
    BEQ: branch = eq;
    BNE: branch = ~eq;
    BGE,
    BGEU: branch = ~lt;
    default: branch = lt; // BLT, BLTU
  endcase // op
end

endmodule
