// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_krz;

logic RSTN;
logic LEDR;
logic LEDG;

krz_top u_dut (
    .RSTN(RSTN),
    .LEDR(LEDR),
    .LEDG(LEDG)
);

// graybox probes
`define core u_dut.u_core
`define MEM u_dut.u_bootrom.MEM

assign clk = u_dut.clk;
default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking


// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        RSTN = 1;
    end

    `TEST_CASE("blinky") begin
        // setup program: blinky.c
        // Bootloader -------------------------
        // Load text
        $readmemh("../../../data/krz_blinky.mem", `MEM);

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
    logic [31:0] instr;
    int index, addr;

    // instruction monitor
    forever @(cb) begin
        if (`core.instr_req && `core.instr_ack) begin
            addr = `core.instr_addr;
            instr = `MEM[addr>>2];
            $display("[%0d] ADDR=%0d, INSTR=%h", index, addr, instr);
            index++;
        end
    end
endtask

endmodule