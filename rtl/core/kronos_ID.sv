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
logic [4:0] rs1, rs2;

logic [31:0] regrd_rs1, regrd_rs2;
logic [31:0] immediate;

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
        regrd_rs1 <= REG1[rs1];
        regrd_rs2 <= REG2[rs2];
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
assign opcode = pipe_IFID.ir[6:2];
assign opcode_LOW = pipe_IFID.ir[4:2];
assign opcode_HIGH = pipe_IFID.ir[6:5];
assign opcode_type = {opcode_HIGH, opcode_LOW};

assign rs1 = pipe_IFID.ir[19:15];
assign rs2 = pipe_IFID.ir[24:20];

// Instruction is illegal if the opcode is all ones or zeros
assign is_illegal = (opcode == '0) || (opcode == '1);


// ============================================================
// Immediate Decoder
assign immediate = '0;

// ============================================================
// Instruction Decode Sequencer

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= ID1;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    case (state)
        ID1: if (pipe_in_vld && pipe_in_rdy) next_state = ID2;
        ID2: next_state = ID1;
    endcase // state
end

// Output pipe (decoded instruction)
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_IDEX <= '0;
        pipe_out_vld <= 1'b0;
    end
    else begin
        if (state == ID1) begin
            if(pipe_in_vld && pipe_in_rdy) begin
                pipe_out_vld <= 1'b0;

                // aluop ----------

                // controls -------
                pipe_IDEX.rs1_read <= (rs1 != '0)
                        && (opcode_type == type__OPIMM || opcode_type == type__OP);

                pipe_IDEX.rs2_read <= (rs2 != '0)
                        && opcode_type == type__OP;

                pipe_IDEX.rs1 <= rs1;
                pipe_IDEX.rs2 <= rs2;

                // Buffer PC into OP1 temporarily, and clear out OP2
                pipe_IDEX.op1 <= (rs1 != '0) ? pipe_IFID.pc : '0;
                pipe_IDEX.op2 <= '0;
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
            pipe_IDEX.op2 <= (pipe_IDEX.rs2_read) ? regrd_rs2 : immediate;
        end
    end
end

// Pipethru can only happen in the ID1 state
assign pipe_in_rdy = (state == ID1) && (~pipe_out_vld | pipe_out_rdy);

endmodule
