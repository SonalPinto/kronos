// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

// RISC-V 32I Instruction Assembler

package rv32_assembler;

import kronos_types::*;

parameter logic [4:0] x0  = 5'd0;
parameter logic [4:0] x1  = 5'd1;
parameter logic [4:0] x2  = 5'd2;
parameter logic [4:0] x3  = 5'd3;
parameter logic [4:0] x4  = 5'd4;
parameter logic [4:0] x5  = 5'd5;
parameter logic [4:0] x6  = 5'd6;
parameter logic [4:0] x7  = 5'd7;
parameter logic [4:0] x8  = 5'd8;
parameter logic [4:0] x9  = 5'd9;
parameter logic [4:0] x10 = 5'd10;
parameter logic [4:0] x11 = 5'd11;
parameter logic [4:0] x12 = 5'd12;
parameter logic [4:0] x13 = 5'd13;
parameter logic [4:0] x14 = 5'd14;
parameter logic [4:0] x15 = 5'd15;
parameter logic [4:0] x16 = 5'd16;
parameter logic [4:0] x17 = 5'd17;
parameter logic [4:0] x18 = 5'd18;
parameter logic [4:0] x19 = 5'd19;
parameter logic [4:0] x20 = 5'd20;
parameter logic [4:0] x21 = 5'd21;
parameter logic [4:0] x22 = 5'd22;
parameter logic [4:0] x23 = 5'd23;
parameter logic [4:0] x24 = 5'd24;
parameter logic [4:0] x25 = 5'd25;
parameter logic [4:0] x26 = 5'd26;
parameter logic [4:0] x27 = 5'd27;
parameter logic [4:0] x28 = 5'd28;
parameter logic [4:0] x29 = 5'd29;
parameter logic [4:0] x30 = 5'd30;
parameter logic [4:0] x31 = 5'd31;

/* verilator lint_off UNUSED */

// ========================================================
// LUI
// ========================================================
function instr_t rv32_lui(logic [4:0] rd, logic [31:0] imm);
    return {imm[31:12], rd, 7'b01_101_11};
endfunction

// ========================================================
// AUIPC
// ========================================================
function instr_t rv32_auipc(logic [4:0] rd, logic [31:0] imm);
    return {imm[31:12], rd, 7'b00_101_11};
endfunction

// ========================================================
// JAL
// ========================================================
function instr_t rv32_jal(logic [4:0] rd, logic [31:0] imm);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b11_011_11};
endfunction

// ========================================================
// JALR
// ========================================================
function instr_t rv32_jalr(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b000, rd, 7'b11_001_11};
endfunction

// ========================================================
// BR
// ========================================================
function instr_t rv32_beq(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[12], imm[10:5], rs2, rs1, 3'b000, imm[4:1], imm[11], 7'b11_000_11};
endfunction

function instr_t rv32_bne(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[12], imm[10:5], rs2, rs1, 3'b001, imm[4:1], imm[11], 7'b11_000_11};
endfunction

function instr_t rv32_blt(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[12], imm[10:5], rs2, rs1, 3'b100, imm[4:1], imm[11], 7'b11_000_11};
endfunction

function instr_t rv32_bge(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[12], imm[10:5], rs2, rs1, 3'b101, imm[4:1], imm[11], 7'b11_000_11};
endfunction

function instr_t rv32_bltu(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[12], imm[10:5], rs2, rs1, 3'b110, imm[4:1], imm[11], 7'b11_000_11};
endfunction

function instr_t rv32_bgeu(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[12], imm[10:5], rs2, rs1, 3'b111, imm[4:1], imm[11], 7'b11_000_11};
endfunction

// ========================================================
// LOAD
// ========================================================
function instr_t rv32_lb(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b000, rd, 7'b00_000_11};
endfunction

function instr_t rv32_lh(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b001, rd, 7'b00_000_11};
endfunction

function instr_t rv32_lw(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b010, rd, 7'b00_000_11};
endfunction

function instr_t rv32_lbu(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b100, rd, 7'b00_000_11};
endfunction

function instr_t rv32_lhu(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b101, rd, 7'b00_000_11};
endfunction

// ========================================================
// STORE
// ========================================================
function instr_t rv32_sb(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[11:5], rs2, rs1, 3'b000, imm[4:0], 7'b01_000_11};
endfunction

function instr_t rv32_sh(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[11:5], rs2, rs1, 3'b001, imm[4:0], 7'b01_000_11};
endfunction

function instr_t rv32_sw(logic [4:0] rs1, rs2, logic [31:0] imm);
    return {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'b01_000_11};
endfunction

// ========================================================
// OPIMM
// ========================================================
function instr_t rv32_addi(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b000, rd, 7'b00_100_11};
endfunction

function instr_t rv32_slti(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b010, rd, 7'b00_100_11};
endfunction

function instr_t rv32_sltiu(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b011, rd, 7'b00_100_11};
endfunction

function instr_t rv32_xori(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b100, rd, 7'b00_100_11};
endfunction

function instr_t rv32_ori(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b110, rd, 7'b00_100_11};
endfunction

function instr_t rv32_andi(logic [4:0] rd, rs1, logic [31:0] imm);
    return {imm[11:0], rs1, 3'b111, rd, 7'b00_100_11};
endfunction

function instr_t rv32_slli(logic [4:0] rd, rs1, logic [31:0] imm);
    return {7'b0, imm[4:0], rs1, 3'b001, rd, 7'b00_100_11};
endfunction

function instr_t rv32_srli(logic [4:0] rd, rs1, logic [31:0] imm);
    return {7'b0, imm[4:0], rs1, 3'b101, rd, 7'b00_100_11};
endfunction

function instr_t rv32_srai(logic [4:0] rd, rs1, logic [31:0] imm);
    return {7'b0100000, imm[4:0], rs1, 3'b101, rd, 7'b00_100_11};
endfunction

// ========================================================
// OP
// ========================================================
function instr_t rv32_add(logic [4:0] rd, rs1, rs2);
    return {7'b0, rs2, rs1, 3'b000, rd, 7'b01_100_11};
endfunction

function instr_t rv32_sub(logic [4:0] rd, rs1, rs2);
    return {7'b0100000, rs2, rs1, 3'b000, rd, 7'b01_100_11};
endfunction

function instr_t rv32_sll(logic [4:0] rd, rs1, rs2);
    return {7'b0000000, rs2, rs1, 3'b001, rd, 7'b01_100_11};
endfunction

function instr_t rv32_slt(logic [4:0] rd, rs1, rs2);
    return {7'b0000000, rs2, rs1, 3'b010, rd, 7'b01_100_11};
endfunction

function instr_t rv32_sltu(logic [4:0] rd, rs1, rs2);
    return {7'b0000000, rs2, rs1, 3'b011, rd, 7'b01_100_11};
endfunction

function instr_t rv32_xor(logic [4:0] rd, rs1, rs2);
    return {7'b0000000, rs2, rs1, 3'b100, rd, 7'b01_100_11};
endfunction

function instr_t rv32_srl(logic [4:0] rd, rs1, rs2);
    return {7'b0000000, rs2, rs1, 3'b101, rd, 7'b01_100_11};
endfunction

function instr_t rv32_sra(logic [4:0] rd, rs1, rs2);
    return {7'b0100000, rs2, rs1, 3'b101, rd, 7'b01_100_11};
endfunction

function instr_t rv32_or(logic [4:0] rd, rs1, rs2);
    return {7'b0000000, rs2, rs1, 3'b110, rd, 7'b01_100_11};
endfunction

function instr_t rv32_and(logic [4:0] rd, rs1, rs2);
    return {7'b0000000, rs2, rs1, 3'b111, rd, 7'b01_100_11};
endfunction

/* verilator lint_on UNUSED */
endpackage