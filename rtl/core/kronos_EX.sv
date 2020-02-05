// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Two cycle ALU

Functions
    ADD     : r[0] = op1 + op2
    SUB     : r[0] = op1 - op2
    AND     : r[1] = op1 & op2
    OR      : r[2] = op1 | op2
    XOR     : r[3] = op1 ^ op2
    LT      : r[4] = (op1 < op2)  ? 32'b1 : 32'b0
    LTU     : r[4] = (op1 <u op2) ? 32'b1 : 32'b0
    GE      : r[4] = (op1 >= op2) ? 32'b1 : 32'b0
    SHL     : r[5] = op1 << op2[4:0]
    SHR     : r[5] = op1 >> op2[4:0]
    SHRA    : r[5] = op1 >>> op2[4:0]

Where r[0-5] are the intermediate results of these major functions
    0: ADDER
    1: AND
    2: OR
    3: XOR
    4: COMPARATOR
    5: BARREL SHIFTER
*/

// https://stackoverflow.com/questions/24586842/signed-multiplication-overflow-detection-in-verilog/24587824#24587824

module kronos_EX
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    // IF/ID interface
    input  pipeIDEX_t   decode,
    input  logic        pipe_in_vld,
    output logic        pipe_in_rdy,
    // EX/WB interface
    output pipeEXWB_t   execute,
    output logic        pipe_out_vld,
    input  logic        pipe_out_rdy
);

logic cout;
logic [31:0] r_adder;
logic [31:0] r_and, r_or, r_xor;
logic [31:0] r_shift;


// ============================================================
assign {cout, r_adder} = {1'b0, decode.op1} + {1'b0, decode.op2};

assign r_and = decode.op1 & decode.op2;

assign r_or = decode.op1 | decode.op2;

assign r_xor = decode.op1 ^ decode.op2;

assign r_shift = decode.op1 << decode.op2[4:0];

// ============================================================

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_out_vld <= '0;
    end
    else begin
        if (pipe_in_vld && pipe_in_rdy) begin
            pipe_out_vld <= 1'b1;

            case(decode.sel)
                ALU_ADDER: execute.result <= r_adder;
                ALU_AND  : execute.result <= r_and;
                ALU_OR   : execute.result <= r_or;
                ALU_XOR  : execute.result <= r_xor;
                // ALU_COMP : execute.result <= cout ? 32'b1 : 32'b0;
                // ALU_SHIFT: execute.result <= r_shift;
            endcase

        end
        else if (pipe_out_vld && pipe_out_rdy) begin
            pipe_out_vld <= 1'b0;
        end
    end
end

assign pipe_in_rdy = ~pipe_out_vld || pipe_out_rdy;


endmodule