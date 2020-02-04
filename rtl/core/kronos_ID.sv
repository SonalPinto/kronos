// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


/*
RISCV-32I Decoder
The 32b instruction and PC from the IF stage is decoded
into a generic form:

     DEST = ALU_OP( OP1, OP2 ), CONTROLS

where,
    DEST        : destination of the operation
    OP1, OP2    : ALU operands
    ALU_OP      : ALU controls
    CONTROLS    : Additional controls signals


ALU Controls (Check kronos_EX for details)
    neg         : Negate OP2 for subtraction and comparision
    rev         : Reverse OP1 for shift-left
    cin         : Carry In for subtration, comparision and arithmetic shift-right
    uns         : Unsigned flag for unsigned comparision
    gte         : Greater than Equal comparision (default is Less Than)
    sel         : Result Select - ADD, AND, OR, XOR, COMP or SHIFT

*/


module kronos_ID
    import kronos_types::*;
(
    input  logic    clk,
    input  logic    rstz,
    // IF/ID interface
    input  pipeIFID_t   pipe_IFID,
    input  logic        pipe_in_vld,
    output logic        pipe_in_rdy,
    // ID/EX interface
    output pipeIDEX_t   pipe_IDEX,
    output logic        pipe_out_vld,
    input  logic        pipe_out_rdy,
    // REG Write
    input  logic [31:0] regwr_data,
    input  logic [4:0]  regwr_sel,
    input  logic        regwr_en
);

localparam logic [31:0] zero   = 32'h0;



logic [31:0] IR, tIR;

logic [6:0] opcode;
logic [1:0] opcode_HIGH;
logic [2:0] opcode_LOW;
logic [4:0] opcode_type;
logic [4:0] rs1, rs2, rd;
logic [2:0] funct3;
logic [6:0] funct7;

logic regrd_rs1_en, regrd_rs2_en;
logic [31:0] regrd_rs1, regrd_rs2;

logic regwr_rd_en;

logic sign;
logic format_I;
logic format_J;
logic format_S;
logic format_B;
logic format_U;

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

logic [31:0] immediate;

// ALU controls
logic [5:0]  aluop;
logic        alu_neg;
logic        alu_rev;
logic        alu_cin;
logic        alu_uns;
logic        alu_gte;
logic [2:0]  alu_sel;

logic is_illegal1, is_illegal2;

enum logic [1:0] {
    ID1,
    ID2
} state, next_state;


// ============================================================
// [rv32i] Instruction Decoder

assign IR = pipe_IFID.ir;

// Aliases to IR segments
assign opcode = IR[6:0];
assign opcode_LOW = IR[4:2];
assign opcode_HIGH = IR[6:5];
assign opcode_type = {opcode_HIGH, opcode_LOW};

assign rs1 = IR[19:15];
assign rs2 = IR[24:20];
assign rd  = IR[11: 7];

assign funct3 = IR[14:12];
assign funct7 = IR[31:25];

// Instruction is illegal if the opcode is all ones or zeros
assign is_illegal1 = (opcode == '0) || (opcode == '1);
assign is_illegal2 = opcode[1:0] != 2'b11;


// ============================================================
// Integer Registers

// FIXME - Make the regfile a separate module ?
/*
Note: Since this ID module is geared towards FPGA, 
    Dual-Port Embedded Block Ram will be used to implement the 32x32 registers.
    Register (EBR) access takes a cycle. We need to read two registers on 
    the same cycle (or have the decode stage take an extra cycle, reading
    one register at a time).

    In the iCE40UP5K this would inefficiently take 4 EBR (each being 16x256)
*/

logic [31:0] REG1 [32];
logic [31:0] REG2 [32];

assign regrd_rs1_en = opcode_type == type__OPIMM ||  opcode_type == type__OP;
assign regrd_rs2_en = opcode_type == type__OP;

assign regwr_rd_en = 1'b1; // opcode != br|st|misc|system

// REG read
always_ff @(posedge clk) begin
    if (state == ID1 && next_state == ID2) begin
        regrd_rs1 <= (regrd_rs1_en && rs1 != '0) ? REG1[rs1] : '0;
        regrd_rs2 <= (regrd_rs2_en && rs2 != '0) ? REG2[rs2] : '0;
    end
end

// REG Write
always_ff @(posedge clk) begin
    if (regwr_en) begin
        REG1[regwr_sel] <= regwr_data;
        REG2[regwr_sel] <= regwr_data;
    end
end


// ============================================================
// Immediate Decoder

// FIXME - Put Imm Decode Table ASCII art here 
assign sign = tIR[31];

always_comb begin
    // FIXME - Refactor to case

    // Immediate Segment A - [0]
    if (format_I) ImmA = tIR[20];
    else if (format_S) ImmA = tIR[7];
    else ImmA = 1'b0; // B/J/U
    
    // Immediate Segment B - [4:1]
    if (format_U) ImmB = 4'b0;
    else if (format_I || format_J) ImmB = tIR[24:21];
    else ImmB = tIR[11:8]; // S/B

    // Immediate Segment C - [10:5]
    if (format_U) ImmC = 6'b0;
    else ImmC = tIR[30:25];

    // Immediate Segment D - [11]
    if (format_U) ImmD = 1'b0;
    else if (format_B) ImmD = tIR[7];
    else if (format_J) ImmD = tIR[20];
    else ImmD = sign;

    // Immediate Segment E - [19:12]
    if (format_U || format_J) ImmE = tIR[19:12];
    else ImmE = {8{sign}};
    
    // Immediate Segment F - [31:20]
    if (format_U) ImmF = tIR[31:20];
    else ImmF = {12{sign}};
end

// As A-Team's Hannibal would say, "I love it when a plan comes together"
assign immediate = {ImmF, ImmE, ImmD, ImmC, ImmB, ImmA};


// ============================================================
// ALU Operation Decoder

always_comb begin
    // Default ALU Operation: ADD, result from adder
    alu_neg = 1'b0;
    alu_rev = 1'b0;
    alu_cin = 1'b0;
    alu_uns = 1'b0;
    alu_gte = 1'b0;
    alu_sel = ALU_ADDER;

    // ALU Controls are decoded using {funct7[5], funct3, opcode_type--encoded}
    // FIXME - add illegal conditions for SHIFT ops
    /* verilator lint_off CASEINCOMPLETE */
    casez(aluop)
        // OPIMM = [00] ---------------
        6'b?_010_00: begin // SLTI
            alu_neg = 1'b1;
            alu_cin = 1'b1;
            alu_sel = ALU_COMP;
        end
        6'b?_011_00: begin // SLTIU
            alu_neg = 1'b1;
            alu_cin = 1'b1;
            alu_uns = 1'b1;
            alu_sel = ALU_COMP;
        end
        6'b?_100_00: begin // XORI
            alu_sel = ALU_XOR;
        end
        6'b?_110_00: begin // ORI
            alu_sel = ALU_OR;
        end
        6'b?_111_00: begin // ANDI
            alu_sel = ALU_AND;
        end
        6'b?_001_00: begin // SLLI
            alu_rev = 1'b1;
            alu_sel = ALU_SHIFT;
        end
        6'b0_101_00: begin // SRLI
            alu_sel = ALU_SHIFT;
        end
        6'b1_101_00: begin // SRAI
            alu_cin = 1'b1;
            alu_sel = ALU_SHIFT;
        end
        // OP = [01] ------------------
        6'b1_000_01: begin // SUB
            alu_neg = 1'b1;
            alu_cin = 1'b1;
        end
        6'b?_001_01: begin // SLL
            alu_rev = 1'b1;
            alu_sel = ALU_SHIFT;
        end
        6'b?_010_01: begin // SLT
            alu_neg = 1'b1;
            alu_cin = 1'b1;
            alu_sel = ALU_COMP;
        end
        6'b?_011_01: begin // SLTU
            alu_neg = 1'b1;
            alu_cin = 1'b1;
            alu_uns = 1'b1;
            alu_sel = ALU_COMP;
        end
        6'b?_100_01: begin // XOR
            alu_sel = ALU_XOR;
        end
        6'b0_101_01: begin // SRL
            alu_sel = ALU_SHIFT;
        end
        6'b1_101_01: begin // SRA
            alu_cin = 1'b1;
            alu_sel = ALU_SHIFT;
        end
        6'b?_110_01: begin // OR
            alu_sel = ALU_OR;
        end
        6'b?_111_01: begin // AND
            alu_sel = ALU_AND;
        end
    endcase //aluop
    /* verilator lint_on CASEINCOMPLETE */
end


// ============================================================
// Instruction Decode Sequencer

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= ID1;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        ID1: if (pipe_in_vld && pipe_in_rdy) next_state = ID2;
        ID2: next_state = ID1;
    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Intermediate buffer to reduce critical paths
always_ff @(posedge clk) begin
    // Instruction format --- used to decode Immediate 
    format_I <= opcode_type == type__OPIMM;
    format_J <= 1'b0;
    format_S <= 1'b0;
    format_B <= 1'b0;
    format_U <= opcode_type == type__LUI || opcode_type == type__AUIPC;

    tIR <= IR;

    aluop[2+:4] <= {funct7[5], funct3};

    // Opcode type -- used for ALU Operation decoder
    /* verilator lint_off CASEINCOMPLETE */
    case(opcode_type)
        type__OPIMM : aluop[1:0] <= 2'b00;
        type__OP    : aluop[1:0] <= 2'b01;
        default     : aluop[1:0] <= 2'b11;
    endcase
    /* verilator lint_on CASEINCOMPLETE */
end


// Output pipe (decoded instruction)
// Note: Some segments are registered on the first cycle, and some on the second cycle
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_out_vld <= 1'b0;
    end
    else begin
        if (state == ID1) begin
            if(pipe_in_vld && pipe_in_rdy) begin
                pipe_out_vld <= 1'b0;

                // controls -------
                pipe_IDEX.rs1_read <= regrd_rs1_en;
                pipe_IDEX.rs2_read <= regrd_rs2_en;

                pipe_IDEX.rs1 <= (regrd_rs1_en) ? rs1 : '0;
                pipe_IDEX.rs2 <= (regrd_rs2_en) ? rs2 : '0;

                pipe_IDEX.rd_write <= regwr_rd_en;
                pipe_IDEX.rd  <= (regwr_rd_en) ? rd : '0;


                // Buffer PC into OP1
                if (opcode_type == type__LUI) pipe_IDEX.op1 <= '0;
                else pipe_IDEX.op1 <= pipe_IFID.pc;

                pipe_IDEX.op2 <= '0;

            end
            else if (pipe_out_vld && pipe_out_rdy) begin
                pipe_out_vld <= 1'b0;
            end
        end
        else if (state == ID2) begin
            pipe_out_vld <= 1'b1;

            // aluop ----------
            pipe_IDEX.neg <= alu_neg;
            pipe_IDEX.rev <= alu_rev;
            pipe_IDEX.cin <= alu_cin;
            pipe_IDEX.uns <= alu_uns;
            pipe_IDEX.gte <= alu_gte;
            pipe_IDEX.sel <= alu_sel;

            // Conclude decoding OP1 and OP2, now that rs1/rs2 data is ready
            if (pipe_IDEX.rs1_read) pipe_IDEX.op1 <= regrd_rs1;

            if (pipe_IDEX.rs2_read) pipe_IDEX.op2 <= regrd_rs2;
            else pipe_IDEX.op2 <= immediate;
        end
    end
end

// Pipethru can only happen in the ID1 state
assign pipe_in_rdy = (state == ID1) && (~pipe_out_vld | pipe_out_rdy);


// // ------------------------------------------------------------
`ifdef verilator
logic _unused;
assign _unused = &{1'b0
    , tIR[6:0]  // the opcode is the only part of the instruction that isn't used to decode the immediate!
};
`endif

endmodule
