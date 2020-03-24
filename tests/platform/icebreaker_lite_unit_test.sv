// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_ice;

import kronos_types::*;
import rv32_assembler::*;

logic clk;
logic RSTN;
logic LEDR;
logic LEDG;

icebreaker_lite_top u_dut (
    .RSTN(RSTN),
    .LEDG(LEDG),
    .LEDR(LEDR)
);

// graybox probes
`define core u_dut.u_core
`define MEM u_dut.u_mem.MEM

assign clk = u_dut.clk;
default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking

// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        RSTN = 1;
    end

    `TEST_CASE("doubler") begin
        int n;
        int r_exp, r_got;

        int addr_n, addr_result, addr_done;

        // setup program: doubler2.c
        // Bootloader -------------------------
        // Load text
        $readmemh("../../../data/doubler2.mem", `MEM);

        // Data addresses
        addr_n = 32'h404 >> 2;
        addr_result = addr_n + 1;

        // Setup operation argument - "n"
        n = $urandom_range(1,31);
        $display("\n\nARG: n = %0d", n);
        `MEM[addr_n] = n;

        reset();

        // Run
        $display("\n\nEXEC\n\n");
        fork
            ##1024; // timeout watchdog
            instruction_monitor();
            program_done_monitor();
        join_any
        $display("\n\n");

        //-------------------------------
        // check
        r_exp = 2**n;
        r_got = `MEM[addr_result];
        $display("RESULT: %d vs %d", r_exp, r_got);
        assert(r_exp == r_got);

        ##64;
    end


    `TEST_CASE("blinky") begin
        // setup program: blinky.c
        // Bootloader -------------------------
        // Load text
        $readmemh("../../../data/blinky.mem", `MEM);

        reset();

        // Run
        $display("\n\nEXEC\n\n");
        fork
            ##10000; // timeout watchdog
            instruction_monitor();
            forever @(LEDG) begin
                if (LEDG) $display("LEDG OFF!");
                else if (~LEDG) $display("LEDG ON!");
            end
        join_any

        ##64;
    end
end

`WATCHDOG(10ms);

// ============================================================
// METHODS
// ============================================================

task automatic reset();
    // Press reset
    ##4 RSTN = 0;
    ##4 RSTN = 1;
    ##4;
endtask

task automatic instruction_monitor();
    instr_t instr;
    int index, addr;

    // instruction monitor
    forever @(cb) begin
        if (`core.instr_req && `core.instr_gnt) begin
            addr = `core.instr_addr;
            instr = `MEM[addr>>2];
            $display("[%0d] ADDR=%0d, INSTR=%h", index, addr, instr);
            index++;
        end
    end
endtask

task automatic program_done_monitor();
    logic [31:0] addr_done;

    addr_done = 32'h400>>2;

    // instruction monitor
    forever @(cb) begin
        if (`MEM[addr_done]) begin
            $display("DONE!");
            break;
        end
    end
endtask

endmodule
