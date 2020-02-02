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
    logic        rs1_read;
    logic        rs2_read;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic        neg;
    logic        rev;
    logic        cin;
    logic        uns;
    logic        gte;
    logic [2:0]  sel;
} pipeIDEX_t;

// Instruction Types: {opcode[6:2]}
parameter logic [4:0] type__OPIMM = 5'b00_100;
parameter logic [4:0] type__AUIPC = 5'b00_101;
parameter logic [4:0] type__OP    = 5'b01_100;
parameter logic [4:0] type__LUI   = 5'b01_101;

// ALU Result Select
parameter logic [2:0] ALU_ADDER = 3'd0;
parameter logic [2:0] ALU_AND   = 3'd1;
parameter logic [2:0] ALU_OR    = 3'd2;
parameter logic [2:0] ALU_XOR   = 3'd3;
parameter logic [2:0] ALU_COMP  = 3'd4;
parameter logic [2:0] ALU_SHIFT = 3'd5;

endpackage
