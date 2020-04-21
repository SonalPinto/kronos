// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ns
`include "vunit_defines.svh"

module tb_comp;

logic clk;

logic [3:0][7:0] a, b;
logic [3:0][1:0] c1, c2;
logic [1:0] fc1, fc2;

generate
  genvar i;
  comp1 u_dut1 (
    .a(a[3]),
    .b(b[3]),
    .c(c1[3])
  );

  comp2 u_dut2 (
    .a(a[3]),
    .b(b[3]),
    .c(c2[3])
  );

  for(i=2; i>=0; i--) begin
    comp1u u_dut1u (
      .a(a[i]),
      .b(b[i]),
      .c(c1[i])
    );

    comp2u u_dut2u (
      .a(a[i]),
      .b(b[i]),
      .c(c2[i])
    );
  end
endgenerate

always_comb begin
  fc1 = c1[3];

  for (int i=2; i>=0; i--) begin
    if (fc1 == 2'b00) begin
      fc1 = c1[i];
    end
  end
end

always_comb begin
  fc2 = c2[3];

  for (int i=2; i>=0; i--) begin
    if (fc2 == 2'b00) begin
      fc2 = c2[i];
    end
  end
end


default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking

// ============================================================
`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        
        a = 0;
        b = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

    end

    `TEST_CASE("compare") begin
        logic signed [31:0] A, B;
        logic [1:0] C;

        repeat (1024) begin
          A = $urandom();
          B = $urandom();

          if ($urandom_range(0,9) == 0) A = B;

          if (A < B) C = 2'b01;
          else if (A > B) C = 2'b10;
          else C = 2'b00;

          ##1;
          a = A;
          b = B;

          ##1;

          $display("A = %d, %d, %d, %d", a[3], a[2], a[1], a[0]);
          $display("B = %d, %d, %d, %d", b[3], b[2], b[1], b[0]);
          $display("");

          $display("c1 = %b, %b, %b, %b", c1[3], c1[2], c1[1], c1[0]);
          $display("c2 = %b, %b, %b, %b", c2[3], c2[2], c2[1], c2[0]);
          $display("");

          $display("A = %d, B = %d, C = %b vs %b | %b", $signed(a), $signed(b), C, fc1, fc2);
          $display("--------------------\n");

          assert(C == fc1 && C == fc2);
          assert(c1 == c2);
        end

        ##8;
    end
end

`WATCHDOG(1ms);


endmodule
