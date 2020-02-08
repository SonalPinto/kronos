// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_kronos_ID_ut;

import kronos_types::*;

logic clk;
logic rstz;
pipeIFID_t fetch;
logic pipe_in_vld;
logic pipe_in_rdy;
pipeIDEX_t decode;
logic pipe_out_vld;
logic pipe_out_rdy;
logic [31:0] regwr_data;
logic [4:0] regwr_sel;
logic regwr_en;

kronos_ID u_id (
    .clk         (clk         ),
    .rstz        (rstz        ),
    .fetch       (fetch       ),
    .pipe_in_vld (pipe_in_vld ),
    .pipe_in_rdy (pipe_in_rdy ),
    .decode      (decode      ),
    .pipe_out_vld(pipe_out_vld),
    .pipe_out_rdy(pipe_out_rdy),
    .regwr_data  (regwr_data  ),
    .regwr_sel   (regwr_sel   ),
    .regwr_en    (regwr_en    )
);

default clocking cb @(posedge clk);
    default input #10s output #10ps;
    input pipe_out_vld, decode;
    input negedge pipe_in_rdy;
    output pipe_in_vld, fetch;
    output negedge pipe_out_rdy;
endclocking

// ============================================================

logic [31:0] REG [32];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        fetch = '0;
        pipe_in_vld = 0;
        pipe_out_rdy = 0;
        regwr_data = '0;
        regwr_en = 0;
        regwr_sel = 0;

        // init regfile with random values
        for(int i=0; i<32; i++) begin
            u_id.REG1[i] = $urandom;
            u_id.REG2[i] = u_id.REG1[i];
            REG[i] = u_id.REG1[i];
        end

        // Zero out TB's REG[0] (x0)
        REG[0] = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("decode") begin
        pipeIFID_t tinstr;
        pipeIDEX_t tdecode, rdecode;
        string optype;

        repeat (2**12) begin

            rand_instr(tinstr, tdecode, optype);

            $display("OPTYPE=%s", optype);
            $display("IFID: PC=%h, IR=%h", tinstr.pc, tinstr.ir);
            $display("Expected IDEX:");
            $display("  op1: %h", tdecode.op1);
            $display("  op2: %h", tdecode.op2);
            $display("  rs1_read: %h", tdecode.rs1_read);
            $display("  rs2_read: %h", tdecode.rs2_read);
            $display("  rs1: %h", tdecode.rs1);
            $display("  rs2: %h", tdecode.rs2);
            $display("  rd: %h", tdecode.rd);
            $display("  rd_write: %h", tdecode.rd_write);
            $display("  neg: %h", tdecode.neg);
            $display("  rev: %h", tdecode.rev);
            $display("  cin: %h", tdecode.cin);
            $display("  uns: %h", tdecode.uns);
            $display("  eq: %h", tdecode.eq);
            $display("  inv: %h", tdecode.inv);
            $display("  sel: %h", tdecode.sel);

            fork 
                begin
                    @(cb);
                    cb.fetch <= tinstr;
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
                        rdecode = decode;

                        $display("Got IDEX:");
                        $display("  op1: %h", rdecode.op1);
                        $display("  op2: %h", rdecode.op2);
                        $display("  rs1_read: %h", rdecode.rs1_read);
                        $display("  rs2_read: %h", rdecode.rs2_read);
                        $display("  rs1: %h", rdecode.rs1);
                        $display("  rs2: %h", rdecode.rs2);
                        $display("  rd: %h", rdecode.rd);
                        $display("  rd_write: %h", rdecode.rd_write);
                        $display("  neg: %h", rdecode.neg);
                        $display("  rev: %h", rdecode.rev);
                        $display("  cin: %h", rdecode.cin);
                        $display("  uns: %h", rdecode.uns);
                        $display("  eq: %h", rdecode.eq);
                        $display("  inv: %h", rdecode.inv);
                        $display("  sel: %h", rdecode.sel);

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

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_instr(output pipeIFID_t instr, output pipeIDEX_t decode, output string optype);
    /*
    Generate constrained-random instr

    Note: This would have been a breeze with SV constraints.
        However, the "free" version of modelsim doesn't support
        that feature (along with many other things, like 
        coverage, properties, sequences, etc)
        Hence, we get by with just the humble $urandom

        You can do A LOT of things with just $urandom
    */

    int op;

    logic [6:0] opcode;
    logic [4:0] rs1, rs2, rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm;

    op = $urandom_range(0,20);
    imm = $urandom();
    rs1 = $urandom();
    rs2 = $urandom();
    rd = $urandom_range(1,31);

    instr.pc = $urandom;

    decode.illegal = 0;

    // painstakingly build random-valid instructions
    // and expected decode
    case(op)
        0: begin
            optype = "ADDI";

            instr.ir = {imm[11:0], rs1, 3'b000, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 0;
        end

        1: begin
            optype = "SLTI";

            instr.ir = {imm[11:0], rs1, 3'b010, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 1;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 3'd4;
        end

        2: begin
            optype = "SLTIU";

            instr.ir = {imm[11:0], rs1, 3'b011, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 1;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 1;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 4;
        end

        3: begin
            optype = "XORI";

            instr.ir = {imm[11:0], rs1, 3'b100, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 3;
        end

        4: begin
            optype = "ORI";

            instr.ir = {imm[11:0], rs1, 3'b110, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 2;
        end

        5: begin
            optype = "ANDI";

            instr.ir = {imm[11:0], rs1, 3'b111, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 1;
        end

        6: begin
            optype = "SLLI";

            instr.ir = {7'b0, imm[4:0], rs1, 3'b001, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0, imm[4:0]});
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 1;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 5;
        end

        7: begin
            optype = "SRLI";

            instr.ir = {7'b0, imm[4:0], rs1, 3'b101, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0,imm[4:0]});
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 5;
        end

        8: begin
            optype = "SRAI";

            instr.ir = {7'b0100000, imm[4:0], rs1, 3'b101, rd, 7'b00_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0100000,imm[4:0]});
            decode.rs1_read = 1;
            decode.rs2_read = 0;
            decode.rs1 = rs1;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 5;
        end

        9: begin
            optype = "ADD";

            instr.ir = {7'b0, rs2, rs1, 3'b000, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 0;
        end

        10: begin
            optype = "SUB";

            instr.ir = {7'b0100000, rs2, rs1, 3'b000, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 1;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 0;
        end

        11: begin
            optype = "SLL";

            instr.ir = {7'b0000000, rs2, rs1, 3'b001, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 1;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 5;
        end

        12: begin
            optype = "SLL";

            instr.ir = {7'b0000000, rs2, rs1, 3'b010, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 1;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 4;
        end


        13: begin
            optype = "SLTU";

            instr.ir = {7'b0000000, rs2, rs1, 3'b011, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 1;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 1;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 4;
        end

        14: begin
            optype = "XOR";

            instr.ir = {7'b0000000, rs2, rs1, 3'b100, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 3;
        end

        15: begin
            optype = "SRL";

            instr.ir = {7'b0000000, rs2, rs1, 3'b101, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 5;
        end

        16: begin
            optype = "SRA";

            instr.ir = {7'b0100000, rs2, rs1, 3'b101, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 1;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 5;
        end

        17: begin
            optype = "OR";

            instr.ir = {7'b0000000, rs2, rs1, 3'b110, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 2;
        end

        18: begin
            optype = "AND";

            instr.ir = {7'b0000000, rs2, rs1, 3'b111, rd, 7'b01_100_11};

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rs1_read = 1;
            decode.rs2_read = 1;
            decode.rs1 = rs1;
            decode.rs2 = rs2;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 1;
        end

        19: begin
            optype = "LUI";

            instr.ir = {imm[31:12], rd, 7'b01_101_11};

            decode.op1 = 0;
            decode.op2 = {imm[31:12], 12'b0};
            decode.rs1_read = 0;
            decode.rs2_read = 0;
            decode.rs1 = 0;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 0;
        end

        20: begin
            optype = "AUIPC";

            instr.ir = {imm[31:12], rd, 7'b00_101_11};

            decode.op1 = instr.pc;
            decode.op2 = {imm[31:12], 12'b0};
            decode.rs1_read = 0;
            decode.rs2_read = 0;
            decode.rs1 = 0;
            decode.rs2 = 0;
            decode.rd  = rd;
            decode.rd_write = 1;
            decode.neg = 0;
            decode.rev = 0;
            decode.cin = 0;
            decode.uns = 0;
            decode.eq  = 0;
            decode.inv = 0;
            decode.sel = 0;
        end
    endcase // instr
endtask

endmodule