/*
   Copyright (c) 2020 Sonal Pinto <sonalpinto@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

`include "vunit_defines.svh"

module tb_kronos_IF_ut;

import kronos_types::*;

logic clk;
logic rstz;
logic [31:0] instr_addr;
logic [31:0] instr_data;
logic instr_req;
logic instr_gnt;
pipeIFID_t pipe_IFID;
logic pipe_vld;
logic pipe_rdy;
logic [31:0] branch_target;
logic branch;

logic miss;

kronos_IF u_dut (
    .clk          (clk          ),
    .rstz         (rstz         ),
    .instr_addr   (instr_addr   ),
    .instr_data   (instr_data   ),
    .instr_req    (instr_req    ),
    .instr_gnt    (instr_gnt & ~miss),
    .pipe_IFID    (pipe_IFID    ),
    .pipe_vld     (pipe_vld     ),
    .pipe_rdy     (pipe_rdy     ),
    .branch_target(branch_target),
    .branch       (branch       )
);

spsram32_model #(.DEPTH(256)) u_imem (
    .clk (clk       ),
    .rstz(rstz      ),
    .addr(instr_addr),
    .data(instr_data),
    .req (instr_req ),
    .gnt (instr_gnt )
);
// ------------------------------------------------------------

default clocking cb @(posedge clk);
    default input #10s output #10ps;
    input pipe_IFID, pipe_vld, instr_req;
    output negedge pipe_rdy;
endclocking

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;
        miss = 0;

        branch = 0;
        branch_target = 0;
        pipe_rdy = 0;

        for(int i=0; i<256; i++)
            u_imem.MEM[i] = $urandom;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("ideal") begin
        logic [31:0] expected_pc;
        
        expected_pc = 0;
        pipe_rdy = 1;

        repeat(128) begin
            @(cb iff pipe_vld) begin        
                $display("PC=%h, IR=%h", pipe_IFID.pc, pipe_IFID.ir);
                assert(pipe_IFID.ir == u_imem.MEM[pipe_IFID.pc[7:0]]);
                assert(expected_pc == pipe_IFID.pc);
                expected_pc += 4;
            end
        end
        ##64;
    end

    `TEST_CASE("stall") begin
        // backpressure from ID, i.e. stall
        logic [31:0] expected_pc;

        expected_pc = 0;
        repeat(128) begin
            @(cb iff pipe_vld) begin
                // random chance of backpressure from memory
                if ($urandom_range(0,1)) begin
                    cb.pipe_rdy <= 0;
                    ##($urandom_range(1,4));
                end
                cb.pipe_rdy <= 1;

                $display("PC=%h, IR=%h", pipe_IFID.pc, pipe_IFID.ir);
                assert(pipe_IFID.ir == u_imem.MEM[pipe_IFID.pc[7:0]]);
                assert(expected_pc == pipe_IFID.pc);
                expected_pc += 4;
            end
        end
        ##64;
    end

    `TEST_CASE("miss") begin
        // backpressure from memory, i.e. miss
        logic [31:0] expected_pc;

        expected_pc = 0;
        pipe_rdy = 1;

        fork
            forever @(negedge clk) begin
                // random chance of miss (arbitration loss or miss)
                if ($urandom_range(0,1)) begin
                    miss = 1;
                    ##($urandom_range(1,4));
                end
                @(negedge clk);
                miss = 0;
            end

            repeat(128) begin
                @(cb iff pipe_vld) begin        
                    $display("PC=%h, IR=%h", pipe_IFID.pc, pipe_IFID.ir);
                    assert(pipe_IFID.ir == u_imem.MEM[pipe_IFID.pc[7:0]]);
                    assert(expected_pc == pipe_IFID.pc);
                    expected_pc += 4;
                end
            end
        join_any

        ##64;
    end

    `TEST_CASE("miss_and_stall") begin
        // backpressure from memory, i.e. miss
        logic [31:0] expected_pc;

        expected_pc = 0;

        fork
            forever @(negedge clk) begin
                // random chance of miss (arbitration loss or miss)
                if ($urandom_range(0,1)) begin
                    miss = 1;
                    ##($urandom_range(1,4));
                end
                @(negedge clk);
                miss = 0;
            end

            repeat(128) begin
                @(cb iff pipe_vld) begin
                     // random chance of backpressure from memory
                    if ($urandom_range(0,1)) begin
                        cb.pipe_rdy <= 0;
                        ##($urandom_range(1,4));
                    end
                    cb.pipe_rdy <= 1;

                    $display("PC=%h, IR=%h", pipe_IFID.pc, pipe_IFID.ir);
                    assert(pipe_IFID.ir == u_imem.MEM[pipe_IFID.pc[7:0]]);
                    assert(expected_pc == pipe_IFID.pc);
                    expected_pc += 4;
                end
            end
        join_any

        ##64;
    end
end

`WATCHDOG(100us);

// ------------------------------------------------------------

endmodule