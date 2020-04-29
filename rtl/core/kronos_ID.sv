// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RV32I Decoder
  - Arranges operands (OP1/OP2) and ALUOP for the alu in the EX stage.
  - Evaluates branch condition for branch instructions.
  - Generates branch target or memory access address.
  - Tracks hazards on register operands and stalls if necessary
*/

module kronos_ID
  import kronos_types::*;
#(
  parameter CATCH_ILLEGAL_INSTR = 1
)(
  input  logic        clk,
  input  logic        rstz,
  input  logic        flush,
  // IF/ID
  input  pipeIFID_t   fetch,
  input  logic [31:0] immediate,
  input  logic [31:0] regrd_rs1,
  input  logic [31:0] regrd_rs2,
  input  logic        regrd_rs1_en,
  input  logic        regrd_rs2_en,
  input  logic        fetch_vld,
  output logic        fetch_rdy,
  // ID/EX
  output pipeIDEX_t   decode,
  output logic        decode_vld,
  input  logic        decode_rdy,
  // REG Write
  input  logic [31:0] regwr_data,
  input  logic [4:0]  regwr_sel,
  input  logic        regwr_en
);

logic [31:0] IR, PC;
logic [4:0] OP;
logic [6:0] opcode;
logic [4:0] rs1, rs2, rd;
logic [2:0] funct3;
logic [6:0] funct7;

logic [31:0] op1, op2;
logic [3:0] aluop;
logic regwr_alu;
logic branch;

// Address generation
logic [31:0] addr, addr_raw, base, offset;
logic align;

// Register forwarding
logic rs1_forward, rs2_forward;
logic [31:0] rs1_data, rs2_data;

// Stall Condition
logic stall;

// ============================================================
// Instruction Decoder

assign IR = fetch.ir;
assign PC = fetch.pc;

// Aliases to IR segments
assign opcode = IR[6:0];
assign OP = opcode[6:2];
assign rs1 = IR[19:15];
assign rs2 = IR[24:20];
assign rd  = IR[11: 7];
assign funct3 = IR[14:12];
assign funct7 = IR[31:25];

// ============================================================
// Register Write
// Write the result of the ALU back into the Registers
assign regwr_alu = (rd != '0) && (OP == INSTR_LUI
                    || OP == INSTR_AUIPC
                    || OP == INSTR_JAL
                    || OP == INSTR_JALR
                    || OP == INSTR_OPIMM 
                    || OP == INSTR_OP);

// ============================================================
// Register Forwarding
assign rs1_forward = regwr_en & regwr_sel == rs1;
assign rs2_forward = regwr_en & regwr_sel == rs2;

assign rs1_data = rs1_forward ? regwr_data : regrd_rs1;
assign rs2_data = rs2_forward ? regwr_data : regrd_rs2;

// ============================================================
// Operation Decoder
always_comb begin
  // Default ALU Operation is ADD
  aluop = ADD;

  // Default ALU Operands
  op1 = PC;
  op2 = FOUR;

  // Default addressGen operands
  align = 1'b0;
  base = PC;
  offset = FOUR;

  /* verilator lint_off CASEINCOMPLETE */
  unique case(OP)
    INSTR_LUI: begin
      op1 = ZERO;
      op2 = immediate;
    end
    INSTR_AUIPC: begin
      op2 = immediate;
    end
    INSTR_JAL: begin
      op2 = FOUR;
      offset = immediate;
    end
    INSTR_JALR: begin
      op2 = FOUR;
      align = 1'b1;
      base = rs1_data;
      offset = immediate;
    end
    INSTR_BR: begin
      offset = immediate;
    end
    INSTR_OPIMM: begin
      if (funct3 == 3'b001 || funct3 == 3'b101) aluop = {funct7[5], funct3};
      else aluop = {1'b0, funct3};

      op1 = rs1_data;
      op2 = immediate;
    end
    INSTR_OP: begin
      aluop = {funct7[5], funct3};
      op1 = rs1_data;
      op2 = rs2_data;
    end
    default: begin
    end
  endcase // OP
  /* verilator lint_on CASEINCOMPLETE */
end

// ============================================================
// Address Generation Unit
// Straightforward 32b adder
always_comb begin
  addr_raw = base + offset;
  addr[31:1] = addr_raw[31:1];
  // blank the LSB for aligned add (JALR)
  addr[0] = ~align & addr_raw[0];
end

// ============================================================
// Branch Comparator
kronos_branch u_branch (
  .op    (funct3  ),
  .rs1   (rs1_data),
  .rs2   (rs2_data),
  .branch(branch  )
);

// ============================================================
// Hazard Control
kronos_hcu u_hcu (
  .clk         (clk         ),
  .rstz        (rstz        ),
  .flush       (flush       ),
  .instr       (IR          ),
  .regrd_rs1_en(regrd_rs1_en),
  .regrd_rs2_en(regrd_rs2_en),
  .fetch_vld   (fetch_vld   ),
  .fetch_rdy   (fetch_rdy   ),
  .regwr_sel   (regwr_sel   ),
  .regwr_en    (regwr_en    ),
  .stall       (stall       )
);

// ============================================================
// Instruction Decode Output
always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    decode_vld <= 1'b0;
  end
  else begin
    if (flush) begin
      decode_vld <= 1'b0;
    end
    else if(fetch_vld && fetch_rdy) begin

      decode_vld <= 1'b1;

      decode.pc <= PC;
      decode.ir <= IR;

      decode.aluop <= aluop;
      decode.regwr_alu <= regwr_alu;
      decode.op1 <= op1;
      decode.op2 <= op2;

      decode.addr <= addr;
      decode.jump <= OP == INSTR_JAL || OP == INSTR_JALR;
      decode.branch <= branch && OP == INSTR_BR;

    end
    else if (decode_vld && decode_rdy) begin
      decode_vld <= 1'b0;
    end
  end
end

assign fetch_rdy = (~decode_vld | decode_rdy) & ~stall;

endmodule
