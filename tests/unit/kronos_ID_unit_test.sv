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

module tb_kronos_ID_ut;

import kronos_types::*;

logic clk;
logic rstz;
pipeIFID_t pipe_IFID;
logic pipe_in_vld;
logic pipe_in_rdy;
pipeIDEX_t pipe_IDEX;
logic pipe_out_vld;
logic pipe_out_rdy;
logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

kronos_ID u_id (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .pipe_IFID   (pipe_IFID   ),
    .pipe_in_vld (pipe_in_vld ),
    .pipe_in_rdy (pipe_in_rdy ),
    .pipe_IDEX   (pipe_IDEX   ),
    .pipe_out_vld(pipe_out_vld),
    .pipe_out_rdy(pipe_out_rdy),
    .regwr_data  (regwr_data  ),
    .regwr_sel   (regwr_sel   ),
    .regwr_en    (regwr_en    )
);

default clocking cb @(posedge clk);
    default input #10s output #10ps;
    input pipe_out_vld, pipe_IDEX;
    input negedge pipe_in_rdy;
    output pipe_in_vld, pipe_IFID;
    output negedge pipe_out_rdy;
endclocking

// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        pipe_IFID = '0;
        pipe_in_vld = 0;
        pipe_out_rdy = 0;
        regwr_data = '0;
        regwr_en = 0;
        regwr_sel = 0;

        // init regfile with random values
        for(int i=0; i<32; i++) begin
            u_id.REG1[i] = $urandom;
            u_id.REG2[i] = u_id.REG1[i];
        end
        u_id.REG1[0] = 0; // x0 is ZERO
        u_id.REG2[0] = 0; 

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("decode") begin
        pipeIFID_t tinstr;
        pipeIDEX_t tdecode, rdecode;

        repeat (128) begin

            rand_instr(tinstr, tdecode);

            $display("IFID: PC=%h, IR=%h", tinstr.pc, tinstr.ir);
            $display("Expected IDEX:");
            $display("  op1: %h", tdecode.op1);
            $display("  op2: %h", tdecode.op2);
            $display("  rs1_read: %h", tdecode.rs1_read);
            $display("  rs2_read: %h", tdecode.rs2_read);
            $display("  rs1: %h", tdecode.rs1);
            $display("  rs2: %h", tdecode.rs2);

            fork 
                begin
                    @(cb);
                    cb.pipe_IFID <= tinstr;
                    cb.pipe_in_vld <= 1;
                    repeat (16) begin
                        @(cb) if (cb.pipe_in_rdy) begin
                            cb.pipe_in_vld <= 0;
                            break;
                        end
                    end
                end

                begin
                    @(cb iff pipe_out_vld) begin
                        //check
                        rdecode = pipe_IDEX;

                        $display("Got IDEX:");
                        $display("  op1: %h", rdecode.op1);
                        $display("  op2: %h", rdecode.op2);
                        $display("  rs1_read: %h", rdecode.rs1_read);
                        $display("  rs2_read: %h", rdecode.rs2_read);
                        $display("  rs1: %h", rdecode.rs1);
                        $display("  rs2: %h", rdecode.rs2);

                        cb.pipe_out_rdy <= 1;
                        ##1 cb.pipe_out_rdy <= 0;

                        assert(rdecode == tdecode);
                    end
                end
            join

            $display("-----------------\n\n");
        end

        ##64;
    end

end

`WATCHDOG(100us);

// ============================================================
// METHODS
// ============================================================

task automatic rand_instr(output pipeIFID_t instr, output pipeIDEX_t decode);
    /*
    Generate constrained-random instr

    Note: This would have been a breeze with SV constraints.
        However, the "free" version of modelsim doesn't support
        that feature (along with many other things, like 
        coverage, properties, sequenes, etc)
        Hence, we get by with just the humble $urandom
    */

    int instr_type;
    logic [4:0] optype, rs1, rs2;

    instr.ir = $urandom;
    instr.pc = $urandom;

    // setup valid opcode
    instr_type = $urandom_range(1);
    case(instr_type)
        0: optype = 5'b00_100; // OPIMM
        1: optype = 5'b01_100; // OP
        default: assert(0);
    endcase // instr_type

    instr.ir[0+:7] = {optype, 2'b11};
    rs1 = instr.ir[15+:5];
    rs2 = instr.ir[20+:5];

    // setup expected decode
    if (optype == 5'b00_100) begin
        // OPIMM
        decode.op1 = u_id.REG1[rs1]; // RS1
        decode.op2 = '0; // Immediate

        decode.rs1_read = rs1 != 0;
        decode.rs2_read = 0;
        decode.rs1 = rs1;
        decode.rs2 = rs2;
    end

    if (optype == 5'b01_100) begin
        // OP
        // Note: Read from same "REG", because REG1 and REG2 are supposed to have
        // the same data at any time
        decode.op1 = u_id.REG1[rs1]; // RS1
        decode.op2 = u_id.REG1[rs2]; // RS2

        decode.rs1_read = rs1 != 0;
        decode.rs2_read = rs2 != 0;
        decode.rs1 = rs1;
        decode.rs2 = rs2;
    end 

endtask

endmodule