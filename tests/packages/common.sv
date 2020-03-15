// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

// Common test helper functions

package common;

import kronos_types::*;

task automatic print_decode(input pipeIDEX_t d);
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
    $display("  data_size: %h",     d.data_size);    
    $display("  data_uns: %h",      d.data_uns);
    $display("  csr_rd: %h",        d.csr_rd);
    $display("  csr_wr: %h",        d.csr_wr);
    $display("  csr_set: %h",       d.csr_set);
    $display("  csr_clr: %h",       d.csr_clr);
    $display("---- Exception ----");
    $display("  is_illegal: %h",    d.is_illegal);
    $display("  is_ecall: %h",      d.is_ecall);
endtask

task automatic print_execute(input pipeEXWB_t e);
    $display("---- RES -------");
    $display("  result1: %h", e.result1);
    $display("  result2: %h", e.result2);
    $display("---- WBCTRL ----");
    $display("  rd: %d",          e.rd);
    $display("  rd_write: %h",    e.rd_write);
    $display("  branch: %h",      e.branch);
    $display("  ld: %h",          e.ld);
    $display("  st: %h",          e.st);
    $display("  branch_cond: %h", e.branch_cond);
    $display("  data_size: %h",   e.data_size);    
    $display("  data_uns: %h",    e.data_uns);
    $display("  csr_rd: %h",      e.csr_rd);
    $display("  csr_wr: %h",      e.csr_wr);
    $display("  csr_set: %h",     e.csr_set);
    $display("  csr_clr: %h",     e.csr_clr);
    $display("---- Exception ----");
    $display("  is_illegal: %h",  e.is_illegal);
    $display("  is_ecall: %h",    e.is_ecall);
endtask

endpackage
