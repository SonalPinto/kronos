// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


`include "vunit_defines.svh"

module tb_kronos_ID_ut;

import kronos_types::*;
import rv32_assembler::*;
import common::*;

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
    .flush       (1'b0        ),
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
    default input #10ps output #10ps;
    input pipe_out_vld, decode;
    input negedge pipe_in_rdy;
    output pipe_in_vld, fetch, regwr_en;
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
        logic write_back;
        string optype;

        repeat (2**10) begin

            rand_instr(tinstr, tdecode, write_back, optype);

            $display("OPTYPE=%s", optype);
            $display("IFID: PC=%h, IR=%h", tinstr.pc, tinstr.ir);
            $display("Expected IDEX:");
            print_decode(tdecode);

            @(cb);
            cb.fetch <= tinstr;
            cb.pipe_in_vld <= 1;
            @(cb iff cb.pipe_in_rdy) begin
                cb.pipe_in_vld <= 0;
            end

            @(cb iff cb.pipe_out_vld);

            //check
            rdecode = decode;

            $display("Got IDEX:");
            print_decode(rdecode);

            cb.pipe_out_rdy <= 1;
            ##1 cb.pipe_out_rdy <= 0;

            assert(rdecode == tdecode);

            // Write back register, else the HCU will stall
            if (write_back) begin
                regwr_data = $urandom();
                regwr_sel = rdecode.rd;
                REG[rdecode.rd] = regwr_data;
                @(cb) cb.regwr_en <= 1;
                ##1 cb.regwr_en <= 0;
            end

            $display("-----------------\n\n");
        end

        ##64;
    end

end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic rand_instr(output pipeIFID_t instr, output pipeIDEX_t decode, 
    output logic write_back, output string optype);
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
    logic [11:0] csr;
    logic [4:0] zimm;

    // generate scenario
    op = $urandom_range(0,47);
    imm = $urandom();
    rs1 = $urandom();
    rs2 = $urandom();
    rd = $urandom();
    csr = $urandom();
    zimm = $urandom();

    instr.pc = $urandom;

    // Blank out decode
    decode.pc  = instr.pc;
    // EX Operands ------------
    decode.op1 = instr.pc;
    decode.op2 = 4;
    decode.op3 = instr.pc;
    decode.op4 = 4;
    // ------------------------
    // EX controls
    decode.cin = 0;
    decode.rev = 0;
    decode.uns = 0;
    decode.eq = 0;
    decode.inv = 0;
    decode.align = 0;
    decode.sel = 0;
    // ------------------------
    // WB controls
    decode.rd = 0;
    decode.rd_write = 0;
    decode.branch = 0;
    decode.branch_cond = 0;
    decode.ld = 0;
    decode.st = 0;
    decode.funct3 = 0;
    // ------------------------
    // System
    decode.csr = 0;
    decode.ecall = 0;
    decode.ebreak = 0;
    decode.ret = 0;
    decode.wfi = 0;
    // ------------------------
    // Exceptions
    decode.is_illegal = 0;

    // indicate that a register write back is required
    write_back = 0;

    // painstakingly build random-valid instructions
    // and expected decode
    case(op)
        0: begin
            optype = "ADDI";
            instr.ir = rv32_addi(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rd  = rd;
            decode.rd_write = rd != 0;
        end

        1: begin
            optype = "SLTI";
            instr.ir = rv32_slti(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.cin = 1;
            decode.sel = ALU_COMP;
        end

        2: begin
            optype = "SLTIU";
            instr.ir = rv32_sltiu(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.cin = 1;
            decode.uns = 1;
            decode.sel = ALU_COMP;
        end

        3: begin
            optype = "XORI";
            instr.ir = rv32_xori(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_XOR;
        end

        4: begin
            optype = "ORI";
            instr.ir = rv32_ori(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_OR;
        end

        5: begin
            optype = "ANDI";
            instr.ir = rv32_andi(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_AND;
        end

        6: begin
            optype = "SLLI";
            instr.ir = rv32_slli(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0, imm[4:0]});
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.rev = 1;
            decode.uns = 1;
            decode.sel = ALU_SHIFT;
        end

        7: begin
            optype = "SRLI";
            instr.ir = rv32_srli(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0, imm[4:0]});
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.uns = 1;
            decode.sel = ALU_SHIFT;
        end

        8: begin
            optype = "SRAI";
            instr.ir = rv32_srai(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'({7'b0100000,imm[4:0]});
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_SHIFT;
        end

        9: begin
            optype = "ADD";
            instr.ir = rv32_add(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;
        end

        10: begin
            optype = "SUB";
            instr.ir = rv32_sub(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.cin = 1;
        end

        11: begin
            optype = "SLL";
            instr.ir = rv32_sll(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.rev = 1;
            decode.uns = 1;
            decode.sel = ALU_SHIFT;
        end

        12: begin
            optype = "SLT";
            instr.ir = rv32_slt(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.cin = 1;
            decode.sel = ALU_COMP;
        end


        13: begin
            optype = "SLTU";
            instr.ir = rv32_sltu(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.cin = 1;
            decode.uns = 1;
            decode.sel = ALU_COMP;
        end

        14: begin
            optype = "XOR";
            instr.ir = rv32_xor(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_XOR;
        end

        15: begin
            optype = "SRL";
            instr.ir = rv32_srl(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.uns = 1;
            decode.sel = ALU_SHIFT;
        end

        16: begin
            optype = "SRA";
            instr.ir = rv32_sra(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_SHIFT;
        end

        17: begin
            optype = "OR";
            instr.ir = rv32_or(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_OR;
        end

        18: begin
            optype = "AND";
            instr.ir = rv32_and(rd, rs1, rs2);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.sel = ALU_AND;
        end

        19: begin
            optype = "LUI";
            instr.ir = rv32_lui(rd, imm);

            decode.op1 = 0;
            decode.op2 = {imm[31:12], 12'b0};
            decode.rd  = rd;
            decode.rd_write = rd != 0;
        end

        20: begin
            optype = "AUIPC";
            instr.ir = rv32_auipc(rd, imm);

            decode.op1 = instr.pc;
            decode.op2 = {imm[31:12], 12'b0};
            decode.rd  = rd;
            decode.rd_write = rd != 0;
        end

        21: begin
            optype = "JAL";
            instr.ir = rv32_jal(rd, imm);

            decode.op1 = instr.pc;
            decode.op2 = 4;
            decode.op3 = instr.pc;
            decode.op4 = signed'({imm[20:1], 1'b0});
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.branch = 1;
        end

        22: begin
            optype = "JALR";
            instr.ir = rv32_jalr(rd, rs1, imm);

            decode.op1 = instr.pc;
            decode.op2 = 4;
            decode.op3 = REG[rs1];
            decode.op4 = signed'(imm[11:0]);
            decode.rd  = rd;
            decode.rd_write = rd != 0;

            decode.align = 1;
            decode.branch = 1;
        end

        23: begin
            optype = "BEQ";
            instr.ir = rv32_beq(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.op3 = instr.pc;
            decode.op4 = signed'({imm[12:1], 1'b0});

            decode.eq = 1;
            decode.sel = ALU_COMP;

            decode.branch_cond = 1;
        end

        24: begin
            optype = "BNE";
            instr.ir = rv32_bne(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.op3 = instr.pc;
            decode.op4 = signed'({imm[12:1], 1'b0});

            decode.eq = 1;
            decode.inv = 1;
            decode.sel = ALU_COMP;

            decode.branch_cond = 1;
        end

        25: begin
            optype = "BLT";
            instr.ir = rv32_blt(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.op3 = instr.pc;
            decode.op4 = signed'({imm[12:1], 1'b0});

            decode.cin = 1;
            decode.sel = ALU_COMP;

            decode.branch_cond = 1;
        end

        26: begin
            optype = "BGE";
            instr.ir = rv32_bge(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.op3 = instr.pc;
            decode.op4 = signed'({imm[12:1], 1'b0});

            decode.cin = 1;
            decode.inv = 1;
            decode.sel = ALU_COMP;

            decode.branch_cond = 1;
        end

        27: begin
            optype = "BLTU";
            instr.ir = rv32_bltu(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.op3 = instr.pc;
            decode.op4 = signed'({imm[12:1], 1'b0});

            decode.cin = 1;
            decode.uns = 1;
            decode.sel = ALU_COMP;

            decode.branch_cond = 1;
        end

        28: begin
            optype = "BGEU";
            instr.ir = rv32_bgeu(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = REG[rs2];
            decode.op3 = instr.pc;
            decode.op4 = signed'({imm[12:1], 1'b0});

            decode.cin = 1;
            decode.inv = 1;
            decode.uns = 1;
            decode.sel = ALU_COMP;

            decode.branch_cond = 1;
        end

        29: begin
            optype = "LB";
            instr.ir = rv32_lb(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);

            decode.rd = rd;
            decode.ld = 1;

            write_back = 1;
        end

        30: begin
            optype = "LH";
            instr.ir = rv32_lh(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);

            decode.rd = rd;
            decode.ld = 1;

            write_back = 1;
        end

        31: begin
            optype = "LW";
            instr.ir = rv32_lw(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);

            decode.rd = rd;
            decode.ld = 1;

            write_back = 1;
        end

        32: begin
            optype = "LBU";
            instr.ir = rv32_lbu(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);

            decode.rd = rd;
            decode.ld = 1;

            write_back = 1;
        end

        33: begin
            optype = "LHU";
            instr.ir = rv32_lhu(rd, rs1, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);

            decode.rd = rd;
            decode.ld = 1;

            write_back = 1;
        end

        34: begin
            optype = "SB";
            instr.ir = rv32_sb(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.op3 = 0;
            decode.op4 = REG[rs2];

            decode.st = 1;
        end

        35: begin
            optype = "SH";
            instr.ir = rv32_sh(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.op3 = 0;
            decode.op4 = REG[rs2];

            decode.st = 1;
        end

        36: begin
            optype = "SW";
            instr.ir = rv32_sw(rs1, rs2, imm);

            decode.op1 = REG[rs1];
            decode.op2 = signed'(imm[11:0]);
            decode.op3 = 0;
            decode.op4 = REG[rs2];

            decode.st = 1;
        end

        37: begin
            optype = "FENCEI";
            instr.ir = rv32_fencei();

            decode.op3 = instr.pc;
            decode.op4 = 4;

            decode.branch = 1;
        end

        38: begin
            optype = "CSRRW";
            instr.ir = rv32_csrrw(rd, rs1, csr);

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = REG[rs1];
            decode.op4 = 0;

            decode.rd = rd;
            decode.csr = 1;

            write_back = 1;
        end

        39: begin
            optype = "CSRRS";
            instr.ir = rv32_csrrs(rd, rs1, csr);

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = REG[rs1];
            decode.op4 = 0;

            decode.rd = rd;
            decode.csr = 1;

            write_back = 1;
        end

        40: begin
            optype = "CSRRC";
            instr.ir = rv32_csrrc(rd, rs1, csr);

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = REG[rs1];
            decode.op4 = 0;

            decode.rd = rd;
            decode.csr = 1;

            write_back = 1;
        end

        41: begin
            optype = "CSRRWI";
            instr.ir = rv32_csrrwi(rd, zimm, csr);

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = zimm;
            decode.op4 = 0;

            decode.rd = rd;
            decode.csr = 1;

            write_back = 1;
        end

        42: begin
            optype = "CSRRSI";
            instr.ir = rv32_csrrsi(rd, zimm, csr);

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = zimm;
            decode.op4 = 0;

            decode.rd = rd;
            decode.csr = 1;

            write_back = 1;
        end

        43: begin
            optype = "CSRRCI";
            instr.ir = rv32_csrrci(rd, zimm, csr);

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = zimm;
            decode.op4 = 0;

            decode.rd = rd;
            decode.csr = 1;

            write_back = 1;
        end

        44: begin
            optype = "ECALL";
            instr.ir = rv32_ecall();

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = 0;
            decode.op4 = 0;

            decode.ecall = 1;
        end


        45: begin
            optype = "EBREAK";
            instr.ir = rv32_ebreak();

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = 0;
            decode.op4 = 0;

            decode.ebreak = 1;
        end

        46: begin
            optype = "MRET";
            instr.ir = rv32_mret();

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = 0;
            decode.op4 = 0;

            decode.ret = 1;
        end

        47: begin
            optype = "WFI";
            instr.ir = rv32_wfi();

            decode.op1 = 0;
            decode.op2 = instr.ir;
            decode.op3 = 0;
            decode.op4 = 0;

            decode.wfi = 1;
        end
    endcase // instr

    // default as-is decode - IR segments
    decode.rd = instr.ir[11:7];
    decode.funct3 = instr.ir[14:12];

    write_back = decode.rd != 0;
endtask

endmodule