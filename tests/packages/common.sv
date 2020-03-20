// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

// Common test helper functions

package common;

import kronos_types::*;

task automatic print_decode(input pipeIDEX_t d);
    $display("  pc: %h",            d.pc);
    $display("---- OP --------");
    $display("  op1: %h",           d.op1);
    $display("  op2: %h",           d.op2);
    $display("  op3: %h",           d.op3);
    $display("  op4: %h",           d.op4);
    $display("---- EXCTRL ----");
    $display("  cin: %b",           d.cin);
    $display("  rev: %b",           d.rev);
    $display("  uns: %b",           d.uns);
    $display("  eq: %b",            d.eq);
    $display("  inv: %b",           d.inv);
    $display("  align: %b",         d.align);
    $display("  sel: %h",           d.sel);
    $display("---- WBCTRL ----");
    $display("  rd: %d",            d.rd);
    $display("  rd_write: %h",      d.rd_write);
    $display("  branch: %h",        d.branch);
    $display("  branch_cond: %h",   d.branch_cond);
    $display("  ld: %h",            d.ld);
    $display("  st: %h",            d.st);
    $display("  funct3: %h",        d.funct3);    
    $display("---- System ----");
    $display("  csr: %h",           d.csr);
    $display("  ecall: %h",         d.ecall);
    $display("  ret: %h",           d.ret);
    $display("  wfi: %h",           d.wfi);
    $display("---- Exception ----");
    $display("  is_illegal: %h",    d.is_illegal);
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
    $display("  ret: %h",         e.ret);
    $display("  wfi: %h",         e.wfi);
    $display("---- Exception ----");
    $display("  is_illegal: %h",  e.is_illegal);
endtask

endpackage
