// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_krz;

logic RSTN;
wire  TX;
wire  SCLK;
wire  MOSI;
wire  MISO;
wire  LEDR;
wire  LEDG;
wire  FLASH_CS;
wire  GPIO3;

krz_top u_dut (
    .RSTN (RSTN    ),
    .TX   (TX      ),
    .SCLK (SCLK    ),
    .MOSI (MOSI    ),
    .MISO (MISO    ),
    .GPIO0(LEDR    ),
    .GPIO1(LEDG    ),
    .GPIO2(FLASH_CS),
    .GPIO3(GPIO3   )
);

spiflash u_flash (
    .csb(FLASH_CS),
    .clk(SCLK),
    .io0(MOSI),
    .io1(MISO),
    .io2(),
    .io3()
);

// graybox probes
`define core u_dut.u_core
`define MEM u_dut.u_bootrom.MEM

assign clk = u_dut.clk;
default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking

// ============================================================
logic [31:0] PROG [1024];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        int addr;

        RSTN = 1;

        // setup program: krz_blinky.c
        PROG = '{default: '0};
        $readmemh("../../../data/krz_blinky.krz.mem", PROG);

        addr = 2**20;
        foreach (PROG[i]) begin
            $display("PROG[%0d] = %h", i, PROG[i]);
            u_flash.memory[addr]   = PROG[i][0+:8];
            u_flash.memory[addr+1] = PROG[i][8+:8];
            u_flash.memory[addr+2] = PROG[i][16+:8];
            u_flash.memory[addr+3] = PROG[i][24+:8];
            addr+=4;
        end     
    end

    `TEST_CASE("boot") begin
        // setup program: krz_bootloader.c
        // Bootloader -------------------------
        // Load text
        $readmemh("../../../data/krz_bootloader.mem", `MEM);

        reset();

        // Run
        $display("\n\nEXEC\n\n");
        ##50000; // timeout watchdog
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