// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_kronos_branch_ut;

import kronos_types::*;

logic clk;
logic [2:0] op;
logic [31:0] rs1;
logic [31:0] rs2;
logic branch;

kronos_branch u_dut (
  .op    (op    ),
  .rs1   (rs1   ),
  .rs2   (rs2   ),
  .branch(branch)
);

default clocking cb @(posedge clk);
  default input #10ps output #10ps;
endclocking

// ============================================================
`TEST_SUITE begin
  `TEST_SUITE_SETUP begin
    clk = 0;
    
    rs1 = 0;
    rs2 = 0;
    op = 3'b000;

    fork 
      forever #1ns clk = ~clk;
    join_none

  end

  `TEST_CASE("compare") begin
    logic [31:0] A, B;
    int choice;
    logic result;

    repeat (4096) begin
      A = $urandom();
      B = $urandom();

      if ($urandom_range(0,5) == 0) A = B;

      choice = $urandom_range(0,5);

      case (choice)
        0: begin
          // BEQ
          op = BEQ;
          result = A == B;
        end
        1: begin
          // BNE
          op = BNE;
          result = A != B;
        end
        2: begin
          // BLT
          op = BLT;
          result = $signed(A) < $signed(B);
        end
        3: begin
          // BGE
          op = BGE;
          result = $signed(A) >= $signed(B);
        end
        4: begin
          // BLTU
          op = BLTU;
          result = A < B;
        end
        5: begin
          // BGEU
          op = BGEU;
          result = A >= B;
        end
      endcase // choice

      ##1;
      rs1 = A;
      rs2 = B;

      ##1;

      $display("A = %d, B = %d", $signed(A), $signed(B));
      $display("COMP[%b] = %b vs %b", op, result, branch);
      $display("--------------------\n");

      `CHECK_EQUAL(result, branch);
    end

    ##8;
  end
end

`WATCHDOG(1ms);

endmodule
