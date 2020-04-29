// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_branch_ut;

import kronos_types::*;
import rv32_assembler::*;

logic clk;
logic rstz;
logic flush;
pipeIFID_t fetch;
logic [31:0] immediate;
logic [31:0] regrd_rs1;
logic [31:0] regrd_rs2;
logic regrd_rs1_en;
logic regrd_rs2_en;
logic fetch_vld;
logic fetch_rdy;
pipeIDEX_t decode;
logic decode_vld;
logic decode_rdy;
logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

logic instr_vld;
logic [31:0] instr_data;

logic [31:0] branch_target;
logic branch;

kronos_RF u_rf (
  .clk         (clk         ),
  .rstz        (rstz        ),
  .instr_data  (instr_data  ),
  .instr_vld   (instr_vld   ),
  .fetch_rdy   (fetch_rdy   ),
  .immediate   (immediate   ),
  .regrd_rs1   (regrd_rs1   ),
  .regrd_rs2   (regrd_rs2   ),
  .regrd_rs1_en(regrd_rs1_en),
  .regrd_rs2_en(regrd_rs2_en),
  .regwr_data  (regwr_data  ),
  .regwr_sel   (regwr_sel   ),
  .regwr_en    (regwr_en    )
);

kronos_ID u_id (
  .clk         (clk         ),
  .rstz        (rstz        ),
  .flush       (flush       ),
  .fetch       (fetch       ),
  .immediate   (immediate   ),
  .regrd_rs1   (regrd_rs1   ),
  .regrd_rs2   (regrd_rs2   ),
  .regrd_rs1_en(regrd_rs1_en),
  .regrd_rs2_en(regrd_rs2_en),
  .fetch_vld   (fetch_vld   ),
  .fetch_rdy   (fetch_rdy   ),
  .decode      (decode      ),
  .decode_vld  (decode_vld  ),
  .decode_rdy  (decode_rdy  ),
  .regwr_data  (regwr_data  ),
  .regwr_sel   (regwr_sel   ),
  .regwr_en    (regwr_en    )
);

kronos_EX u_ex (
  .clk          (clk          ),
  .rstz         (rstz         ),
  .decode       (decode       ),
  .decode_vld   (decode_vld   ),
  .decode_rdy   (decode_rdy   ),
  .regwr_data   (regwr_data   ),
  .regwr_sel    (regwr_sel    ),
  .regwr_en     (regwr_en     ),
  .branch_target(branch_target),
  .branch       (branch       )
);

default clocking cb @(posedge clk);
  default input #10ps output #10ps;
  input branch_target, branch;
  input regwr_en, regwr_data, regwr_sel, fetch_rdy;
  output fetch_vld, fetch, instr_vld, instr_data;
endclocking

// ============================================================
logic [31:0] REG [32];

struct packed {
  logic [31:0] regwr_data;
  logic [4:0] regwr_sel;
  logic regwr_en;
  logic [31:0] branch_target;
  logic branch;
} expected_wb, got_wb;


`TEST_SUITE begin
  `TEST_SUITE_SETUP begin
    logic [31:0] data;

    clk = 0;
    rstz = 0;

    fetch = '0;
    fetch_vld = 0;
    instr_vld = 0;
    flush = 0;

    // init regfile with random values
    for(int i=0; i<32; i++) begin
      data = $urandom;
      u_rf.REG[i] = data;
      REG[i] = data;
    end

    // Zero out TB's REG[0] (x0)
    REG[0] = 0;

    fork 
      forever #1ns clk = ~clk;
    join_none

    ##4 rstz = 1;
  end

  `TEST_CASE("typical") begin
    pipeIFID_t tinstr;
    string optype;

    repeat (1024) begin

      rand_instr(tinstr, optype);

      $display("OPTYPE=%s", optype);
      $display("IFID: PC=%h, IR=%h", tinstr.pc, tinstr.ir);
      $display("Expected: ");
      $display("  regwr_data: %h", expected_wb.regwr_data);
      $display("  regwr_sel: %h", expected_wb.regwr_sel);
      $display("  regwr_en: %h", expected_wb.regwr_en);
      $display("  branch_target: %h", expected_wb.branch_target);
      $display("  branch: %h", expected_wb.branch);

      @(cb);
      cb.instr_data <= tinstr.ir;
      cb.instr_vld <= 1;
      @(cb);
      cb.fetch <= tinstr;
      cb.fetch_vld <= 1;
      cb.instr_vld <= 0;
      @(cb iff cb.fetch_rdy) begin
        cb.fetch_vld <= 0;
      end

      // Wait until EX stage is done, and collect outputs
      got_wb = '0;
      repeat (8) begin
        @(cb) begin
          if (cb.branch) begin
            got_wb.branch = 1;
            got_wb.branch_target = cb.branch_target;
          end

          if (cb.regwr_en) begin
            got_wb.regwr_en = 1;
            got_wb.regwr_data = cb.regwr_data;
            got_wb.regwr_sel = cb.regwr_sel;
          end
        end
      end

      $display("Got: ");
      $display("  regwr_data: %h", got_wb.regwr_data);
      $display("  regwr_sel: %h", got_wb.regwr_sel);
      $display("  regwr_en: %h", got_wb.regwr_en);
      $display("  branch_target: %h", got_wb.branch_target);
      $display("  branch: %h", got_wb.branch);

      assert(got_wb.branch == expected_wb.branch);
      if (expected_wb.branch) begin
        assert(expected_wb.branch_target == got_wb.branch_target);
      end

      assert(got_wb.regwr_en == expected_wb.regwr_en);
      if (expected_wb.regwr_en) begin
        assert(expected_wb.regwr_data == got_wb.regwr_data);
        assert(expected_wb.regwr_sel == got_wb.regwr_sel);
      end
      

      // Update test's REG as required
      if (got_wb.regwr_en) REG[got_wb.regwr_sel] = got_wb.regwr_data;

      $display("-----------------\n\n");
    end

    ##64;
  end
end
`WATCHDOG(1ms);


// ============================================================
// METHODS
// ============================================================

task automatic rand_instr(output pipeIFID_t instr, output string optype);
  int op;

  logic [6:0] opcode;
  logic [4:0] rs1, rs2, rd;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [31:0] imm;
  int pc, op1, op2;
  logic [31:0] op1_uns, op2_uns;

  // generate scenario
  op = $urandom_range(0,17);

  imm = $urandom() & ~3;
  rs1 = $urandom();
  rs2 = $urandom();
  rd = $urandom_range(1,31);

  instr.pc = $urandom & ~3;
  pc = int'(instr.pc);
  op1_uns = REG[rs1];
  op2_uns = REG[rs2];
  op1 = int'(op1_uns);
  op2 = int'(op2_uns);

  // clear out expected WB
  expected_wb.regwr_data = '0;
  expected_wb.regwr_sel = '0;
  expected_wb.regwr_en = '0;
  expected_wb.branch_target = '0;
  expected_wb.branch = '0;

  $display("op1 = %h", op1);
  $display("op2 = %h", op2);

  case(op)
    0: begin
      optype = "JAL";
      instr.ir = rv32_jal(rd, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + signed'({imm[20:1], 1'b0});
      expected_wb.branch = 1;
    end

    1: begin
      optype = "JALR";
      instr.ir = rv32_jalr(rd, rs1, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = (op1 + signed'(imm[11:0])) & ~1;
      expected_wb.branch = 1;
    end

    2: begin
      optype = "BEQ";
      instr.ir = rv32_beq(rs1, rs2, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 0;
      expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
      expected_wb.branch = op1 == op2;
    end

    3: begin
      optype = "BNE";
      instr.ir = rv32_bne(rs1, rs2, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 0;
      expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
      expected_wb.branch = op1 != op2;
    end

    4: begin
      optype = "BLT";
      instr.ir = rv32_blt(rs1, rs2, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 0;
      expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
      expected_wb.branch = op1 < op2;
    end

    5: begin
      optype = "BGE";
      instr.ir = rv32_bge(rs1, rs2, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 0;
      expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
      expected_wb.branch = op1 >= op2;
    end

    6: begin
      optype = "BLTU";
      instr.ir = rv32_bltu(rs1, rs2, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 0;
      expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
      expected_wb.branch = op1_uns < op2_uns;
    end

    7: begin
      optype = "BGEU";
      instr.ir = rv32_bgeu(rs1, rs2, imm);

      expected_wb.regwr_data = pc + 4;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 0;
      expected_wb.branch_target = pc + signed'({imm[12:1], 1'b0});
      expected_wb.branch = op1_uns >= op2_uns;
    end

    8: begin
      optype = "ADD";
      instr.ir = rv32_add(rd, rs1, rs2);

      expected_wb.regwr_data = op1 + op2;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    9: begin
      optype = "SUB";
      instr.ir = rv32_sub(rd, rs1, rs2);

      expected_wb.regwr_data = op1 - op2;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    10: begin
      optype = "SLL";
      instr.ir = rv32_sll(rd, rs1, rs2);

      expected_wb.regwr_data = op1 << op2[4:0];
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    11: begin
      optype = "SLT";
      instr.ir = rv32_slt(rd, rs1, rs2);

      expected_wb.regwr_data = (op1 < op2) ? 32'b1 : 32'b0;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    12: begin
      optype = "SLTU";
      instr.ir = rv32_sltu(rd, rs1, rs2);

      expected_wb.regwr_data = (op1_uns < op2_uns) ? 32'b1 : 32'b0;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    13: begin
      optype = "XOR";
      instr.ir = rv32_xor(rd, rs1, rs2);

      expected_wb.regwr_data = op1 ^ op2;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    14: begin
      optype = "SRL";
      instr.ir = rv32_srl(rd, rs1, rs2);

      expected_wb.regwr_data = op1 >> op2[4:0];
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    15: begin
      optype = "SRA";
      instr.ir = rv32_sra(rd, rs1, rs2);

      expected_wb.regwr_data = op1 >>> op2[4:0];
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    16: begin
      optype = "OR";
      instr.ir = rv32_or(rd, rs1, rs2);

      expected_wb.regwr_data = op1 | op2;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end

    17: begin
      optype = "AND";
      instr.ir = rv32_and(rd, rs1, rs2);

      expected_wb.regwr_data = op1 & op2;
      expected_wb.regwr_sel = rd;
      expected_wb.regwr_en = 1;
      expected_wb.branch_target = pc + 4;
      expected_wb.branch = 0;
    end
  endcase // instr
endtask

endmodule
