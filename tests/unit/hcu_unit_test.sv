// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_hcu_ut;

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


spsram32_model #(.DEPTH(1024)) u_imem (
    .clk    (clk       ),
    .addr   (instr_addr[2+:10]),
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
        data_gnt = 0;

        // // init regfile with random values
        // for(int i=0; i<32; i++) begin
        //     u_dut.u_id.REG1[i] = $urandom;
        //     u_dut.u_id.REG2[i] = u_dut.u_id.REG1[i];
        // end

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("doubler") begin
        logic [31:0] PROGRAM [$];
        instr_t instr;
        int prog_size, index;
        int data;
        int n;

        // setup program: DOUBLER
        /*  
            x1 = 1
            repeat(n):
                x1 = x1 + x1
        */
        // load 1 in x1
        instr = rv32_addi(x1, x0, 1);
        PROGRAM.push_back(instr);

        n = $urandom_range(1,31);
        $display("N = %d", n);
        repeat(n) begin
            instr = rv32_add(x1, x1, x1);
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


    `TEST_CASE("fibonnaci") begin
        logic [31:0] PROGRAM [$];
        instr_t instr;
        int prog_size, index;
        int reg_x1, reg_x2, reg_x3;
        int a, b, c;
        int n;

        // setup program: FIBONNACI
        /*  
            x1 = 0
            x2 = 1
            repeat(n):
                x3 = x1 + x2
                x1 = x2
                x2 = x3
        */
        // x1 = 0
        instr = rv32_add(x1, x0, x0);
        PROGRAM.push_back(instr);
        // x2 = 1
        instr = rv32_addi(x2, x0, 1);
        PROGRAM.push_back(instr);

        n = $urandom_range(1, 32);
        $display("N = %d", n);
        repeat(n) begin
            // x3 = x1 + x2
            instr = rv32_add(x3, x1, x2);
            PROGRAM.push_back(instr);
            // x1 = x2
            instr = rv32_add(x1, x2, x0);
            PROGRAM.push_back(instr);
            // x2 = x3
            instr = rv32_add(x2, x3, x0);
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

        //-------------------------------
        // check
        a = 0;
        b = 1;
        repeat(n) begin
            c = a+b;
            a = b;
            b = c;
        end

        reg_x1 = u_dut.u_id.REG1[1];
        reg_x2 = u_dut.u_id.REG1[2];
        reg_x3 = u_dut.u_id.REG1[3];
        $display("REG[x1]=%d vs a=%d", reg_x1, a);
        $display("REG[x2]=%d vs b=%d", reg_x2, b);
        $display("REG[x3]=%d vs c=%d", reg_x3, c);
        assert(reg_x1 == a);
        assert(reg_x2 == b);
        assert(reg_x3 == c);

        ##64;
    end
end

`WATCHDOG(1ms);


endmodule
