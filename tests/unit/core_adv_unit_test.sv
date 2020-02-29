// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_core_ut;

/*
For this test suite, the memory is limited to 4KB (1024 words)

The results will be stored in the .data section starting at 960
*/

import kronos_types::*;
import rv32_assembler::*;

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

logic run;

kronos_core u_dut (
    .clk         (clk            ),
    .rstz        (rstz           ),
    .instr_addr  (instr_addr     ),
    .instr_data  (instr_data     ),
    .instr_req   (instr_req      ),
    .instr_gnt   (instr_gnt & run),
    .data_addr   (data_addr      ),
    .data_rd_data(data_rd_data   ),
    .data_wr_data(data_wr_data   ),
    .data_wr_mask(data_wr_mask   ),
    .data_rd_req (data_rd_req    ),
    .data_wr_req (data_wr_req    ),
    .data_gnt    (data_gnt       )
);

logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [31:0] mem_rdata;
logic mem_en, mem_wren;
logic [3:0] mem_wmask;

spsram32_model #(.DEPTH(1024)) u_imem (
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
        data_addr[2+:10] : instr_addr[2+:10];

    instr_data = mem_rdata;
    data_rd_data = mem_rdata;

    mem_wdata = data_wr_data;
    mem_wmask = data_wr_mask;
end

always_ff @(posedge clk) begin
    instr_gnt <= (instr_req) & ~(data_rd_req | data_wr_req) && run;
    data_gnt <= (data_rd_req | data_wr_req);
end


default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input instr_req, instr_addr, instr_gnt;
    output negedge run;
endclocking

// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        run = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("doubler") begin
        logic [31:0] PROGRAM [$];
        instr_t instr;
        int index, addr;
        int data;
        int n;
        int r_exp, r_got;

        // setup program: DOUBLER - from test source: doubler.c
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
        $readmemh("../../../data/doubler.mem", u_imem.MEM);

        // ABI --------------------------------
        // Setup Return Address (ra/x1)
        u_dut.u_id.REG1[x1] = 944;
        u_dut.u_id.REG2[x1] = 944;

        // Store while(1); at 944
        u_imem.MEM[944>>2] = rv32_jal(x0, 0); // j 1b

        // Setup Frame Pointer (s0/x8)
        u_dut.u_id.REG1[x8] = 0;
        u_dut.u_id.REG2[x8] = 0;

        // Setup Stack Pointer (sp/x2) to the end of the memory (4KB)
        u_dut.u_id.REG1[x2] = 1024;
        u_dut.u_id.REG2[x2] = 1024;

        // Setup Function Argument - "n" - at a0 (x10)
        n = $urandom_range(1,31);
        $display("\n\nARG: n = %0d", n);
        u_dut.u_id.REG1[x10] = n;
        u_dut.u_id.REG2[x10] = n;

        // Run
        $display("\n\nEXEC\n\n");
        fork 
            begin
                @(cb) cb.run <= 1;
            end

            forever @(cb) begin
                if (instr_req && instr_gnt) begin
                    addr = cb.instr_addr;
                    instr = u_imem.MEM[addr>>2];
                    $display("[%0d] ADDR=%0d, INSTR=%h", index, addr, instr);
                    index++;
                    if (addr == 944) begin
                        cb.run <= 0;
                        break;
                    end
                end
            end
        join
        $display("\n\n");

        //-------------------------------
        // check
        r_exp = 2**n;
        r_got = u_imem.MEM[960>>2];
        $display("RESULT: %d vs %d", r_exp, r_got);
        assert(r_exp == r_got);

        ##64;
    end
end

`WATCHDOG(1ms);


endmodule
