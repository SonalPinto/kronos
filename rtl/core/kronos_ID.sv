/*
    Copyright (c) 2020 Sonal Pinto <sonalpinto@gmail.com>

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

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

localparam logic [4:0] type__OPIMM = 5'b00_100;
localparam logic [4:0] type__AUIPC = 5'b00_101;
localparam logic [4:0] type__OP    = 5'b01_100;
localparam logic [4:0] type__LUI   = 5'b01_101;


logic [6:0] opcode;
logic [1:0] opcode_HIGH;
logic [2:0] opcode_LOW;
logic [4:0] opcode_type;
logic rs1, rs2;

logic [4:0] rs1_sel, rs2_sel;
logic rs1_required, rs2_required, read_rs2;
logic [31:0] regrd_data;

logic is_illegal_cond1;

enum logic [1:0] {
    IDLE,
    READRS1,
    READRS2
} state, next_state;


// ============================================================
/* 
Integer Registers
-----------------
Note: Since this ID module is geared towards FPGA, 
    Dual-Port Embedded Block Ram will be used to implement the 32x32 registers.
    Register (EBR) access takes a cycle. Hence, an instr requiring 
    both rs1 and rs2 would take 3 cycles to decode (cascading two reg access 
    and one output buffer write)

    In the iCE40UP5K this would take two EBR (each being 16x256)
*/

logic [31:0] REG [32];

// FIXME - see if timing will close for  negedge read clocking.
//  If so, then the decoder latency will be 1~2 cycles, instead of 
//  2~3

// REG read
always_ff @(posedge clk) begin
    if (state == IDLE && rs1_required) regrd_data <= REG[rs1];
    else if (state == READRS1 && read_rs2) regrd_data <= REG[rs2]; 
end

// REG Write
always_ff @(posedge clk) begin
    if (regwr_en) REG[regwr_sel] <= regwr_data; 
end


// ============================================================
// [rv32i] Instruction Decoder

// Aliases to IR segments
assign opcode = pipe_IFID.ir[6:2];
assign opcode_LOW = pipe_IFID.ir[4:2];
assign opcode_HIGH = pipe_IFID.ir[6:5];
assign opcode_type = {opcode_HIGH, opcode_LOW};

assign rs1 = pipe_IFID.ir[19:15];
assign rs2 = pipe_IFID.ir[24:20];

// Check if register read is required
// FIXME: Account for x0 !!
assign rs1_required = opcode_type == type__OPIMM || opcode_type == type__OP;
assign rs2_required = opcode_type == type__OP;

// Instruction is illegal if the LSB 2b of the opcode are not 2'b11
//  or the opcode is all ones or zeros
assign is_illegal_cond1 = (opcode[1:0] != 2'b11)
                    || (opcode == '0)
                    || (opcode == '1);


// ============================================================
// Instruction Decode Sequencer

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= IDLE;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: 
            if (pipe_in_vld && pipe_in_rdy) begin
                if(rs1_required) next_state = READRS1;
                else next_state = IDLE;
            end

        READRS1: 
            if (read_rs2) next_state = READRS2;
            else next_state = IDLE;

        READRS2:
            next_state = IDLE
    endcase // state
end

// buffer in rs2 requirement
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        read_rs2 <= 1'b0;
        rs2_sel <= '0;
    end
    else if (state == IDLE) begin
        read_rs2 <= rs2_required;
        rs2_sel <= rs2;
    end
end

// Output pipe (decoded instruction)
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_IDEX <= '0;
        pipe_out_vld <= 1'b0;
    end
    else begin
        case (state)
            IDLE: begin
                if (pipe_in_vld && pipe_in_rdy) begin
                    // aluop
                    // controls
                    pipe_IDEX.op1 <= pipe_IFID.pc; // | ZERO FIXME
                    // op2 <= imm | ZERO FIXME
                    if (rs1_required) pipe_out_vld <= 1'b0;
                    else pipe_out_vld <= 1'b1;
                end
                else if (pipe_out_vld && pipe_out_rdy) begin
                    pipe_out_vld <= 1'b0;
                end
            end
            
            READRS1: begin
                pipe_IDEX.op1 <= regrd_data;
                if (~read_rs2) pipe_out_vld <= 1'b1;
            end

            READRS2: begin
                pipe_IDEX.op2 <= regrd_data;
                pipe_out_vld <= 1'b1;
            end
        endcase
    end
end

// handoff can only happen in the IDLE state
assign pipe_in_rdy = (state == IDLE) && (~pipe_out_vld | pipe_out_rdy);

endmodule
