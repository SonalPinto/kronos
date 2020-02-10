// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


package kronos_types;


typedef struct packed {
    logic [31:0] pc;
    logic [31:0] ir;
} pipeIFID_t;


typedef struct packed {
    logic [31:0] op1;
    logic [31:0] op2;
    logic [31:0] op3;
    logic [31:0] op4;
    // ------------------------
    // Hazard checks
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic        op1_regrd;
    logic        op2_regrd;
    logic        op3_regrd;
    logic        op4_regrd;
    // ------------------------
    // EX controls
    logic        cin;
    logic        rev;
    logic        uns;
    logic        eq;
    logic        inv;
    logic        align;
    logic [2:0]  sel;
    // ------------------------
    // WB controls
    logic [4:0]  rd;
    logic        rd_write;
    logic        branch;
    logic        branch_cond;
    logic [1:0]  ld_size;
    logic        ld_sign;
    logic        st;
    logic        illegal;
} pipeIDEX_t;


typedef struct packed {
    logic [31:0] result1;
    logic [31:0] result2;
    // ------------------------
    // WB controls
    logic [4:0]  rd;
    logic        rd_write;
    logic        branch;
    logic        branch_cond;
    logic [1:0]  ld_size;
    logic        ld_sign;
    logic        st;
    logic        illegal;
} pipeEXWB_t;


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
// ALU Result Select
parameter logic [2:0] ALU_ADDER = 3'd0;
parameter logic [2:0] ALU_AND   = 3'd1;
parameter logic [2:0] ALU_OR    = 3'd2;
parameter logic [2:0] ALU_XOR   = 3'd3;
parameter logic [2:0] ALU_COMP  = 3'd4;
parameter logic [2:0] ALU_SHIFT = 3'd5;

endpackage
