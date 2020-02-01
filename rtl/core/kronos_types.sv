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
} pipeIDEX_t;

endpackage
