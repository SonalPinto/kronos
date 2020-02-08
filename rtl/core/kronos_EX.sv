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
    GEU     : r[4] = (op1 >=u op2) ? 32'b1 : 32'b0
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

ALU controls signals:
    neg         : Negate OP2 for subtraction and comparision
    rev         : Reverse OP1 for shift-left
    cin         : Carry In for subtration, comparision and arithmetic shift-right
    uns         : Unsigned flag for unsigned comparision
    eq          : Equality check
    inv         : Invert flag for comparision result inversion

*/


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
    input  logic        pipe_out_rdy,
    // Register Forwarding
    input  logic [31:0] fwd_data,
    input  logic        fwd_vld
);


logic is_pending;
logic [4:0] rpend;
logic rs1_hazard, rs2_hazard;
logic [31:0] op1, op2;

logic [31:0] adder_A, adder_B;
logic [15:0] adder_RL;
logic [15:0] adder_RH0, adder_RH1, adder_RH;
logic cout_RL, cout_RH0, cout_RH1;
logic cout;
logic [31:0] r_adder;

logic [2:0] result_select;

logic [31:0] r_and, r_or, r_xor;
logic [31:0] r_logic;

logic a_sign, b_sign, r_sign;
logic check_unsigned, check_equality, invert_result;
logic lt, ltu;
logic eqH, eqL, eq;
logic r_comp;

enum logic [1:0] {
    EX1,
    EX2
} state, next_state;


// ============================================================
// Hazard Check

// Hazard check for register operands
assign rs1_hazard = (is_pending && decode.rs1_read && decode.rs1 == rpend);
assign rs2_hazard = (is_pending && decode.rs2_read && decode.rs2 == rpend);

// If there's a hazard, then pick the forwarded register (from the WriteBack stage)
// instead of the stale rs1 from the Decode stage
assign op1 = (rs1_hazard) ? fwd_data : decode.op1;
assign op2 = (rs2_hazard) ? fwd_data : decode.op2;


// ============================================================
// ADDER
// 2 Stage 32b Carry Select Adder, 16b per stage
// Hence, the critical is drastically reduced

// OP2 can be negated for subtraction
assign adder_A = op1;
assign adder_B = (decode.neg) ? ~op2 : op2;

always_ff @(posedge clk) begin
    /* verilator lint_off WIDTH */
    // Lower Adder Result
    {cout_RL, adder_RL} <= {1'b0, adder_A[0+:16]} + {1'b0, adder_B[0+:16]} + decode.cin;
    // Two possible Higher Addder Result, based on the carry
    //      of the lower half
    {cout_RH0, adder_RH0} <= {1'b0, adder_A[16+:16]} + {1'b0, adder_B[16+:16]} + 1'b0;
    {cout_RH1, adder_RH1} <= {1'b0, adder_A[16+:16]} + {1'b0, adder_B[16+:16]} + 1'b1;
    /* verilator lint_on WIDTH */
end

// Form full adder result and carry out
assign adder_RH = (cout_RL) ? adder_RH1 : adder_RH0;
assign cout     = (cout_RL) ? cout_RH1  : cout_RH0;
assign r_adder  = {adder_RH, adder_RL};


// ============================================================
// LOGIC
assign r_and    = op1 & op2;
assign r_or     = op1 | op2;
assign r_xor    = op1 ^ op2;

always_ff @(posedge clk) begin
    // Select the logic result, and stow it for stage 2
    /* verilator lint_off CASEINCOMPLETE */
    case (decode.sel)
        ALU_AND : r_logic <= r_and;
        ALU_OR  : r_logic <= r_or;
        ALU_XOR : r_logic <= r_xor;
    endcase
    /* verilator lint_on CASEINCOMPLETE */
end


// ============================================================
// COMPARATOR

always_ff @(posedge clk) begin
    // Stow operand signs for second cycle, when the adder result is ready
    a_sign <= op1[31];
    b_sign <= op2[31];

    // ALUOP controls needed for the Comparator ops in the second cyle
    check_unsigned  <= decode.uns;
    check_equality  <= decode.eq;
    invert_result   <= decode.inv;

    // Pipelined equality check
    eqL <= op1[0+:16]   == op2[0+:16];
    eqH <= op1[16+:16]  == op2[16+:16];
end

always_comb begin
    // Use adder to subtract operands: op1(A) - op2(B), 
    //  and obtain the sign of the result
    r_sign = r_adder[31];

    // Signed Less Than (LT)
    // Greater Than or Equal (GTE) comparision is inverse of the LT result
    // 
    // If the operands have the same sign, we use r_sign
    // The result is negative if op1<op2
    // Subtraction of two postive or two negative signed integers (2's complement)
    //  will _never_ overflow
    case({a_sign, b_sign})
        2'b00: lt = r_sign; // Check subtraction result
        2'b01: lt = 1'b0;   // op1 is positive, and op2 is negative
        2'b10: lt = 1'b1;   // op1 is negative, and op2 is positive
        2'b11: lt = r_sign; // Check subtraction result
    endcase

    // Unsigned Less Than (LTU)
    // Check the carry out on op1-op2
    ltu = ~cout;

    // Equality check
    eq = eqL & eqH;

    // Aggregate comparator results as per ALUOP
    if (check_equality) r_comp = (invert_result) ? ~eq : eq;
    else if (check_unsigned) r_comp = (invert_result) ? ~ltu : ltu;
    else r_comp = (invert_result) ? ~lt : lt;
end


// ============================================================
// Execute Sequencer

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= EX1;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    /* verilator lint_off CASEINCOMPLETE */
    case (state)
        EX1: if (pipe_in_vld && pipe_in_rdy) next_state = EX2;
        EX2: next_state = EX1;
    endcase // state
    /* verilator lint_on CASEINCOMPLETE */
end

// Intermediate buffer
always_ff @(posedge clk) begin
    result_select <= decode.sel;
end

// Output pipe (Execute Results)
// Note: Some segments are registered on the first cycle, and some on the second cycle
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_out_vld <= 1'b0;
        is_pending <= 1'b0;
        rpend <= '0;
    end
    else begin
        if (state == EX1) begin
            if(pipe_in_vld && pipe_in_rdy) begin
                pipe_out_vld <= 1'b0;

                // Forward decoded controls
                execute.rd <= decode.rd;
                execute.rd_write <= decode.rd_write;
                execute.illegal <= decode.illegal;

                // Keep track if some register requires a write
                is_pending <= 1'b0; // decode.rd_write;
                rpend <= decode.rd;

            end
            else if (pipe_out_vld && pipe_out_rdy) begin
                pipe_out_vld <= 1'b0;
            end
        end
        else if (state == EX2) begin
            // Results from various operations are ready now
            // Result1 is Register Write Data
            /* verilator lint_off CASEINCOMPLETE */
            case(result_select)
                ALU_ADDER   : execute.result1 <= r_adder;

                ALU_AND,
                ALU_OR,
                ALU_XOR     : execute.result1 <= r_logic;

                ALU_COMP    : execute.result1 <= {31'b0, r_comp};
            endcase
            /* verilator lint_on CASEINCOMPLETE */

            execute.result2 <= '0;

            // Result2 is Branch Target or Memory Write Data
            pipe_out_vld <= 1'b1;
        end
    end
end

// Pipethru can only happen in the EX1 state
assign pipe_in_rdy = (state == EX1) && (~pipe_out_vld | pipe_out_rdy);


endmodule