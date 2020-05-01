// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

package kronos_types;

// ============================================================
// Types
typedef logic [31:0] instr_t;

typedef struct packed {
    logic [31:0] pc;
    logic [31:0] ir;
} pipeIFID_t;

typedef struct packed {
    logic [31:0] pc;
    logic [31:0] ir;
    logic [31:0] op1;
    logic [31:0] op2;
    logic [31:0] addr;
    // ------------------------
    // EX controls
    logic [3:0]  aluop;
    logic        regwr_alu;
    logic        branch;
    logic        load;
    logic        store;
    logic [3:0]  mask;
    logic        misaligned;
} pipeIDEX_t;

// ============================================================
// Instruction Types: {opcode[6:2]}
parameter logic [4:0] INSTR_LOAD  = 5'b00_000;
parameter logic [4:0] INSTR_STORE = 5'b01_000;
parameter logic [4:0] INSTR_BR    = 5'b11_000;

parameter logic [4:0] INSTR_JALR  = 5'b11_001;

parameter logic [4:0] INSTR_MISC  = 5'b00_011;
parameter logic [4:0] INSTR_JAL   = 5'b11_011;

parameter logic [4:0] INSTR_OPIMM = 5'b00_100;
parameter logic [4:0] INSTR_OP    = 5'b01_100;
parameter logic [4:0] INSTR_SYS   = 5'b11_100;

parameter logic [4:0] INSTR_AUIPC = 5'b00_101;
parameter logic [4:0] INSTR_LUI   = 5'b01_101;

// ============================================================
// ALU Operations
parameter logic [3:0] ADD       = 4'b0000;
parameter logic [3:0] SUB       = 4'b1000;
parameter logic [3:0] SLT       = 4'b0010;
parameter logic [3:0] SLTU      = 4'b0011;
parameter logic [3:0] XOR       = 4'b0100;
parameter logic [3:0] OR        = 4'b0110;
parameter logic [3:0] AND       = 4'b0111;
parameter logic [3:0] SLL       = 4'b0001;
parameter logic [3:0] SRL       = 4'b0101;
parameter logic [3:0] SRA       = 4'b1101;

// ============================================================
// Branch Operations
parameter logic [2:0] BEQ       = 3'b000;
parameter logic [2:0] BNE       = 3'b001;
parameter logic [2:0] BLT       = 3'b100;
parameter logic [2:0] BGE       = 3'b101;
parameter logic [2:0] BLTU      = 3'b110;
parameter logic [2:0] BGEU      = 3'b111;

parameter logic [1:0] EQ        = 2'b00;
parameter logic [1:0] LT        = 2'b01;
parameter logic [1:0] GT        = 2'b10;

// ============================================================
// Memory Access Size
parameter logic [1:0] BYTE      = 2'b00;
parameter logic [1:0] HALF      = 2'b01;
parameter logic [1:0] WORD      = 2'b10;

// ============================================================
// Constants
parameter logic [31:0] ZERO   = 32'h0;
parameter logic [31:0] FOUR   = 32'h4;

// ============================================================
// Interrupts
parameter logic [3:0] SOFTWARE_INTERRUPT    = 4'd3;
parameter logic [3:0] TIMER_INTERRUPT       = 4'd7;
parameter logic [3:0] EXTERNAL_INTERRUPT    = 4'd11;

// ============================================================
// Exceptions
parameter logic [3:0] INSTR_ADDR_MISALIGNED = 4'd0;
parameter logic [3:0] ILLEGAL_INSTR         = 4'd2;
parameter logic [3:0] BREAKPOINT            = 4'd3;
parameter logic [3:0] LOAD_ADDR_MISALIGNED  = 4'd4;
parameter logic [3:0] STORE_ADDR_MISALIGNED = 4'd6;
parameter logic [3:0] ECALL_MACHINE         = 4'd11;

// ============================================================
// Control Status Register

// CSR operations
parameter logic [1:0]  CSR_RW       = 2'b01;
parameter logic [1:0]  CSR_RS       = 2'b10;
parameter logic [1:0]  CSR_RC       = 2'b11;

// CSR Address
parameter logic [11:0] MSTATUS      = 12'h300;
parameter logic [11:0] MIE          = 12'h304;
parameter logic [11:0] MTVEC        = 12'h305;

parameter logic [11:0] MSCRATCH     = 12'h340;
parameter logic [11:0] MEPC         = 12'h341;
parameter logic [11:0] MCAUSE       = 12'h342;
parameter logic [11:0] MTVAL        = 12'h343;
parameter logic [11:0] MIP          = 12'h344;

parameter logic [11:0] MCYCLE       = 12'hB00;
parameter logic [11:0] MINSTRET     = 12'hB02;
parameter logic [11:0] MCYCLEH      = 12'hB80;
parameter logic [11:0] MINSTRETH    = 12'hB82;

// Privilege levels
parameter logic [1:0] PRIVILEGE_MACHINE = 2'b11;
// mtvec modes
parameter logic [1:0] DIRECT_MODE   = 2'b00;
 
endpackage
