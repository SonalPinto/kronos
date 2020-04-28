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
    $display("  addr: %h",          d.addr);
    $display("---- EXCTRL ----");
    $display("  aluop: %b",         d.aluop);
    $display("  regwr_alu: %b",     d.regwr_alu);
    $display("  jump: %b",          d.jump);
    $display("  branch: %b",        d.branch);
endtask

endpackage
