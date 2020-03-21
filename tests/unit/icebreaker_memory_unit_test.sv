// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ns
`include "vunit_defines.svh"

module tb_icemem_ut;

localparam logic [31:0] LASTADDR = (2**15)-1;

logic clk, rstz;
logic [31:0] addr;
logic [31:0] wdata;
logic [31:0] rdata;
logic en;
logic wr_en;
logic [3:0] wr_mask;

icebreaker_memory u_mem (
    .clk    (clk    ),
    .addr   (addr   ),
    .wdata  (wdata  ),
    .rdata  (rdata  ),
    .en     (en     ),
    .wr_en  (wr_en  ),
    .wr_mask(wr_mask)
);

`define MEM00 u_mem.MEMBANK[0].MEMINST[0].u_spsram.vfb_b_inst.SRAM_inst.spram256k_core_inst.uut.mem_core_array
`define MEM01 u_mem.MEMBANK[0].MEMINST[1].u_spsram.vfb_b_inst.SRAM_inst.spram256k_core_inst.uut.mem_core_array
`define MEM10 u_mem.MEMBANK[1].MEMINST[0].u_spsram.vfb_b_inst.SRAM_inst.spram256k_core_inst.uut.mem_core_array
`define MEM11 u_mem.MEMBANK[1].MEMINST[1].u_spsram.vfb_b_inst.SRAM_inst.spram256k_core_inst.uut.mem_core_array

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking

// ============================================================

logic [31:0] MEM [2**15];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        logic [31:0] data;

        clk = 0;
        rstz = 0;
        en = 0;
        wr_en = 0;

        // rand init memory+model
        // init some memory
        for (int i=0; i<2**15; i++) begin
            data = $urandom();

            MEM[i] = data;

            if (i < 2**14)
                {`MEM01[i[13:0]], `MEM00[i[13:0]]} = data;
            else 
                {`MEM11[i[13:0]], `MEM10[i[13:0]]} = data;
        end

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("rw") begin
        logic [31:0] golden, reference, word;
        ##1;

        repeat (1024) begin

            // random chance of some delay
            if ($urandom_range(0,4) == 0) ##($urandom_range(1,7));

            word = $urandom_range(0, LASTADDR);
            wr_mask = $urandom();
            wdata = $urandom();
            addr = word << 2;

            // coin toss and read/write
            if ($urandom_range(0,1) == 0) begin
                // Get expected data from model
                golden = MEM[word];

                // READ
                
                en = 1;
                ##1;
                en = 0;
                
                // Check memory read data
                reference = rdata;

                $display("READ MEM[%0d] = %h vs %h", word, golden, reference);
                assert(golden == reference);
            end
            else begin
                // update model
                for (int i=0; i<4; i++)
                    if (wr_mask[i]) MEM[word][i*8+:8] = wdata[i*8+:8];
                golden = MEM[word];

                // WRITE
                wr_en = 1;
                en = 1;
                ##1;
                wr_en = 0;
                en = 0;

                // check memory
                if (word < 2**14)
                    reference = {`MEM01[word[13:0]], `MEM00[word[13:0]]};
                else 
                    reference = {`MEM11[word[13:0]], `MEM10[word[13:0]]};

                $display("WRITE MEM[%0d] = %h vs %h, mask=%b, data=%h", word, golden, reference,
                    wr_mask, wdata);
                assert(golden == reference);
            end
        end

        ##64;
    end
end

`WATCHDOG(1ms);

endmodule
