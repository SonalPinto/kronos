// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_kronos_EX_ut;

import kronos_types::*;
import common::*;

logic clk;
logic rstz;
pipeIDEX_t decode;
logic pipe_in_vld;
logic pipe_in_rdy;
pipeEXWB_t execute;
logic pipe_out_vld;
logic pipe_out_rdy;


kronos_EX u_ex (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .flush       (1'b0        ),
    .decode      (decode      ),
    .pipe_in_vld (pipe_in_vld ),
    .pipe_in_rdy (pipe_in_rdy ),
    .execute     (execute     ),
    .pipe_out_vld(pipe_out_vld),
    .pipe_out_rdy(pipe_out_rdy)
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
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

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("simple") begin
        string optype;
        pipeIDEX_t tdecode;
        pipeEXWB_t texecute, rexecute;


        repeat (2**10) begin
            rand_decode_simple(tdecode, texecute, optype);

            $display("OPTYPE=%s", optype);
            $display("OP1: %d", signed'(tdecode.op1));
            $display("OP2: %d", signed'(tdecode.op2));
            $display("Expected: ");
            print_execute(texecute);


            @(cb);
            cb.decode <= tdecode;
            cb.pipe_in_vld <= 1;
            @(cb iff cb.pipe_in_rdy) begin
                cb.pipe_in_vld <= 0;
            end
       
            @(cb iff cb.pipe_out_vld);
            //check
            rexecute = execute;
            $display("Got:");
            print_execute(rexecute);

            cb.pipe_out_rdy <= 1;
            ##1 cb.pipe_out_rdy <= 0;

            assert(rexecute == texecute);


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
    int op1, op2, op3, op4;
    logic [31:0] op1_uns, op2_uns;

    // Scenario
    aluop = $urandom_range(0,14);
    op1 = $urandom();
    op2 = $urandom();
    op3 = $urandom();
    op4 = $urandom();

    // 5% chance of operands being the same!
    if ($urandom_range(0,19) == 0) op2 = op1;

    op1_uns = op1;
    op2_uns = op2;

    //=========================
    // DECODE
    decode = '0;
    decode.op1 = op1;
    decode.op2 = op2;
    decode.op3 = op3;
    decode.op4 = op4;

    //=========================
    // EXECUTE
    execute.pc      = 0;
    execute.result1 = 0;
    execute.result2 = op3 + op4;

    execute.rd          = decode.rd;
    execute.rd_write    = decode.rd_write;
    execute.branch      = decode.branch;
    execute.branch_cond = decode.branch_cond;
    execute.ld          = decode.ld;
    execute.st          = decode.st;
    execute.funct3      = decode.funct3;
    execute.csr         = decode.csr;
    execute.ecall       = decode.ecall;
    execute.ret         = decode.ret;
    execute.wfi         = decode.wfi;
    execute.is_illegal  = decode.is_illegal;

    case(aluop)
        0: begin
            optype = "ADD";
            execute.result1 = op1 + op2;
        end
        1: begin
            optype = "SUB";
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
        5: begin
            optype = "LT";
            decode.cin = 1;
            decode.sel = ALU_COMP;

            execute.result1 = (op1 < op2) ? 32'b1 : 32'b0;
        end
        6: begin
            optype = "LTU";
            decode.cin = 1;
            decode.uns = 1;
            decode.sel = ALU_COMP;

            execute.result1 = (op1_uns < op2_uns) ? 32'b1 : 32'b0;
        end
        7: begin
            optype = "GTE";
            decode.cin = 1;
            decode.inv = 1;
            decode.sel = ALU_COMP;

            execute.result1 = (op1 >= op2) ? 32'b1 : 32'b0;
        end
        8: begin
            optype = "GTEU";
            decode.cin = 1;
            decode.inv = 1;
            decode.uns = 1;
            decode.sel = ALU_COMP;

            execute.result1 = (op1_uns >= op2_uns) ? 32'b1 : 32'b0;
        end
        9: begin
            optype = "EQ";
            decode.eq = 1;
            decode.sel = ALU_COMP;

            execute.result1 = (op1_uns == op2_uns) ? 32'b1 : 32'b0;
        end
        10: begin
            optype = "NEQ";
            decode.eq  = 1;
            decode.inv = 1;
            decode.sel = ALU_COMP;

            execute.result1 = (op1_uns != op2_uns) ? 32'b1 : 32'b0;
        end
        11: begin
            optype = "SHR";
            decode.uns = 1;
            decode.sel = ALU_SHIFT;

            execute.result1 = op1 >> op2[4:0];
        end
        12: begin
            optype = "SHRA";
            decode.sel = ALU_SHIFT;

            execute.result1 = op1 >>> op2[4:0];
        end
        13: begin
            optype = "SHL";
            decode.rev = 1;
            decode.uns = 1;
            decode.sel = ALU_SHIFT;

            execute.result1 = op1 << op2[4:0];
        end
        14: begin
            optype = "SADD_ALIGN";
            decode.align = 1;

            execute.result1 = op1 + op2;
            execute.result2 = (op3 + op4) & ~1;
        end
    endcase
endtask

endmodule