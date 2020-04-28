// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Branch Comparator
*/

/* verilator lint_off DECLFILENAME */

// 8b signed/unsigned comparator
module comp (
  input logic uns,
  input logic [7:0] a,
  input logic [7:0] b,
  output logic [1:0] c
);

always_comb begin
  if (~a[7] & b[7]) c = uns ? 2'b01 : 2'b10;
  else if (a[7] & ~b[7]) c = uns ? 2'b10: 2'b01;
  else if (a[6:0] < b[6:0]) c = 2'b01;
  else if (a[6:0] > b[6:0]) c = 2'b10;
  else c = 2'b00;
end

endmodule

module kronos_branch 
  import kronos_types::*;
(
  input  logic [2:0]  op,
  input  logic [31:0] rs1,
  input  logic [31:0] rs2,
  output logic        branch
);

localparam logic [1:0] EQ = 2'b00;
localparam logic [1:0] LT = 2'b01;
localparam logic [1:0] GT = 2'b10;

logic [3:0][7:0] a, b;
assign a = rs1;
assign b = rs2;

logic [1:0] result;
logic [3:0][1:0] c;

// Parallel comparator - only the highest byte operation is variable
generate
  genvar i;
  comp u_c (
    .uns(op[1]),
    .a(a[3]),
    .b(b[3]),
    .c(c[3])
  );

  for(i=2; i>=0; i--) begin
    comp u_cu (
      .uns(1'b1),
      .a(a[i]),
      .b(b[i]),
      .c(c[i])
    );
  end
endgenerate

always_comb begin
  result = c[3];

  for (int j=2; j>=0; j--) begin
    if (result == EQ) begin
      result = c[j];
    end
  end
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

/* verilator lint_on DECLFILENAME */
