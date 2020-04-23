// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Decoder
*/

module kronos_ID
  import kronos_types::*;
#(
  parameter CATCH_ILLEGAL_INSTR = 1,
  parameter USE_REGISTER_FORWARDING = 1 
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

logic is_reg_write;

logic [3:0] aluop;
logic regwr_alu;

// Hazard controls
logic stall;
logic [4:0] rpend;

// CSR register access
logic csr_regwr;


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

// Indicates a register will be written by this instructions
// regardless of source. This is useful for hazard tracking
assign is_reg_write = (rd != '0) && (OP == INSTR_LUI
                    || OP == INSTR_AUIPC
                    || OP == INSTR_JAL
                    || OP == INSTR_JALR
                    || OP == INSTR_OPIMM 
                    || OP == INSTR_OP
                    || OP == INSTR_LOAD
                    || csr_regwr);

assign csr_regwr = OP == INSTR_SYS && (funct3 == 3'b001
                    || funct3 == 3'b010
                    || funct3 == 3'b011
                    || funct3 == 3'b101
                    || funct3 == 3'b110
                    || funct3 == 3'b111);

// Write the result of the ALU back into the Registers
assign regwr_alu = (rd != '0) && (OP == INSTR_LUI
                    || OP == INSTR_AUIPC
                    || OP == INSTR_JAL
                    || OP == INSTR_JALR
                    || OP == INSTR_OPIMM 
                    || OP == INSTR_OP);


// ============================================================
// Execute Stage Operation Decoder

always_comb begin
  // Default ALU Operation is ADD
  aluop = ADD;

  /* verilator lint_off CASEINCOMPLETE */
  case(OP)
    // --------------------------------
    INSTR_OPIMM: begin
      if (funct3 == 3'b001 || funct3 == 3'b101) aluop = {funct7[5], funct3};
      else aluop = {1'b0, funct3};
    end
    INSTR_OP: begin
      aluop = {funct7[5], funct3};
    end
  endcase // OP
  /* verilator lint_on CASEINCOMPLETE */
end


// ============================================================
// Hazard Controls
assign rpend = '0;
assign stall = 1'b0;


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

      // ALU operands
      decode.op1 <= PC;
      decode.op2 <= FOUR;
      
      /* verilator lint_off CASEINCOMPLETE */
      case(OP)
        INSTR_LUI: begin
          decode.op1 <= ZERO;
          decode.op2 <= immediate;
        end
        INSTR_AUIPC: begin
          decode.op2 <= immediate;
        end
        INSTR_OPIMM: begin
          decode.op1 <= regrd_rs1;
          decode.op2 <= immediate;
        end
        INSTR_OP: begin
          decode.op1 <= regrd_rs1;
          decode.op2 <= regrd_rs2;
        end
      endcase // OP
    end
    /* verilator lint_on CASEINCOMPLETE */

    else if (decode_vld && decode_rdy) begin
      decode_vld <= 1'b0;
    end
  end
end

assign fetch_rdy = (~decode_vld | decode_rdy) && ~stall;

endmodule
