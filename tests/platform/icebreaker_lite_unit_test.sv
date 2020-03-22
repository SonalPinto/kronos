// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_ice;

import kronos_types::*;
import rv32_assembler::*;

logic clk;
logic rstz;
logic LED;

icebreaker_lite_top u_dut (
    .clk (clk ),
    .rstz(rstz),
    .LED (LED )
);

// graybox probes
`define core u_dut.u_core
`define MEM u_dut.u_mem.MEM

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking

// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none
    end

    `TEST_CASE("doubler") begin
        instr_t instr;
        int index, addr;
        int data;
        int n;
        int r_exp, r_got;

        // setup program: doubler.c
        /*
            void main(int n) {
                int a, b;
                a = 1;
                for(b=0; b<n; b++){
                    a = 2 * a;
                }
                result = a;
            }
        */
        // Bootloader -------------------------
        // Load text
        $readmemh("../../../data/doubler.mem", `MEM);

        // ABI --------------------------------
        // Setup Return Address (ra/x1)
        `core.u_id.REG1[x1] = 944;
        `core.u_id.REG2[x1] = 944;

        // Store while(1); at 944
        // 944 = 0x3B0, word 236
        `MEM[944>>2] = rv32_jal(x0, 0); // j 1b

        // Setup Frame Pointer (s0/x8)
        `core.u_id.REG1[x8] = 0;
        `core.u_id.REG2[x8] = 0;

        // Setup Stack Pointer (sp/x2) to the end of the memory (4KB), 0x1000
        `core.u_id.REG1[x2] = 4096;
        `core.u_id.REG2[x2] = 4096;

        // Setup Function Argument - "n" - at a0 (x10)
        n = $urandom_range(1,31);
        $display("\n\nARG: n = %0d", n);
        `core.u_id.REG1[x10] = n;
        `core.u_id.REG2[x10] = n;

        // De-assert reset
        ##4 rstz = 1;

        // Run
        $display("\n\nEXEC\n\n");
        fork 
            forever @(cb) begin
                if (`core.instr_req && `core.instr_gnt) begin
                    addr = `core.instr_addr;
                    instr = `MEM[addr>>2];
                    $display("[%0d] ADDR=%0d, INSTR=%h", index, addr, instr);
                    index++;
                    if (addr == 944) begin
                        break;
                    end
                end
            end

            ##1024;
        join_any
        $display("\n\n");

        //-------------------------------
        // check
        r_exp = 2**n;
        r_got = `MEM[960>>2];
        $display("RESULT: %d vs %d", r_exp, r_got);
        assert(r_exp == r_got);

        ##64;
    end
end

`WATCHDOG(1ms);

endmodule
