// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


/*
RISCV-32I Decoder
The 32b instruction and PC from the IF stage is decoded
into a generic form:

    RESULT1 = ALU( OP1, OP2 )
    RESULT2 = ADD( OP3, OP4 )
    WB_CONTROLS
    HAZARD_CHECK

where,
    OP1-4       : Operands, where OP1/2 are primary kronos_ALU operands,
                  and OP3/4 are secondary kronos_adder operands
                  Each operand can take one of many values as listed below,
                  OP1 <= PC, ZERO, REG[rs1]
                  OP2 <= IMM, FOUR, REG[rs2]
                  OP3 <= REG[rs2], PC
                  OP4 <= REG[rs1], IMM, ZERO
    EX_CTRL     : Execute stage controls
    WB_CTRL     : Write back stage controls which perform an action using
                  RESULT1/2
    RESULT1     : register write data
                  memory write addr
                  branch condition
    RESULT2     : memory address
                  branch target

EX_CTRL,
    neg         : Negate OP2 for subtraction and comparision
    rev         : Reverse OP1 for shift-left
    cin         : Carry In for subtration, comparision and arithmetic shift-right
    uns         : Unsigned flag for unsigned comparision
    eq          : Equality check
    inv         : Invert comparator result
    align       : blank out the LSB of the secondary adder result
    sel         : select ALU output for RESULT1
                  one of ALU.{ADDder, AND, OR, XOR, SHIFTer, COMParator}
                  RESULT2 always takes the secondary ADDer result

WB_CTRL,
    rd          : register write select
    rd_write    : register write enable
    branch      : unconditional branch
    branch_cond : conditional branch
    ld_size     : memory load size - byte, half-word or word
    ld_sign     : sign extend loaded data
    st          : store
    illegal     : illegal instruction

HAZARD CHECKS,
    rs1_read    : register rs1 was read
    rs2_read    : register rs2 was read
    rs1         : rs1 address
    rs2         : rs2 address


Note: The 4 operand requirement comes from the RISC-V's Branch instructions which perform
    if compare(rs1, rs2):
        pc <= pc + Imm

    Which consumes rs1, rs2, pc and Imm at the same time!
*/


module kronos_ID
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    // IF/ID interface
    input  pipeIFID_t   fetch,
    input  logic        pipe_in_vld,
    output logic        pipe_in_rdy,
    // ID/EX interface
    output pipeIDEX_t   decode,
    output logic        pipe_out_vld,
    input  logic        pipe_out_rdy,
    // REG Write
    input  logic [31:0] regwr_data,
    input  logic [4:0]  regwr_sel,
    input  logic        regwr_en
);

localparam logic [31:0] ZERO   = 32'h0;
localparam logic [31:0] FOUR   = 32'h4;

logic [31:0] IR;
logic [6:0] opcode;
logic [4:0] opcode_type;
logic [4:0] rs1, rs2, rd;
logic [2:0] funct3;
logic [6:0] funct7;

logic [31:0] tIR;
logic [4:0] tOP;

logic instr_valid;
logic illegal_opcode;

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

// Execute Stage controls
logic       neg;
logic       rev;
logic       cin;
logic       uns;
logic       eq;
logic       inv;
logic       align;
logic [2:0] sel;

enum logic [1:0] {
    ID1,
    ID2
} state, next_state;


// ============================================================
// [rv32i] Instruction Decoder

assign IR = fetch.ir;

// Aliases to IR segments
assign opcode = IR[6:0];
assign opcode_type = opcode[6:2];

assign rs1 = IR[19:15];
assign rs2 = IR[24:20];
assign rd  = IR[11: 7];

assign funct3 = IR[14:12];
assign funct7 = IR[31:25];

// opcode is illegal if LSB 2b are not 2'b11
assign illegal_opcode = opcode[1:0] != 2'b11;


// ============================================================
// Integer Registers

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

assign regrd_rs1_en = opcode_type == INSTR_OPIMM ||  opcode_type == INSTR_OP;
assign regrd_rs2_en = opcode_type == INSTR_OP;

assign regwr_rd_en = (rd != 0); // opcode != br|st|misc|system

// REG read
always_ff @(posedge clk) begin
    regrd_rs1 <= (regrd_rs1_en && rs1 != '0) ? REG1[rs1] : '0;
    regrd_rs2 <= (regrd_rs2_en && rs2 != '0) ? REG2[rs2] : '0;
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

// Intermediate buffer
always_ff @(posedge clk) begin
    // Instruction format --- used to decode Immediate 
    format_I <= opcode_type == INSTR_OPIMM;
    format_J <= 1'b0;
    format_S <= 1'b0;
    format_B <= 1'b0;
    format_U <= opcode_type == INSTR_LUI || opcode_type == INSTR_AUIPC;

    // Stow fetch for second cycle
    tIR <= fetch.ir;
end

assign tOP = tIR[6:2];
assign sign = tIR[31];

always_comb begin
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
// Execute Stage Operation Decoder

always_comb begin
    // Default ALU Operation: ADD 
    //  result1 <= ALU.adder
    //  result2 <= unaligned add
    neg     = 1'b0;
    rev     = 1'b0;
    cin     = 1'b0;
    uns     = 1'b0;
    eq      = 1'b0;
    inv     = 1'b0;
    align   = 1'b0;
    sel     = ALU_ADDER;
    instr_valid = 1'b0;

    // ALU Controls are decoded using {funct7, funct3, opcode_type}
    /* verilator lint_off CASEINCOMPLETE */

    // FIXME - Once this is complete, ONLY then optimize for 2 stage if critical path
    //  candidates: f7==0, f7==32, opcode_types(5b->3b)
    case(opcode_type)
    // --------------------------------
    INSTR_OPIMM: begin
        case(funct3)
            3'b000: begin // ADDI
                instr_valid = 1'b1;
            end
            3'b010: begin // SLTI
                neg = 1'b1;
                cin = 1'b1;
                sel = ALU_COMP;
                instr_valid = 1'b1;
            end

            3'b011: begin // SLTIU
                neg = 1'b1;
                cin = 1'b1;
                uns = 1'b1;
                sel = ALU_COMP;
                instr_valid = 1'b1;
            end

            3'b100: begin // XORI
                sel = ALU_XOR;
                instr_valid = 1'b1;
            end

            3'b110: begin // ORI
                sel = ALU_OR;
                instr_valid = 1'b1;
            end

            3'b111: begin // ANDI
                sel = ALU_AND;
                instr_valid = 1'b1;
            end

            3'b001: begin // SLLI
                if (funct7 == 7'd0) begin
                    rev = 1'b1;
                    uns = 1'b1;
                    sel = ALU_SHIFT;
                    instr_valid = 1'b1;
                end
            end

            3'b101: begin // SRLI/SRAI
                if (funct7 == 7'd0) begin
                    uns = 1'b1;
                    sel = ALU_SHIFT;
                    instr_valid = 1'b1;
                end
                else if (funct7 == 7'd32) begin
                    sel = ALU_SHIFT;
                    instr_valid = 1'b1;
                end
            end
        endcase // funct3
    end
    // --------------------------------
    INSTR_OP: begin
        case(funct3)
            3'b000: begin // ADD/SUB
                if (funct7 == 7'd0) begin
                    instr_valid = 1'b1;
                end
                else if (funct7 == 7'd32) begin
                    neg = 1'b1;
                    cin = 1'b1;
                    instr_valid = 1'b1;
                end
            end

            3'b001: begin // SLL
                if (funct7 == 7'd0) begin
                    rev = 1'b1;
                    uns = 1'b1;
                    sel = ALU_SHIFT;
                    instr_valid = 1'b1;
                end
            end

            3'b010: begin // SLT
                if (funct7 == 7'd0) begin
                    neg = 1'b1;
                    cin = 1'b1;
                    sel = ALU_COMP;
                    instr_valid = 1'b1;
                end
            end

            3'b011: begin // SLTU
                if (funct7 == 7'd0) begin
                    neg = 1'b1;
                    cin = 1'b1;
                    uns = 1'b1;
                    sel = ALU_COMP;
                    instr_valid = 1'b1;
                end
            end

            3'b100: begin // XOR
                if (funct7 == 7'd0) begin
                    sel = ALU_XOR;
                    instr_valid = 1'b1;
                end
            end

            3'b101: begin // SRL/SRA
                if (funct7 == 7'd0) begin
                    uns = 1'b1;
                    sel = ALU_SHIFT;
                    instr_valid = 1'b1;
                end
                else if (funct7 == 7'd32) begin
                    sel = ALU_SHIFT;
                    instr_valid = 1'b1;
                end
            end

            3'b110: begin // OR
                if (funct7 == 7'd0) begin
                    sel = ALU_OR;
                    instr_valid = 1'b1;
                end
            end

            3'b111: begin // AND
                if (funct7 == 7'd0) begin
                    sel = ALU_AND;
                    instr_valid = 1'b1;
                end
            end
        endcase // funct3
    end
    endcase // opcode_type
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

                // Hazard check
                decode.rs1_read <= regrd_rs1_en;
                decode.rs2_read <= regrd_rs2_en;
                decode.rs1      <= (regrd_rs1_en) ? rs1 : '0;
                decode.rs2      <= (regrd_rs2_en) ? rs2 : '0;

                // EX controls
                decode.neg   <= neg;
                decode.rev   <= rev;
                decode.cin   <= cin;
                decode.uns   <= uns;
                decode.eq    <= eq;
                decode.inv   <= inv;
                decode.align <= align;
                decode.sel   <= sel;
                
                // WB controls
                decode.rd_write     <= regwr_rd_en;
                decode.rd           <= (regwr_rd_en) ? rd : '0;
                decode.branch       <= 1'b0;
                decode.branch_cond  <= 1'b0;
                decode.ld_size      <= 2'b0;
                decode.ld_sign      <= 1'b0;
                decode.st           <= 1'b0;
                decode.illegal      <= ~(instr_valid) | illegal_opcode;

                // Temporarily store defaults in operands
                decode.op1 <= fetch.pc;
                decode.op2 <= FOUR;
                decode.op3 <= fetch.pc;
                decode.op4 <= ZERO;

            end
            else if (pipe_out_vld && pipe_out_rdy) begin
                pipe_out_vld <= 1'b0;
            end
        end
        else if (state == ID2) begin
            pipe_out_vld <= 1'b1;

            // Fill out OP1-4 as per opcode
            // now that rs1,rs2 and Immediate are ready
            /* verilator lint_off CASEINCOMPLETE */
            case(tOP)
                INSTR_LUI   : begin
                    decode.op1 <= ZERO;
                    decode.op2 <= immediate;
                end
                INSTR_AUIPC : begin
                    decode.op2 <= immediate;
                end
                INSTR_OPIMM : begin
                    decode.op1 <= regrd_rs1;
                    decode.op2 <= immediate;
                end
                INSTR_OP    : begin
                    decode.op1 <= regrd_rs1;
                    decode.op2 <= regrd_rs2;
                end
            endcase // tOP
            /* verilator lint_off CASEINCOMPLETE */
        end
    end
end

// Pipethru can only happen in the ID1 state
assign pipe_in_rdy = (state == ID1) && (~pipe_out_vld | pipe_out_rdy);


// ------------------------------------------------------------
`ifdef verilator
logic _unused;
assign _unused = &{1'b0
    , tIR[6:0]  // the opcode is the only part of the instruction that isn't used to decode the immediate!
};
`endif

endmodule
