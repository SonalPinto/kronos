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
    ALU_OP      : ALU operation and controls
    CONTROLS    : Auxillary controls
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

// Instruction Types
localparam logic [4:0] type__OPIMM = 5'b00_100;
localparam logic [4:0] type__AUIPC = 5'b00_101;
localparam logic [4:0] type__OP    = 5'b01_100;
localparam logic [4:0] type__LUI   = 5'b01_101;


logic [6:0] opcode;
logic [1:0] opcode_HIGH;
logic [2:0] opcode_LOW;
logic [4:0] opcode_type;
logic [4:0] rs1, rs2;
logic [31:0] IR;
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

logic [31:0] regrd_rs1, regrd_rs2;
logic [31:0] immediate;

logic rs1_required, rs2_required;
logic is_illegal;

enum logic [1:0] {
    ID1,
    ID2
} state, next_state;


// ============================================================
// Integer Registers

// FIXME - Make the regfile a separate module
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

// REG read
always_ff @(posedge clk) begin
    if (state == ID1 && next_state == ID2) begin
        regrd_rs1 <= (rs1 != '0) ? REG1[rs1] : '0;
        regrd_rs2 <= (rs2 != '0) ? REG2[rs2] : '0;
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
// [rv32i] Instruction Decoder

// Aliases to IR segments
assign opcode = pipe_IFID.ir[6:0];
assign opcode_LOW = pipe_IFID.ir[4:2];
assign opcode_HIGH = pipe_IFID.ir[6:5];
assign opcode_type = {opcode_HIGH, opcode_LOW};

assign rs1 = pipe_IFID.ir[19:15];
assign rs2 = pipe_IFID.ir[24:20];

assign rs1_required = opcode_type == type__OPIMM || opcode_type == type__OP;
assign rs2_required = opcode_type == type__OP;

// Instruction is illegal if the opcode is all ones or zeros
assign is_illegal = (opcode == '0) || (opcode == '1);


// ============================================================
// Immediate Decoder

// FIXME - Put Imm Decode Table ASCII art here 

// The instruction from the Fetch stage is buffered into the OP2
// from which the sign-extened immediate needs to be derived
assign IR = pipe_IDEX.op2;
assign sign = pipe_IDEX.op2[31];

always_comb begin
    // I'm sure the synthesis tool could have handled all of this "optimization"
    // But, where's the fun in that.

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
assign immediate = {ImmF, ImmE, ImmD, ImmC, ImmB, ImmA};


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
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_IDEX <= '0;
        pipe_out_vld <= 1'b0;
        format_I <= 1'b0;
        format_J <= 1'b0;
        format_S <= 1'b0;
        format_B <= 1'b0;
        format_U <= 1'b0;
    end
    else begin
        if (state == ID1) begin
            if(pipe_in_vld && pipe_in_rdy) begin
                pipe_out_vld <= 1'b0;


                // format --------- // FIXME
                format_I <= opcode_type == type__OPIMM;
                format_J <= 1'b0;
                format_S <= 1'b0;
                format_B <= 1'b0;
                format_U <= opcode_type == type__LUI || opcode_type == type__AUIPC;

                // aluop ----------

                // controls -------
                pipe_IDEX.rs1_read <= rs1_required;
                pipe_IDEX.rs2_read <= rs2_required;

                pipe_IDEX.rs1 <= rs1;
                pipe_IDEX.rs2 <= rs2;

                // Buffer PC into OP1 and place the IR in OP2, temporarily
                // FIXME - if critical path, then place IR in a separate buffer
                pipe_IDEX.op1 <= pipe_IFID.pc;
                pipe_IDEX.op2 <= pipe_IFID.ir;
            end
            else if (pipe_out_vld && pipe_out_rdy) begin
                pipe_out_vld <= 1'b0;
            end
        end
        else if (state == ID2) begin
            pipe_out_vld <= 1'b1;

            // Conclude decoding OP1 and OP2, now that rs1/rs2 data is ready
            // and the sign-extended immediate is decoded
            if (pipe_IDEX.rs1_read) pipe_IDEX.op1 <= regrd_rs1;

            if (pipe_IDEX.rs2_read) pipe_IDEX.op2 <= regrd_rs2;
            else pipe_IDEX.op2 <= immediate;

        end
    end
end

// Pipethru can only happen in the ID1 state
assign pipe_in_rdy = (state == ID1) && (~pipe_out_vld | pipe_out_rdy);


// ------------------------------------------------------------
`ifdef verilator
logic _unused;
assign _unused = &{1'b0
    , IR[6:0] // the 7b opcode is the only segment that doesn't contribute to Immediate operand decoding!
};
`endif

endmodule
