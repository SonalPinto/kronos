// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_kronos_ID_ut;

import kronos_types::*;
import rv32_assembler::*;
import utils::*;

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

logic load;
logic [31:0] instr_data;

kronos_RF u_rf (
  .clk         (clk         ),
  .load        (load        ),
  .instr_data  (instr_data  ),
  .immediate   (immediate   ),
  .regrd_rs1   (regrd_rs1   ),
  .regrd_rs2   (regrd_rs2   ),
  .regrd_rs1_en(regrd_rs1_en),
  .regrd_rs2_en(regrd_rs2_en),
  .regwr_data  (regwr_data  ),
  .regwr_sel   (regwr_sel   ),
  .regwr_en    (regwr_en    )
);

kronos_ID #(
  .CATCH_ILLEGAL_INSTR    (1),
  .USE_REGISTER_FORWARDING(1)
) u_id (
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

default clocking cb @(posedge clk);
  default input #10ps output #10ps;
  input decode_vld, decode;
  input negedge fetch_rdy;
  output fetch_vld, fetch, regwr_en, load, instr_data;
  output negedge decode_rdy;
endclocking

// ============================================================

logic [31:0] REG [32];

`TEST_SUITE begin
  `TEST_SUITE_SETUP begin
    logic [31:0] data;

    clk = 0;
    rstz = 0;

    fetch = '0;
    fetch_vld = 0;
    decode_rdy = 0;
    regwr_data = '0;
    regwr_en = 0;
    regwr_sel = 0;

    load = 0;
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

  `TEST_CASE("decode") begin
    pipeIFID_t tinstr;
    pipeIDEX_t tdecode, rdecode;
    logic write_back;
    string optype;

    repeat (2**10) begin

      rand_instr(tinstr, tdecode, write_back, optype);

      $display("OPTYPE=%s", optype);
      $display("IFID: PC=%h, IR=%h", tinstr.pc, tinstr.ir);
      $display("Expected IDEX:");
      print_decode(tdecode);

      @(cb);
      cb.instr_data <= tinstr.ir;
      cb.load <= 1;
      @(cb);
      cb.fetch <= tinstr;
      cb.fetch_vld <= 1;
      cb.load <= 0;
      @(cb iff cb.fetch_rdy) begin
        cb.fetch_vld <= 0;
      end

      @(cb iff cb.decode_vld);

      //check
      rdecode = decode;

      $display("Got IDEX:");
      print_decode(rdecode);

      cb.decode_rdy <= 1;
      ##1 cb.decode_rdy <= 0;

      assert(rdecode == tdecode);

      // Write back register, else the stage will stall, because of hazard
      if (write_back) begin
        regwr_data = $urandom();
        regwr_sel = rdecode.ir[11:7];
        REG[regwr_sel] = regwr_data;
        @(cb) cb.regwr_en <= 1;
        ##1 cb.regwr_en <= 0;
      end

      $display("-----------------\n\n");
    end

    ##64;
  end

end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_instr(output pipeIFID_t instr, output pipeIDEX_t decode, 
  output logic write_back, output string optype);
  /*
  Generate constrained-random instr

  Note: This would have been a breeze with SV constraints.
    However, the "free" version of modelsim doesn't support
    that feature (along with many other things, like 
    coverage, properties, sequences, etc)
    Hence, we get by with just the humble $urandom

    You can do A LOT of things with just $urandom
  */

  int op;

  logic [6:0] opcode;
  logic [4:0] rs1, rs2, rd;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [31:0] imm;
  logic [11:0] csr;
  logic [4:0] zimm;

  // generate scenario
  op = $urandom_range(0,28);
  imm = $urandom();
  rs1 = $urandom();
  rs2 = $urandom();
  rd = $urandom();
  csr = $urandom();
  zimm = $urandom();

  instr.pc = $urandom;

  // Blank out decode
  decode = '0;
  decode.pc = instr.pc;
  decode.addr = instr.pc + 4;

  // indicate that a register write back is required
  write_back = 0;

  // painstakingly build random-valid instructions
  // and expected decode
  case(op)
    0: begin
      optype = "LUI";
      instr.ir = rv32_lui(rd, imm);
      decode.ir = instr.ir;

      decode.op1 = 0;
      decode.op2 = {imm[31:12], 12'b0};
      decode.aluop = ADD;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    1: begin
      optype = "AUIPC";
      instr.ir = rv32_auipc(rd, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = {imm[31:12], 12'b0};
      decode.aluop = ADD;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    2: begin
      optype = "ADDI";
      instr.ir = rv32_addi(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(imm[11:0]);
      decode.aluop = ADD;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    3: begin
      optype = "SLTI";
      instr.ir = rv32_slti(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(imm[11:0]);
      decode.aluop = SLT;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    4: begin
      optype = "SLTIU";
      instr.ir = rv32_sltiu(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(imm[11:0]);
      decode.aluop = SLTU;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    5: begin
      optype = "XORI";
      instr.ir = rv32_xori(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(imm[11:0]);
      decode.aluop = XOR;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    6: begin
      optype = "ORI";
      instr.ir = rv32_ori(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(imm[11:0]);
      decode.aluop = OR;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    7: begin
      optype = "ANDI";
      instr.ir = rv32_andi(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(imm[11:0]);
      decode.aluop = AND;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    8: begin
      optype = "SLLI";
      instr.ir = rv32_slli(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(instr.ir[31-:12]);
      decode.aluop = SLL;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    9: begin
      optype = "SRLI";
      instr.ir = rv32_srli(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(instr.ir[31-:12]);
      decode.aluop = SRL;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    10: begin
      optype = "SRAI";
      instr.ir = rv32_srai(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = $signed(instr.ir[31-:12]);
      decode.aluop = SRA;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    11: begin
      optype = "ADD";
      instr.ir = rv32_add(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = ADD;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    12: begin
      optype = "SUB";
      instr.ir = rv32_sub(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = SUB;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    13: begin
      optype = "SLL";
      instr.ir = rv32_sll(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = SLL;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    14: begin
      optype = "SLT";
      instr.ir = rv32_slt(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = SLT;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end


    15: begin
      optype = "SLTU";
      instr.ir = rv32_sltu(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = SLTU;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    16: begin
      optype = "XOR";
      instr.ir = rv32_xor(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = XOR;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    17: begin
      optype = "SRL";
      instr.ir = rv32_srl(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = SRL;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    18: begin
      optype = "SRA";
      instr.ir = rv32_sra(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = SRA;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    19: begin
      optype = "OR";
      instr.ir = rv32_or(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = OR;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    20: begin
      optype = "AND";
      instr.ir = rv32_and(rd, rs1, rs2);
      decode.ir = instr.ir;

      decode.op1 = REG[rs1];
      decode.op2 = REG[rs2];
      decode.aluop = AND;
      decode.regwr_alu = rd != 0;

      write_back = rd != 0;
    end

    21: begin
      optype = "JAL";
      instr.ir = rv32_jal(rd, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;
      decode.addr = $signed(instr.pc) + $signed({imm[20:1], 1'b0});

      decode.regwr_alu = rd != 0;
      write_back = rd != 0;

      decode.jump = 1;
    end

    22: begin
      optype = "JALR";
      instr.ir = rv32_jalr(rd, rs1, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;
      decode.addr = ($signed(REG[rs1]) + $signed(imm[11:0])) & ~1;

      decode.regwr_alu = rd != 0;
      write_back = rd != 0;

      decode.jump = 1;
    end

    23: begin
      optype = "BEQ";
      instr.ir = rv32_beq(rs1, rs2, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;

      $display("%b", $signed(imm[11:0]));

      decode.addr = $signed(instr.pc) + $signed({imm[12:1], 1'b0});
      decode.branch = REG[rs1] == REG[rs2];
    end

    24: begin
      optype = "BNE";
      instr.ir = rv32_bne(rs1, rs2, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;

      $display("%b", $signed(imm[11:0]));

      decode.addr = $signed(instr.pc) + $signed({imm[12:1], 1'b0});
      decode.branch = REG[rs1] != REG[rs2];
    end

    25: begin
      optype = "BLT";
      instr.ir = rv32_blt(rs1, rs2, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;

      $display("%b", $signed(imm[11:0]));

      decode.addr = $signed(instr.pc) + $signed({imm[12:1], 1'b0});
      decode.branch = $signed(REG[rs1]) < $signed(REG[rs2]);
    end

    26: begin
      optype = "BGE";
      instr.ir = rv32_bge(rs1, rs2, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;

      $display("%b", $signed(imm[11:0]));

      decode.addr = $signed(instr.pc) + $signed({imm[12:1], 1'b0});
      decode.branch = $signed(REG[rs1]) >= $signed(REG[rs2]);
    end

    27: begin
      optype = "BLTU";
      instr.ir = rv32_bltu(rs1, rs2, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;

      $display("%b", $signed(imm[11:0]));

      decode.addr = $signed(instr.pc) + $signed({imm[12:1], 1'b0});
      decode.branch = REG[rs1] < REG[rs2];
    end

    28: begin
      optype = "BGEU";
      instr.ir = rv32_bgeu(rs1, rs2, imm);
      decode.ir = instr.ir;

      decode.op1 = instr.pc;
      decode.op2 = 4;

      $display("%b", $signed(imm[11:0]));

      decode.addr = $signed(instr.pc) + $signed({imm[12:1], 1'b0});
      decode.branch = REG[rs1] >= REG[rs2];
    end

    // 29: begin
    //     optype = "LB";
    //     instr.ir = rv32_lb(rd, rs1, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);

    //     decode.rd = rd;
    //     decode.ld = 1;

    //     write_back = 1;
    // end

    // 30: begin
    //     optype = "LH";
    //     instr.ir = rv32_lh(rd, rs1, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);

    //     decode.rd = rd;
    //     decode.ld = 1;

    //     write_back = 1;
    // end

    // 31: begin
    //     optype = "LW";
    //     instr.ir = rv32_lw(rd, rs1, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);

    //     decode.rd = rd;
    //     decode.ld = 1;

    //     write_back = 1;
    // end

    // 32: begin
    //     optype = "LBU";
    //     instr.ir = rv32_lbu(rd, rs1, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);

    //     decode.rd = rd;
    //     decode.ld = 1;

    //     write_back = 1;
    // end

    // 33: begin
    //     optype = "LHU";
    //     instr.ir = rv32_lhu(rd, rs1, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);

    //     decode.rd = rd;
    //     decode.ld = 1;

    //     write_back = 1;
    // end

    // 34: begin
    //     optype = "SB";
    //     instr.ir = rv32_sb(rs1, rs2, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);
    //     decode.op3 = 0;
    //     decode.op4 = REG[rs2];

    //     decode.st = 1;
    // end

    // 35: begin
    //     optype = "SH";
    //     instr.ir = rv32_sh(rs1, rs2, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);
    //     decode.op3 = 0;
    //     decode.op4 = REG[rs2];

    //     decode.st = 1;
    // end

    // 36: begin
    //     optype = "SW";
    //     instr.ir = rv32_sw(rs1, rs2, imm);

    //     decode.op1 = REG[rs1];
    //     decode.op2 = $signed(imm[11:0]);
    //     decode.op3 = 0;
    //     decode.op4 = REG[rs2];

    //     decode.st = 1;
    // end

    // 37: begin
    //     optype = "FENCEI";
    //     instr.ir = rv32_fencei();

    //     decode.op3 = instr.pc;
    //     decode.op4 = 4;

    //     decode.branch = 1;
    // end

    // 38: begin
    //     optype = "CSRRW";
    //     instr.ir = rv32_csrrw(rd, rs1, csr);

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = REG[rs1];
    //     decode.op4 = 0;

    //     decode.rd = rd;
    //     decode.csr = 1;

    //     write_back = 1;
    // end

    // 39: begin
    //     optype = "CSRRS";
    //     instr.ir = rv32_csrrs(rd, rs1, csr);

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = REG[rs1];
    //     decode.op4 = 0;

    //     decode.rd = rd;
    //     decode.csr = 1;

    //     write_back = 1;
    // end

    // 40: begin
    //     optype = "CSRRC";
    //     instr.ir = rv32_csrrc(rd, rs1, csr);

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = REG[rs1];
    //     decode.op4 = 0;

    //     decode.rd = rd;
    //     decode.csr = 1;

    //     write_back = 1;
    // end

    // 41: begin
    //     optype = "CSRRWI";
    //     instr.ir = rv32_csrrwi(rd, zimm, csr);

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = zimm;
    //     decode.op4 = 0;

    //     decode.rd = rd;
    //     decode.csr = 1;

    //     write_back = 1;
    // end

    // 42: begin
    //     optype = "CSRRSI";
    //     instr.ir = rv32_csrrsi(rd, zimm, csr);

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = zimm;
    //     decode.op4 = 0;

    //     decode.rd = rd;
    //     decode.csr = 1;

    //     write_back = 1;
    // end

    // 43: begin
    //     optype = "CSRRCI";
    //     instr.ir = rv32_csrrci(rd, zimm, csr);

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = zimm;
    //     decode.op4 = 0;

    //     decode.rd = rd;
    //     decode.csr = 1;

    //     write_back = 1;
    // end

    // 44: begin
    //     optype = "ECALL";
    //     instr.ir = rv32_ecall();

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = 0;
    //     decode.op4 = 0;

    //     decode.ecall = 1;
    // end


    // 45: begin
    //     optype = "EBREAK";
    //     instr.ir = rv32_ebreak();

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = 0;
    //     decode.op4 = 0;

    //     decode.ebreak = 1;
    // end

    // 46: begin
    //     optype = "MRET";
    //     instr.ir = rv32_mret();

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = 0;
    //     decode.op4 = 0;

    //     decode.ret = 1;
    // end

    // 47: begin
    //     optype = "WFI";
    //     instr.ir = rv32_wfi();

    //     decode.op1 = 0;
    //     decode.op2 = instr.ir;
    //     decode.op3 = 0;
    //     decode.op4 = 0;

    //     decode.wfi = 1;
    // end
  endcase // instr
endtask

endmodule
