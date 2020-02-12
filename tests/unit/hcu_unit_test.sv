// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_hcu_ut;

import kronos_types::*;

logic clk;
logic rstz;
logic [31:0] instr_addr;
logic [31:0] instr_data;
logic instr_req;
logic instr_gnt;

logic run;

kronos_core u_dut (
    .clk       (clk       ),
    .rstz      (rstz      ),
    .instr_addr(instr_addr),
    .instr_data(instr_data),
    .instr_req (instr_req ),
    .instr_gnt (instr_gnt & run)
);


spsram32_model #(.DEPTH(256)) u_imem (
    .clk    (clk       ),
    .addr   (instr_addr[2+:8]),
    .wdata  (32'b0     ),
    .rdata  (instr_data),
    .en     (instr_req ),
    .wr_en  (1'b0      ),
    .wr_mask(4'b0      )
);

always_ff @(posedge clk) instr_gnt <= instr_req;


default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input instr_req, instr_addr;
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
        logic [31:0] instr;
        int prog_size, index;
        int data;
        int n;

        // setup program: DOUBLER
        /*  
            repeat(n):
                x = x + x
        */
        // load 1 in x1
        instr = {12'd1, 5'd0, 3'b000, 5'd1, 7'b00_100_11}; // addi x1, x0, 1
        PROGRAM.push_back(instr);

        n = $urandom_range(1,31);
        $display("N = %d", n);
        repeat(n) begin
            instr = {7'b0, 5'd1, 5'd1, 3'b000, 5'd1, 7'b01_100_11}; // add x1, x1, x1
            PROGRAM.push_back(instr);
        end

        prog_size = PROGRAM.size();

        // Bootload
        foreach(PROGRAM[i])
            u_imem.MEM[i] = PROGRAM[i];

        // Run
        fork 
            begin
                @(cb) cb.run <= 1;
            end

            forever @(cb) begin
                if (instr_req && instr_gnt) begin
                    index = cb.instr_addr>>2;
                    if (index >= prog_size) begin
                        cb.run <= 0;
                        break;
                    end
                    instr = PROGRAM[index];
                    $display("[%0d] INSTR=%h", index, instr);
                end
            end
        join

        ##32;

        data = u_dut.u_id.REG1[1];
        $display("x1: %d", data);
        assert(data == 2**n);

        ##64;
    end
end

`WATCHDOG(1ms);


endmodule