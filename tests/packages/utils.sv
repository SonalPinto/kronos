// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

// Test helper functions

package utils;

import kronos_types::*;

task automatic print_decode(input pipeIDEX_t d);
    $display("  pc: %h",            d.pc);
    $display("  ir: %h",            d.ir);
    $display("---- OP --------");
    $display("  op1: %h",           d.op1);
    $display("  op2: %h",           d.op2);
    $display("---- EXCTRL ----");
    $display("  aluop: %b",         d.aluop);
    $display("  regwr_alu: %b",     d.regwr_alu);
endtask

task automatic print_execute(input pipeEXWB_t e);
    $display("  pc: %h",          e.pc);
    $display("---- RES -------");
    $display("  result1: %h",     e.result1);
    $display("  result2: %h",     e.result2);
    $display("---- WBCTRL ----");
    $display("  rd: %d",          e.rd);
    $display("  rd_write: %h",    e.rd_write);
    $display("  branch: %h",      e.branch);
    $display("  ld: %h",          e.ld);
    $display("  st: %h",          e.st);
    $display("  branch_cond: %h", e.branch_cond);
    $display("  funct3: %h",      e.funct3);    
    $display("---- System ----");
    $display("  csr: %h",         e.csr);
    $display("  ecall: %h",       e.ecall);
    $display("  ebreak: %h",      e.ebreak);
    $display("  ret: %h",         e.ret);
    $display("  wfi: %h",         e.wfi);
    $display("---- Exception ----");
    $display("  is_illegal: %h",  e.is_illegal);
endtask

endpackage
