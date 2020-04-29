// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Hazard Control Unit

Minimalist HCU to detect pending writes on an operand and assert a STALL
condition that halts the pipeline.
*/

module kronos_hcu 
  import kronos_types::*;
(
  input  logic        clk,
  input  logic        rstz,
  input  logic        flush,
  // Instruction
  input  logic [31:0] instr,
  input  logic        regrd_rs1_en,
  input  logic        regrd_rs2_en,
  input  logic        fetch_vld,
  input  logic        fetch_rdy,
  // REG Write
  input  logic [4:0]  regwr_sel,
  input  logic        regwr_en,
  // Stall
  output logic        stall
);

logic [4:0] OP;
logic [4:0] rs1, rs2, rd;
logic [2:0] funct3;

// Hazard controls
logic is_reg_write, csr_regwr;
logic regwr_pending;
logic rs1_hazard, rs2_hazard;
logic [4:0] rpend;

// ============================================================
// Hazard Tracking and Control

// Aliases to IR segments
assign OP = instr[6:2];
assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
assign rd  = instr[11: 7];
assign funct3 = instr[14:12];

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

// Hazard on register operands
assign rs1_hazard = regrd_rs1_en & regwr_pending & rpend == rs1;
assign rs2_hazard = regrd_rs2_en & regwr_pending & rpend == rs2;

// Stall condition if either operand has a hazard,
// and register write back isn't ready
assign stall = (rs1_hazard | rs2_hazard) & ~(regwr_en & rpend == regwr_sel);

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    regwr_pending <= 1'b0;
  end
  else begin
    if (flush) begin
      regwr_pending <= 1'b0;
    end
    else if(fetch_vld && fetch_rdy) begin
      regwr_pending <= is_reg_write;
      rpend <= rd;
    end
    else if(regwr_pending) begin
      regwr_pending <= ~(regwr_en & rpend == regwr_sel);
    end
  end
end

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , instr[1:0]
    , instr[31:25]
};
`endif

endmodule
