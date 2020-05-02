// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_csr_ut;

import kronos_types::*;
import rv32_assembler::*;
import utils::*;

logic clk;
logic rstz;
pipeIDEX_t decode;
logic decode_vld;
logic decode_rdy;
logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;
logic [31:0] branch_target;
logic branch;
logic [31:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_mask;
logic data_wr_en;
logic data_req;
logic data_ack;
logic software_interrupt;
logic timer_interrupt;
logic external_interrupt;

kronos_EX u_ex (
  .clk               (clk               ),
  .rstz              (rstz              ),
  .decode            (decode            ),
  .decode_vld        (decode_vld        ),
  .decode_rdy        (decode_rdy        ),
  .regwr_data        (regwr_data        ),
  .regwr_sel         (regwr_sel         ),
  .regwr_en          (regwr_en          ),
  .branch_target     (branch_target     ),
  .branch            (branch            ),
  .data_addr         (data_addr         ),
  .data_rd_data      (data_rd_data      ),
  .data_wr_data      (data_wr_data      ),
  .data_mask         (data_mask         ),
  .data_wr_en        (data_wr_en        ),
  .data_req          (data_req          ),
  .data_ack          (data_ack          ),
  .software_interrupt(1'b0              ),
  .timer_interrupt   (1'b0              ),
  .external_interrupt(1'b0              )
);

// gray box probes
`define csr u_ex.u_csr

logic csr_rd_en, csr_wr_en;
logic [11:0] csr_addr;
logic [1:0] csr_op;
logic [31:0] csr_rd_data, csr_wr_data, csr_wb_data;

assign csr_rd_en = `csr.csr_rd_en;
assign csr_wr_en = `csr.csr_wr_en;
assign csr_addr = `csr.addr;
assign csr_op = `csr.funct3[1:0];
assign csr_rd_data = `csr.csr_data;
assign csr_wr_data = `csr.csr_wr_data;

default clocking cb @(posedge clk);
  default input #10ps output #10ps;
  input negedge decode_rdy;
  input regwr_en, regwr_data, regwr_sel;
  input csr_rd_en, csr_wr_en;
  input branch, branch_target;
  output decode_vld, decode;
endclocking

// ============================================================

`TEST_SUITE begin
  `TEST_SUITE_SETUP begin
  clk = 0;
  rstz = 0;

  decode = '0;
  decode_vld = 0;
  data_ack = 0;
  data_rd_data = 0;

  // rand init CSR
  `csr.mscratch = $urandom();
  `csr.mepc = $urandom();
  `csr.mcause = $urandom();
  `csr.mtval = $urandom();

  fork 
  forever #1ns clk = ~clk;
  join_none

  ##4 rstz = 1;
  end

  `TEST_CASE("rw") begin
  string optype, csr_name;
  logic [11:0] csr;
  pipeIDEX_t tdecode;
  logic [31:0] exp_rd, exp_wr;
  logic [4:0] rd, rs1;

  repeat (128) begin
  // Select random CSR
  select_csr(csr, csr_name);
  $display("CSR: %s", csr_name);

  // Setup some rw instruction for it
  rand_csr(csr, tdecode, optype);
  $display("OPTYPE: %s", optype);
  $display("");
  print_decode(tdecode);
  rd = tdecode.ir[11:7];
  rs1 = tdecode.ir[19:15];

  // Setup expected results
  setup_expected(tdecode, exp_rd, exp_wr);
  $display("");
  $display("EXP rd_data = %h", exp_rd);
  $display("EXP wr_data = %h", exp_wr);

  @(cb);
  cb.decode <= tdecode;
  cb.decode_vld <= 1;

  @(cb iff cb.decode_rdy) cb.decode_vld <= 0;

  @(cb) if (rd != 0) begin
  assert(cb.regwr_en);
  $display("GOT Register WB: %h", cb.regwr_data);
  assert(cb.regwr_data == exp_rd);
  assert(cb.regwr_sel == rd);
  end
  else assert(!cb.regwr_en);

  // check CSR
  check_csr(csr, exp_wr);

  $display("-----------------\n\n");
  end

  check_minstret(128);

  ##64;
  end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic select_csr(output logic [11:0] csr, output string csr_name);
  int pick;
  pick = $urandom_range(0,7);

  case(pick)
  0: begin 
  csr = MSTATUS;
  csr_name = "mstatus";
  end
  1: begin 
  csr = MIE;
  csr_name = "mie";
  end
  2: begin 
  csr = MTVEC;
  csr_name = "mtvec";
  end
  3: begin 
  csr = MSCRATCH;
  csr_name = "mscratch";
  end
  4: begin 
  csr = MEPC;
  csr_name = "mepc";
  end
  5: begin 
  csr = MCAUSE;
  csr_name = "mcause";
  end
  6: begin 
  csr = MTVAL;
  csr_name = "mtval";
  end
  7: begin 
  csr = MIP;
  csr_name = "mip";
  end
  endcase
endtask

task automatic rand_csr(logic [11:0] csr, output pipeIDEX_t decode, output string optype);
  logic [4:0] rs1, rd;
  logic [4:0] zimm;

  rs1 = $urandom();
  rd = $urandom();
  zimm = $urandom();

  // generate random CSR operation
  decode = '0;
  decode.csr = 1;

  // coin toss for imm or reg source
  case($urandom_range(0,5))
  0: begin
  optype = "CSRRW";
  decode.ir = rv32_csrrw(rd, rs1, csr);
  end
  1: begin
  optype = "CSRRS";
  decode.ir = rv32_csrrs(rd, rs1, csr);
  end
  2: begin
  optype = "CSRRC";
  decode.ir = rv32_csrrc(rd, rs1, csr);
  end
  3: begin
  optype = "CSRRWI";
  decode.ir = rv32_csrrwi(rd, zimm, csr);
  end
  4: begin
  optype = "CSRRSI";
  decode.ir = rv32_csrrsi(rd, zimm, csr);
  end
  5: begin
  optype = "CSRRCI";
  decode.ir = rv32_csrrci(rd, zimm, csr);
  end
  endcase

  decode.op1 = rs1 == 0 ? '0 : $urandom;
endtask

task automatic setup_expected(input pipeIDEX_t decode, 
  output logic [31:0] rd_data, wr_data);

  logic [11:0] csr;
  logic [31:0] twdata;
  logic [31:0] write_data;

  rd_data = '0; // default
  wr_data = '0;

  // Read current value
  csr = decode.ir[31:20];
  case(csr)
  MSTATUS: begin
    rd_data[3] = `csr.mstatus.mie;
    rd_data[7] = `csr.mstatus.mpie;
    rd_data[12:11] = 2'b11;
  end
  MIE : begin
    rd_data[3] = `csr.mie.msie;
    rd_data[7] = `csr.mie.mtie;
    rd_data[11] = `csr.mie.meie;
  end
  MTVEC : rd_data = `csr.mtvec;
  MSCRATCH : rd_data = `csr.mscratch;
  MEPC : rd_data = `csr.mepc;
  MCAUSE : rd_data = `csr.mcause;
  MTVAL : rd_data = `csr.mtval;
  MIP : begin
    rd_data[3] = `csr.mip.msip;
    rd_data[7] = `csr.mip.mtip;
    rd_data[11] = `csr.mip.meip;
  end
  endcase // csr

  if (decode.ir[14]) write_data = decode.ir[19:15]; 
  else write_data = decode.op1;

  // Setup write value as per op
  case(decode.ir[13:12])
  CSR_RW: twdata = write_data;
  CSR_RS: twdata = rd_data | write_data;
  CSR_RC: twdata = rd_data & ~write_data;
  endcase

  case(csr)
  MSTATUS: begin
    wr_data[3] = twdata[3];
    wr_data[7] = twdata[7];
    wr_data[12:11] = 2'b11;
  end
  MIE : begin
    wr_data[3] = twdata[3];
    wr_data[7] = twdata[7];
    wr_data[11] = twdata[11];
  end
  MTVEC : wr_data = {twdata[31:2], 2'b00};
  MSCRATCH : wr_data = twdata;
  MEPC : wr_data = {twdata[31:2], 2'b00};
  MCAUSE : wr_data = twdata;
  MTVAL : wr_data = twdata;
  endcase // csr
endtask

task automatic check_csr(input logic [11:0] csr, input logic [31:0] check);
  case(csr)
    MSTATUS: begin
      $display("mstatus.mie=%b", `csr.mstatus.mie);
      $display("mstatus.mpie=%b", `csr.mstatus.mpie);
      $display("mstatus.mpp=%b", `csr.mstatus.mpp);

      assert(`csr.mstatus.mie == check[3]);
      assert(`csr.mstatus.mpie == check[7]);
      assert(`csr.mstatus.mpp == check[12:11]);
    end
    MIE : begin
      $display("mie.msie=%b", `csr.mie.msie);
      $display("mie.mtie=%b", `csr.mie.mtie);
      $display("mie.meie=%b", `csr.mie.meie);

      assert(`csr.mie.msie == check[3]);
      assert(`csr.mie.mtie == check[7]);
      assert(`csr.mie.meie == check[11]);
    end
    MTVEC : begin
      $display("mtvec=%h", `csr.mtvec);
      assert(`csr.mtvec == check);
    end
    MSCRATCH : begin
      $display("mscratch=%h", `csr.mscratch);
      assert(`csr.mscratch == check);
    end
    MEPC : begin
      $display("mepc=%h", `csr.mepc);
      assert(`csr.mepc == check);
    end
    MCAUSE : begin
      $display("mcause=%h", `csr.mcause);
      assert(`csr.mcause == check);
    end
    MTVAL : begin 
      $display("mtval=%h", `csr.mtval);
      assert(`csr.mtval == check);
    end
    MIP : begin
      $display("mip.msip=%b", `csr.mip.msip);
      $display("mip.mtip=%b", `csr.mip.mtip);
      $display("mip.meip=%b", `csr.mip.meip);

      assert(`csr.mip.msip == check[3]);
      assert(`csr.mip.mtip == check[7]);
      assert(`csr.mip.meip == check[11]);
    end
  endcase // csr
endtask

task automatic check_minstret(input logic [31:0] count);
    // check minstret
    decode = '0;
    decode.csr = 1;
    decode.ir = rv32_csrrs(1, 0, MINSTRET);

    @(cb) cb.decode_vld <= 1;
    @(cb iff cb.decode_rdy) cb.decode_vld <= 0;

    @(cb iff cb.regwr_en);
    $display("minstret: %d", cb.regwr_data);
    assert(cb.regwr_data == count);
    assert(cb.regwr_sel == 1);
endtask

endmodule
