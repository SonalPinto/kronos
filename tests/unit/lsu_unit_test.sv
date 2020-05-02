// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_lsu_ut;

import kronos_types::*;
import rv32_assembler::*;

logic clk;

pipeIDEX_t decode;
logic lsu_vld;
logic lsu_rdy;
logic [31:0] load_data;
logic regwr_lsu;
logic [31:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_mask;
logic data_wr_en;
logic data_req;
logic data_ack;

kronos_lsu u_dut (
  .decode      (decode      ),
  .lsu_vld     (lsu_vld     ),
  .lsu_rdy     (lsu_rdy     ),
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

spsram32_model #(.WORDS(256)) u_dmem (
  .clk  (clk         ),
  .addr (data_addr   ),
  .wdata(data_wr_data),
  .rdata(data_rd_data),
  .en   (data_req    ),
  .wr_en(data_wr_en  ),
  .mask (data_mask   )
);

`define MEM u_dmem.MEM

always_ff @(posedge clk) begin
  if (data_req) begin
    data_ack <= 1;
    // Confirm that access is always 4B aligned
    assert(data_addr[1:0] == 2'b00);
  end
  else data_ack <= 0;
end

default clocking cb @(posedge clk);
  default input #10ps output #10ps;
  output decode, lsu_vld;
  input lsu_rdy, regwr_lsu, load_data;
endclocking

// ============================================================
logic [31:0] expected_load_data, got_load_data;
logic [31:0] store_addr, expected_store_data, got_store_data;

`TEST_SUITE begin
  `TEST_SUITE_SETUP begin
  logic [31:0] data;

  clk = 0;
  lsu_vld = 0;

  for(int i=0; i<256; i++)
    `MEM[i] = $urandom;

  fork 
    forever #1ns clk = ~clk;
  join_none

  ##8;
  end

  `TEST_CASE("load") begin
    pipeIDEX_t tdecode;
    string optype;

    repeat (1024) begin
      rand_load(tdecode, optype);
      $display("OPTYPE=%s", optype);
      $display("Expected: ");
      $display("  load_data: %h", expected_load_data);

      @(cb);
      cb.decode <= tdecode;
      cb.lsu_vld <= 1;

      repeat (8) begin
        @(cb) if (cb.lsu_rdy) begin
          cb.lsu_vld <= 0;
          assert(cb.regwr_lsu);
          got_load_data = cb.load_data;
          $display("Got:");
          $display("  load_data: %h", got_load_data);
        end
      end

      assert(got_load_data == expected_load_data);

      $display("-----------------\n\n");
    end

    ##64;
  end

  `TEST_CASE("store") begin
    pipeIDEX_t tdecode;
    string optype;

    repeat (1024) begin
      rand_store(tdecode, optype);
      $display("OPTYPE=%s", optype);
      $display("Expected: ");
      $display("  store_data: %h", expected_store_data);
      $display("  store_addr: %h", store_addr);

      @(cb);
      cb.decode <= tdecode;
      cb.lsu_vld <= 1;
      @(cb iff cb.lsu_rdy);
      cb.lsu_vld <= 0;
      
      ##2;
      got_store_data = `MEM[store_addr];
      $display("Got:");
      $display("  store_data: %h", got_store_data);

      assert(got_store_data == expected_store_data);

      $display("-----------------\n\n");
    end

    ##64;
  end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_load(output pipeIDEX_t decode, output string optype);
  int op;
  logic [4:0] rd;
  int addr;
  logic [3:0][7:0] mem_word;
  int offset;
  int aligned_addr;
  logic [7:0] dbyte;
  logic [15:0] dhalf;
  logic [31:0] dword;

  // generate scenario
  op = $urandom_range(0,4);
  rd = $urandom_range(1,31);
  addr = $urandom_range(0,252);

  if (op == 2 || op == 3) begin
    addr = addr & ~1; // 2B aligned
  end
  else if (op == 4) begin
    addr = addr & ~3; // 4B aligned
  end

  // Fetch 4B word and next word from the memory
  aligned_addr = addr>>2;
  offset = addr & 3;

  mem_word = `MEM[aligned_addr];
  dbyte = mem_word[offset];
  dhalf = offset[1] ? mem_word[3:2] : mem_word[1:0];
  dword = mem_word;

  $display("addr = %h", addr);
  $display("byte index = %0d", offset);
  $display("mem[%h]: %h", aligned_addr, mem_word);

  // clear out decode
  decode = '0;

  case(op)
    0: begin
      optype = "LB";

      decode.ir = rv32_lb(rd, 0, 0);
      decode.load = 1;
      decode.addr = addr;
      decode.mask = 4'hF;

      expected_load_data = signed'(dbyte);
    end

    1: begin
      optype = "LBU";

      decode.ir = rv32_lbu(rd, 0, 0);
      decode.load = 1;
      decode.addr = addr;
      decode.mask = 4'hF;

      expected_load_data = dbyte;
    end

    2: begin
      optype = "LH";

      decode.ir = rv32_lh(rd, 0, 0);
      decode.load = 1;
      decode.addr = addr;
      decode.mask = 4'hF;

      expected_load_data = signed'(dhalf);
    end

    3: begin
      optype = "LHU";

      decode.ir = rv32_lhu(rd, 0, 0);
      decode.load = 1;
      decode.addr = addr;
      decode.mask = 4'hF;

      expected_load_data = dhalf;
    end

    4: begin
      optype = "LW";

      decode.ir = rv32_lw(rd, 0, 0);
      decode.load = 1;
      decode.addr = addr;
      decode.mask = 4'hF;

      expected_load_data = dword;
    end
  endcase // op
endtask

task automatic rand_store(output pipeIDEX_t decode, output string optype);
  int op;
  logic [4:0] rd;
  int addr;
  logic [3:0][7:0] mem_word;
  int offset;
  int aligned_addr;
  logic [7:0] dbyte;
  logic [15:0] dhalf;
  logic [31:0] dword;


  // generate scenario
  op = $urandom_range(0,2);
  addr = $urandom_range(0,252);
  dbyte = $urandom;
  dhalf = $urandom;
  dword = $urandom;

  if (op == 1) begin
    addr = addr & ~1; // 2B aligned
  end
  else if (op == 2) begin
    addr = addr & ~3; // 4B aligned
  end

  // Fetch 4B word and next word from the memory
  aligned_addr = addr>>2;
  offset = addr & 3;

  mem_word = `MEM[aligned_addr];

  $display("addr = %h", addr);
  $display("byte index = %0d", offset);
  $display("mem[%h]: %h", aligned_addr, mem_word);

  // clear out decode
  decode = '0;

  case(op)
    0: begin
      optype = "SB";

      decode.ir = rv32_sb(rd, 0, 0);
      decode.store = 1;
      decode.addr = addr;
      decode.mask = 4'h1 << offset;
      decode.op2 = dbyte << (8 * offset);

      mem_word[offset] = dbyte;
    end

    1: begin
      optype = "SH";

      decode.ir = rv32_sh(rd, 0, 0);
      decode.store = 1;
      decode.addr = addr;
      decode.mask = 4'h3 << offset;
      decode.op2 = dhalf << (8 * offset);

      {mem_word[offset+1], mem_word[offset]} = dhalf;
    end

    2: begin
      optype = "SW";

      decode.ir = rv32_sw(rd, 0, 0);
      decode.store = 1;
      decode.addr = addr;
      decode.mask = 4'hF;
      decode.op2 = dword;

      mem_word = dword;
    end
  endcase

  // Setup expected stored data at word-aligned address
  store_addr = aligned_addr;
  expected_store_data = mem_word;

endtask

endmodule
