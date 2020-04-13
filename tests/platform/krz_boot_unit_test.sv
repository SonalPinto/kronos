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

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        int addr;

        RSTN = 1;

        addr = 2**20;
        u_flash.memory[addr] = 0;
        u_flash.memory[addr+1] = 2;
        u_flash.memory[addr+2] = 0;
        u_flash.memory[addr+3] = 0;
        for(int i=0; i<128; i++) begin
            addr = addr + 4;
            u_flash.memory[addr]   = i;
            u_flash.memory[addr+1] = ~i;
            u_flash.memory[addr+2] = i;
            u_flash.memory[addr+3] = ~i;
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