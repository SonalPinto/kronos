// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_kronos_EX_ut;

import kronos_types::*;

logic clk;
logic rstz;
pipeIDEX_t decode;
logic pipe_in_vld;
logic pipe_in_rdy;
pipeEXWB_t execute;
logic pipe_out_vld;
logic pipe_out_rdy;
logic [31:0] fwd_data;
logic fwd_vld;

kronos_EX u_ex (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .decode      (decode      ),
    .pipe_in_vld (pipe_in_vld ),
    .pipe_in_rdy (pipe_in_rdy ),
    .execute     (execute     ),
    .pipe_out_vld(pipe_out_vld),
    .pipe_out_rdy(pipe_out_rdy),
    .fwd_data    (fwd_data    ),
    .fwd_vld     (fwd_vld     )
);

default clocking cb @(posedge clk);
    default input #10s output #10ps;
    input pipe_out_vld, execute;
    input negedge pipe_in_rdy;
    output pipe_in_vld, decode;
    output negedge pipe_out_rdy;
endclocking

// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        decode = '0;
        pipe_in_vld = 0;
        pipe_out_rdy = 0;

        fwd_vld = 0;
        fwd_data = '0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("simple") begin
        string optype;
        pipeIDEX_t tdecode;
        pipeEXWB_t texecute, rexecute;


        repeat (128) begin
            rand_decode_simple(tdecode, texecute, optype);

            $display("OPTYPE=%s", optype);
            $display("OP1: %d", signed'(tdecode.op1));
            $display("OP2: %d", signed'(tdecode.op2));
            $display("Expected: ",);
            $display("  result1: %d", signed'(texecute.result1));

            fork 
                begin
                    @(cb);
                    cb.decode <= tdecode;
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
                        rexecute = execute;
                        $display("Got:");
                        $display("  result1: %d", signed'(rexecute.result1));

                        cb.pipe_out_rdy <= 1;
                        ##1 cb.pipe_out_rdy <= 0;

                        assert(rexecute == texecute);
                    end
                end
            join

            $display("-----------------\n\n");
        end

        ##64;
    end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_decode_simple(output pipeIDEX_t decode, output pipeEXWB_t execute, output string optype);
    /*
    Generate constrained-random decode
    */

    int aluop;
    int op1, op2; // logic signed [31:0]

    aluop = $urandom_range(0,4);
    op1 = $urandom();
    op2 = $urandom();

    decode.op1 = op1;
    decode.op2 = op2;
    decode.rs1_read = 1;
    decode.rs2_read = 1;
    decode.rs1 = 1;
    decode.rs2 = 1;
    decode.rd = $urandom;
    decode.rd_write = $urandom; 
    decode.neg = 0;
    decode.rev = 0;
    decode.cin = 0;
    decode.uns = 0;
    decode.gte = 0;
    decode.sel = ALU_ADDER;
    decode.illegal = $urandom;

    execute.result2 = '0;
    execute.rd = decode.rd;
    execute.rd_write = decode.rd_write;
    execute.illegal = decode.illegal;

    case(aluop)
        0: begin
            optype = "ADD";
            execute.result1 = op1 + op2;
        end
        1: begin
            optype = "SUB";
            decode.neg = 1;
            decode.cin = 1;

            execute.result1 = op1 - op2;
        end
        2: begin
            optype = "AND";
            decode.sel = ALU_AND;

            execute.result1 = op1 & op2;
        end
        3: begin
            optype = "OR";
            decode.sel = ALU_OR;

            execute.result1 = op1 | op2;
        end
        4: begin
            optype = "XOR";
            decode.sel = ALU_XOR;

            execute.result1 = op1 ^ op2;
        end
    endcase
endtask

endmodule