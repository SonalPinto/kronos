// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Stage-0 Decoder
  - Houses the Integer Registers.
  - Decodes 32b Immediate and Register Operands for the main Decode stage.
  - Operates in parallel to the Fetch stage, such that when the fetch is valid, 
  so are the outputs of this block. 
*/

module kronos_ID0 
  import kronos_types::*;
(
  input  logic        clk,
  input  logic        load,
  // Fetch
  input  logic [31:0] instr_data,
  // Decode
  output logic [31:0] immediate,
  output logic [31:0] regrd_rs1,
  output logic [31:0] regrd_rs2,
  output logic        regrd_rs1_en,
  output logic        regrd_rs2_en,
  // Write back
  input  logic [31:0] regwr_data,
  input  logic [4:0]  regwr_sel,
  input  logic        regwr_en
);

logic [31:0] IR;
logic [4:0] OP;
logic [4:0] rs1, rs2;
logic [2:0] funct3;

// Immediate Operand segments
// A: [0]
// B: [4:1]
// C: [10:5]
// D: [11]
// E: [19:12]
// F: [31:20]
logic           ImmA;
logic [3:0]     ImmB;
logic [5:0]     ImmC;
logic           ImmD;
logic [7:0]     ImmE;
logic [11:0]    ImmF;

logic sign;
logic format_I;
logic format_J;
logic format_S;
logic format_B;
logic format_U;

logic csr_regrd;

// ============================================================
// Instruction Decoder

assign IR = instr_data;

// Aliases to IR segments
assign OP = IR[6:2];
assign rs1 = IR[19:15];
assign rs2 = IR[24:20];
assign funct3 = IR[14:12];

// ============================================================
// Immediate Decoder

assign sign = IR[31];

always_comb begin
  // Instruction format --- used to decode Immediate 
  format_I = OP == INSTR_OPIMM || OP == INSTR_JALR || OP == INSTR_LOAD;
  format_J = OP == INSTR_JAL;
  format_S = OP == INSTR_STORE;
  format_B = OP == INSTR_BR;
  format_U = OP == INSTR_LUI || OP == INSTR_AUIPC;

  // Immediate Segment A - [0]
  if (format_I) ImmA = IR[20];
  else if (format_S) ImmA = IR[7];
  else ImmA = 1'b0; // B/J/U
  
  // Immediate Segment B - [4:1]
  if (format_U) ImmB = 4'b0;
  else if (format_I || format_J) ImmB = IR[24:21];
  else ImmB = IR[11:8]; // S/B

  // Immediate Segment C - [10:5]
  if (format_U) ImmC = 6'b0;
  else ImmC = IR[30:25];

  // Immediate Segment D - [11]
  if (format_U) ImmD = 1'b0;
  else if (format_B) ImmD = IR[7];
  else if (format_J) ImmD = IR[20];
  else ImmD = sign;

  // Immediate Segment E - [19:12]
  if (format_U || format_J) ImmE = IR[19:12];
  else ImmE = {8{sign}};
  
  // Immediate Segment F - [31:20]
  if (format_U) ImmF = IR[31:20];
  else ImmF = {12{sign}};
end

// As A-Team's Hannibal would say, "I love it when a plan comes together"
always_ff @(posedge clk) begin
  if (load) immediate <= {ImmF, ImmE, ImmD, ImmC, ImmB, ImmA};
end

// ============================================================
// Integer Registers

logic [31:0] REG [32] /* synthesis syn_ramstyle = "no_rw_check" */;

// REG read
always_ff @(posedge clk) begin
  if (load) begin
    regrd_rs1 <= (rs1 != 0) ? REG[rs1] : '0;
    regrd_rs2 <= (rs2 != 0) ? REG[rs2] : '0;
  end
end

// REG Write
always_ff @(posedge clk) begin
  if (regwr_en) REG[regwr_sel] <= regwr_data;
end

// ============================================================
// Hazard tracking

assign csr_regrd = OP == INSTR_SYS && (funct3 == 3'b001
                                    || funct3 == 3'b010
                                    || funct3 == 3'b011);

// RS1/RS2 register read conditions
always_ff @(posedge clk) begin
  if (load) begin
    regrd_rs1_en <= OP == INSTR_OPIMM 
                || OP == INSTR_OP 
                || OP == INSTR_JALR 
                || OP == INSTR_BR
                || OP == INSTR_LOAD
                || OP == INSTR_STORE
                || csr_regrd;

    regrd_rs2_en <= OP == INSTR_OP 
                || OP == INSTR_BR
                || OP == INSTR_STORE;
  end
end

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , IR[1:0]
};
`endif


endmodule
