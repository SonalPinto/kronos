// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos ALU

The ALU has two tracks, OP1/2 are consumed by the Primary Track
to produce RESULT1 and OP3/4 are consumed by the Secondary Track 
to produce RESULT2

Primary Track Functions
    ADD     : r[0] = op1 + op2
    SUB     : r[0] = op1 - op2
    AND     : r[1] = op1 & op2
    OR      : r[2] = op1 | op2
    XOR     : r[3] = op1 ^ op2
    LT      : r[4] = op1 < op2
    LTU     : r[4] = op1 <u op2
    GTE     : r[4] = op1 >= op2
    GTEU    : r[4] = op1 >=u op2
    EQ      : r[4] = op1 == op2
    NEQ     : r[4] = op1 != op2
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

Secondary Track Functions
    ADD         : s[0] = op1 + op2
    ADD_ALIGN   : s[0] = (op1 + op2) & ~1

ALU controls signals:
    cin         : Carry In for subtration, Negate OP2 for subtraction and comparision
    rev         : Reverse OP1 for shift-left
    uns         : Unsigned flag for unsigned comparision
    eq          : Equality check
    inv         : Invert comparator result
    align       : blank out the LSB of the secondary adder result
    sel         : select ALU output for RESULT1
                  one of ALU.{ADDder, AND, OR, XOR, COMParator, SHIFTer}
                  RESULT2 always takes the secondary ADDer result
*/

module kronos_alu
    import kronos_types::*;
(
    // Operands
    input  logic [31:0] op1,
    input  logic [31:0] op2,
    input  logic [31:0] op3,
    input  logic [31:0] op4,
    // Operators
    input logic         cin,
    input logic         rev,
    input logic         uns,
    input logic         eq,
    input logic         inv,
    input logic         align,
    input logic [2:0]   sel,
    // Outputs
    output logic [31:0] result1,
    output logic [31:0] result2
);


logic [31:0] r_adder, r_and, r_or, r_xor, r_shift, s_adder;

logic [31:0] adder_A, adder_B;
logic cout;

logic A_sign, B_sign, R_sign;
logic r_eq, r_lt, r_ltu, r_comp;

logic [31:0] data;
logic [4:0] shamt;
logic shift_in;
logic [31:0] p0, p1, p2, p3, p4;

logic [31:0] t;


// ============================================================
// Primary Track
// ============================================================

// ADDER
always_comb begin
    // OP2 can be negated for subtraction
    adder_A = op1;
    adder_B = (cin) ? ~op2 : op2;

    // Add Operation
    /* verilator lint_off WIDTH */
    {cout, r_adder} = {1'b0, adder_A} + {1'b0, adder_B} + cin;
    /* verilator lint_on WIDTH */
end

// LOGIC
always_comb begin
    r_and = op1 & op2;
    r_or  = op1 | op2;
    r_xor = op1 ^ op2;
end

// COMPARATOR
always_comb begin
    // Use adder to subtract operands: op1(A) - op2(B), 
    //  and obtain the sign of the result
    A_sign = op1[31];
    B_sign = op2[31];
    R_sign = r_adder[31];

    // Signed Less Than (LT)
    // Greater Than or Equal (GTE) comparision is inverse of the LT result
    // 
    // If the operands have the same sign, we use r_sign
    // The result is negative if op1<op2
    // Subtraction of two postive or two negative signed integers (2's complement)
    //  will _never_ overflow
    case({A_sign, B_sign})
        2'b00: r_lt = R_sign; // Check subtraction result
        2'b01: r_lt = 1'b0;   // op1 is positive, and op2 is negative
        2'b10: r_lt = 1'b1;   // op1 is negative, and op2 is positive
        2'b11: r_lt = R_sign; // Check subtraction result
    endcase

    // Unsigned Less Than (LTU)
    // Check the carry out on op1-op2
    r_ltu = ~cout;

    // Equality check
    r_eq = op1 == op2;

    // Aggregate comparator results as per ALUOP
    if (eq) r_comp = (inv) ? ~r_eq : r_eq;
    else if (uns) r_comp = (inv) ? ~r_ltu : r_ltu;
    else r_comp = (inv) ? ~r_lt : r_lt;
end

// BARREL SHIFTER
always_comb begin
    // Reverse data to the shifter for SHL operations
    data = rev ? {<<{op1}} : op1;
    shift_in = uns ? 1'b0: op1[31];
    shamt = op2[4:0];

    // The barrel shifter is formed by a 5-level fixed RIGHT-shifter
    // that pipes in the value of the last stage

    p0 = shamt[0] ? {    shift_in  , data[31:1]} : data;
    p1 = shamt[1] ? {{ 2{shift_in}}, p0[31:2]}   : p0;
    p2 = shamt[2] ? {{ 4{shift_in}}, p1[31:4]}   : p1;
    p3 = shamt[3] ? {{ 8{shift_in}}, p2[31:8]}   : p2;
    p4 = shamt[4] ? {{16{shift_in}}, p3[31:16]}  : p3;

    // Reverse last to get SHL result
    r_shift = rev ? {<<{p4}} : p4;
end


// ============================================================
// Secondary Track
// ============================================================

// ADDER
always_comb begin
    t = op3 + op4;
    s_adder[31:1] = t[31:1];
    // blank the LSB for aligned add
    s_adder[0] = ~align & t[0];
end


// ============================================================
// Result
// ============================================================

always_comb begin
    case(sel)
        ALU_AND     : result1 = r_and;
        ALU_OR      : result1 = r_or;
        ALU_XOR     : result1 = r_xor;
        ALU_COMP    : result1 = {31'b0, r_comp};
        ALU_SHIFT   : result1 = r_shift;
        default     : result1 = r_adder;
    endcase

    result2 = s_adder;
end

endmodule