// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RV32I Decoder
  - Arranges operands (OP1/OP2) and ALUOP for the alu in the EX stage.
  - Evaluates branch condition for branch instructions.
  - Generates branch target or memory access address.
  - Generates store data and mask.
  - Detects misaligned jumps and memory access
  - Tracks hazards on register operands and stalls if necessary.
*/

module kronos_ID
  import kronos_types::*;
#(
  parameter CATCH_ILLEGAL_INSTR = 1,
  parameter CATCH_MISALIGNED_JMP = 1,
  parameter CATCH_MISALIGNED_LDST = 1
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
logic [1:0] data_size;

logic [31:0] op1, op2;
logic [3:0] aluop;
logic regwr_alu;
logic branch;
logic csr;
logic [1:0] sysop;
logic is_fencei;

logic illegal;
logic instr_valid;
logic illegal_opcode;

// Address generation
logic [31:0] addr, base, offset;
logic misaligned_jmp;
logic misaligned_ldst;

// Memory Access
logic [3:0] mask;
logic [1:0] byte_addr;
logic [3:0][7:0] sdata, store_data;

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
assign data_size = funct3[1:0];

// opcode is illegal if LSB 2b are not 2'b11
assign illegal_opcode = opcode[1:0] != 2'b11;

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
assign rs1_forward = regwr_en & (regwr_sel == rs1);
assign rs2_forward = regwr_en & (regwr_sel == rs2);

assign rs1_data = rs1_forward ? regwr_data : regrd_rs1;
assign rs2_data = rs2_forward ? regwr_data : regrd_rs2;

// ============================================================
// Operation Decoder
always_comb begin
  instr_valid = 1'b0;
  is_fencei = 1'b0;
  sysop = 2'b0;
  csr = 1'b0;

  // Default ALU Operation is ADD
  aluop = ADD;

  // Default ALU Operands
  op1 = PC;
  op2 = FOUR;

  // Default addressGen operands
  base = PC;
  offset = FOUR;

  // Memory Access
  byte_addr = addr[1:0];

  // Memory access
  sdata = rs2_data;

  // setup write data
  // Barrel Rotate Left store_data bytes as per offset
  case(byte_addr)
    2'b00: store_data = sdata;
    2'b01: store_data = {sdata[2:0], sdata[3]};
    2'b10: store_data = {sdata[1:0], sdata[3:2]};
    2'b11: store_data = {sdata[0]  , sdata[3:1]};
  endcase

  if (OP == INSTR_STORE) begin
    if (data_size == BYTE) mask = 4'h1 << byte_addr;
    else if (data_size == HALF) mask = byte_addr[1] ? 4'hC : 4'h3;
    else mask = 4'hF;
  end
  else begin
    mask = 4'hF;
  end

  /* verilator lint_off CASEINCOMPLETE */
  unique case(OP)
    // --------------------------------
    INSTR_LUI: begin
      op1 = ZERO;
      op2 = immediate;
      instr_valid = 1'b1;
    end
    // --------------------------------
    INSTR_AUIPC: begin
      op2 = immediate;
      instr_valid = 1'b1;
    end
    // --------------------------------
    INSTR_JAL: begin
      op2 = FOUR;
      offset = immediate;
      instr_valid = 1'b1;
    end
    // --------------------------------
    INSTR_JALR: begin
      op2 = FOUR;
      base = rs1_data;
      offset = immediate;
      instr_valid = funct3 == 3'b000;
    end
    // --------------------------------
    INSTR_BR: begin
      offset = immediate;

      case(funct3)
        BEQ,
        BNE,
        BLT,
        BGE,
        BLTU,
        BGEU:
          instr_valid  = 1'b1;
      endcase // funct3
    end
    // --------------------------------
    INSTR_LOAD: begin
      base = rs1_data;
      offset = immediate;

      case(funct3)
        3'b000, // LB
        3'b001, // LH
        3'b010, // LW
        3'b100, // LBU
        3'b101: // LHU 
          instr_valid = 1'b1;
      endcase // funct3
    end
    // --------------------------------
    INSTR_STORE: begin
      op2 = store_data;
      base = rs1_data;
      offset = immediate;

      case(funct3)
        3'b000, // SB
        3'b001, // SH
        3'b010: // SW
          instr_valid = 1'b1;
      endcase // funct3
    end
    // --------------------------------
    INSTR_OPIMM: begin
      if (funct3 == 3'b001 || funct3 == 3'b101) aluop = {funct7[5], funct3};
      else aluop = {1'b0, funct3};

      op1 = rs1_data;
      op2 = immediate;

      case(funct3)
        3'b000, // ADDI
        3'b010, // SLTI
        3'b011, // SLTIU
        3'b100, // XORI
        3'b110, // ORI
        3'b111: // ANDI
          instr_valid = 1'b1;
        3'b001: begin // SLLI
          if (funct7 == 7'd0) instr_valid = 1'b1;
        end
        3'b101: begin // SRLI/SRAI
          if (funct7 == 7'd0) instr_valid = 1'b1;
          else if (funct7 == 7'd32) instr_valid = 1'b1;
        end
      endcase // funct3
    end
    // --------------------------------
    INSTR_OP: begin
      aluop = {funct7[5], funct3};
      op1 = rs1_data;
      op2 = rs2_data;

      case(funct3)
        3'b000: begin // ADD/SUB
          if (funct7 == 7'd0) instr_valid = 1'b1;
          else if (funct7 == 7'd32) instr_valid = 1'b1;
        end
        3'b001: begin // SLL
          if (funct7 == 7'd0) instr_valid = 1'b1;
        end
        3'b010: begin // SLT
          if (funct7 == 7'd0) instr_valid = 1'b1;
        end
        3'b011: begin // SLTU
          if (funct7 == 7'd0) instr_valid = 1'b1;
        end
        3'b100: begin // XOR
          if (funct7 == 7'd0) instr_valid = 1'b1;
        end
        3'b101: begin // SRL/SRA
          if (funct7 == 7'd0) instr_valid = 1'b1;
          else if (funct7 == 7'd32) instr_valid = 1'b1;
        end
        3'b110: begin // OR
          if (funct7 == 7'd0) instr_valid = 1'b1;
        end
        3'b111: begin // AND
          if (funct7 == 7'd0) instr_valid = 1'b1;
        end
      endcase // funct3
    end
    // --------------------------------
    INSTR_MISC: begin
      case(funct3)
        3'b000: begin // FENCE
          // This is a NOP
          instr_valid = 1'b1;
        end
        3'b001: begin // FENCE.I
          if (IR[31:20] == 12'b0 && rs1 == '0 && rd =='0) begin
            // implementing fence.i as `j f1` (jump to pc+4) 
            // as this will flush the pipeline and cause a fresh 
            // fetch of the instructions after the fence.i instruction
            is_fencei = 1'b1;
            instr_valid = 1'b1;
          end
        end
      endcase // funct3
    end
    // --------------------------------
    INSTR_SYS: begin
      unique case(funct3)
        3'b000: begin
          if (rs1 == '0 && rd =='0) begin
            if (IR[31:20] == 12'h000) begin // ECALL
              sysop = ECALL;
              instr_valid = 1'b1;
            end
            else if (IR[31:20] == 12'h001) begin // EBREAK
              sysop = EBREAK;
              instr_valid = 1'b1;
            end
            else if (IR[31:20] == 12'h302) begin // MRET
              sysop = MRET;
              instr_valid = 1'b1;
            end
            else if (IR[31:20] == 12'h105) begin // WFI
              sysop = WFI;
              instr_valid = 1'b1;
            end
          end
        end
        3'b001,       // CSRRW
        3'b010,       // CSRRS
        3'b011: begin // CSRRC
          op1 = rs1_data;
          csr = 1'b1;
          instr_valid = 1'b1;
        end
        3'b101,       // CSRRWI
        3'b110,       // CSRRSI
        3'b111: begin // CSRRCI
          csr = 1'b1;
          instr_valid = 1'b1;
        end
      endcase // funct3
    end
    // --------------------------------
    default: begin
    end
  endcase // OP
  /* verilator lint_on CASEINCOMPLETE */
end

// Consolidate factors that deem an instruction as illegal
assign illegal = CATCH_ILLEGAL_INSTR ? (~instr_valid | illegal_opcode) : 1'b0;

// ============================================================
// Address Generation Unit
kronos_agu #(
  .CATCH_MISALIGNED_JMP (CATCH_MISALIGNED_JMP),
  .CATCH_MISALIGNED_LDST(CATCH_MISALIGNED_LDST)
) u_agu (
  .instr          (IR             ),
  .base           (base           ),
  .offset         (offset         ),
  .addr           (addr           ),
  .misaligned_jmp (misaligned_jmp ),
  .misaligned_ldst(misaligned_ldst)
);

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

      decode.basic <= OP == INSTR_LUI
                    || OP == INSTR_AUIPC
                    || OP == INSTR_OPIMM
                    || OP == INSTR_OP
                    || OP == INSTR_BR
                    || OP == INSTR_JAL
                    || OP == INSTR_JALR
                    || OP == INSTR_MISC;

      decode.aluop <= aluop;
      decode.regwr_alu <= regwr_alu;
      decode.op1 <= op1;
      decode.op2 <= op2;

      decode.addr <= addr;
      decode.jump <= OP == INSTR_JAL || OP == INSTR_JALR || is_fencei;
      decode.branch <= branch && OP == INSTR_BR;
      decode.load <= OP == INSTR_LOAD; 
      decode.store <= OP == INSTR_STORE;
      decode.mask  <= mask;

      decode.csr <= csr;
      decode.system <= OP == INSTR_SYS && ~csr;
      decode.sysop <= sysop;

      decode.illegal <= illegal;
      decode.misaligned_jmp <= misaligned_jmp;
      decode.misaligned_ldst <= misaligned_ldst;

    end
    else if (decode_vld && decode_rdy) begin
      decode_vld <= 1'b0;
    end
  end
end

assign fetch_rdy = (~decode_vld | decode_rdy) & ~stall;

endmodule
