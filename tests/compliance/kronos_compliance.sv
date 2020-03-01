// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_compliance;

// Macros
`define q(_s) `"_s`"

// Memory Size: 8KB (2024 words)
parameter MEMSIZE = 11; // log2

import kronos_types::*;

logic clk;
logic rstz;
logic [31:0] instr_addr;
logic [31:0] instr_data;
logic instr_req;
logic instr_gnt;
logic [31:0] data_addr;
logic [31:0] data_rd_data;
logic [31:0] data_wr_data;
logic [3:0] data_wr_mask;
logic data_rd_req;
logic data_wr_req;
logic data_gnt;

kronos_core u_dut (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .instr_addr  (instr_addr  ),
    .instr_data  (instr_data  ),
    .instr_req   (instr_req   ),
    .instr_gnt   (instr_gnt   ),
    .data_addr   (data_addr   ),
    .data_rd_data(data_rd_data),
    .data_wr_data(data_wr_data),
    .data_wr_mask(data_wr_mask),
    .data_rd_req (data_rd_req ),
    .data_wr_req (data_wr_req ),
    .data_gnt    (data_gnt    )
);

logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [31:0] mem_rdata;
logic mem_en, mem_wren;
logic [3:0] mem_wmask;

spsram32_model #(.DEPTH(2**(MEMSIZE))) u_mem (
    .clk    (clk      ),
    .addr   (mem_addr ),
    .wdata  (mem_wdata),
    .rdata  (mem_rdata),
    .en     (mem_en   ),
    .wr_en  (mem_wren ),
    .wr_mask(mem_wmask)
);

// Data has Priority
always_comb begin
    mem_en = |{instr_req, data_rd_req, data_wr_req};
    mem_wren = data_wr_req;

    mem_addr = 0;
    mem_addr = (data_rd_req | data_wr_req) ?
        data_addr[2+:MEMSIZE] : instr_addr[2+:MEMSIZE];

    instr_data = mem_rdata;
    data_rd_data = mem_rdata;

    mem_wdata = data_wr_data;
    mem_wmask = data_wr_mask;
end

always_ff @(posedge clk) begin
    instr_gnt <= instr_req & ~(data_rd_req | data_wr_req);
    data_gnt <= (data_rd_req | data_wr_req);
end


default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input instr_req, instr_gnt;
    input instr_addr;
    input data_rd_req, data_wr_req, data_gnt;
    input data_addr;
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

    `TEST_CASE("compliance") begin
        int begin_signature, end_signature;
        logic [31:0] data, addr;
        
        begin_signature = `BEGIN_SIGNATURE;
        end_signature = `END_SIGNATURE;

        $display("Program: %s", `q(`PROGRAM));
        $display("begin_signature: %08h", begin_signature);
        $display("end_signature: %08h", end_signature);

        // Bootloader -----------------------------------------
        // Load Program into memory
        $readmemh(`q(`PROGRAM), u_mem.MEM);

        // De-assert reset
        ##4 rstz = 1;

        // Wait
        ##1024;

        // Print Result Memory
        $display("<<START>> %08h", begin_signature);
        for(int i=0; i<128; i++) begin
            addr = begin_signature + (i<<2);
            if (addr == end_signature) break;

            data = u_mem.MEM[addr>>2];
            $display("[%04h] %08h", addr, data);
        end
        $display("<<END>> %08h", end_signature);
        $display("\n\n");

        ##64;
    end
end

`WATCHDOG(1ms);

endmodule
