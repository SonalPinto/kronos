// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_krz;

logic RSTN;
wire  LEDR;
wire  LEDG;
logic TX;

krz_top u_dut (
    .RSTN(RSTN),
    .TX(TX),
    .GPIO0(LEDR),
    .GPIO1(LEDG)
);

// graybox probes
`define core u_dut.u_core
`define MEM u_dut.u_bootrom.MEM

assign clk = u_dut.clk;
default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking

`define MEM00 u_dut.u_mem0.MEMINST[0].u_spsram.vfb_b_inst.SRAM_inst.spram256k_core_inst.uut.mem_core_array
`define MEM01 u_dut.u_mem0.MEMINST[1].u_spsram.vfb_b_inst.SRAM_inst.spram256k_core_inst.uut.mem_core_array

// ============================================================
logic [31:0] PROG [1024*128];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        RSTN = 1;
    end

    `TEST_CASE("blinky") begin
        logic [31:0] instr;

        ##8;

        // setup simple bootloader
        $readmemh("../../../data/krz_test_boot.mem", u_dut.u_bootrom.MEM);

        reset();

        // setup program: krz_blinky.c
        PROG = '{default: '0};
        $readmemh("../../../data/dhrystone_main.mem", PROG);

        foreach (PROG[i]) begin
            // $display("%h",PROG[i]);
            {`MEM01[i], `MEM00[i]} = PROG[i];
        end

        // Run
        $display("\n\nEXEC\n\n");
        fork
            ##40000; // timeout watchdog
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

endmodule