# ALU Design

On a platform like the iCE40UP5K (not the speediest FPGA out there, but definitely one of the lowest power ones), the Execute stage is truly going to be the critical path. Those adder chains and comparison operations do not come cheap. In order to optimize the EX stage, I decided to move all of the control logic and operand selection to the Decode stage. As well as hazard checks. Those register forward muxes and hazard detections add to the critical path! Yes, this does come at the cost of one extra cycle for hazard resolution (the Decode stage has 2 stages ahead of it), but I decided it was worth it for some sweet **fmax**.

The study of the ISA detailed out the feature requirement of the ALU. Two tracks consuming 4 operands (`OP1-4`) and generating two results, `result1` and `result2`. The primary track being used for most instructions and thus, capable of most operations required.


## Primary Track

![Kronos ALU](_images/kronos_alu.svg)

ADD and SUB can be calculated with a simple 32b adder. `cin`, the adder carry-in inverts the operand for subtraction. The outputs of the adder are `R_ADD`, the 32b result, and `cout`, the carry-out (or overflow).

Signed less than is derived from the sign of the subtraction result and the operands, whereas the unsigned less than is simply the inverted `cout`. Equality comparison is straightforward. The `inv` flips the default comparison pairs: {LT,GTE}, (LTU, GTEU) and (EQ, NEQ). The final result of the comparator is R_COMP.

There's a 32b Right Barrel Shifter which can be used for SHR and SHRA. If you reverse (`rev`) the operand before and after the right barrel shifter, you can use if for left shifts (SHL). Arithmetic shift right, where the value shifted in is the sign of the operand, is selected by `uns`. The result is R_SHIFT.

Finally, the logical operations, AND, OR and XOR generate R_AND, R_OR and R_XOR. 


Primary track functions | Operation | cin | uns | eq | inv | rev | result
:----|----|----|----|----|----|----|----|
ADD  | result1 = op1 + op2          | 0 | 0 | 0 | 0 | 0 | R_ADD
SUB  | result1 = op1 - op2          | 1 | 0 | 0 | 0 | 0 | R_ADD
AND  | result1 = op1 & op2          | 0 | 0 | 0 | 0 | 0 | R_AND
OR   | result1 = op1 \| op2         | 0 | 0 | 0 | 0 | 0 | R_OR
XOR  | result1 = op1 ^ op2          | 0 | 0 | 0 | 0 | 0 | R_XOR
LT   | result1 = op1 < op2          | 1 | 0 | 0 | 0 | 0 | R_COMP
LTU  | result1 = op1 <u op2         | 1 | 1 | 0 | 0 | 0 | R_COMP
GTE  | result1 = op1 >= op2         | 1 | 0 | 0 | 0 | 1 | R_COMP
GTEU | result1 = op1 >=u op2        | 1 | 1 | 0 | 0 | 1 | R_COMP
EQ   | result1 = op1 == op2         | 0 | 0 | 0 | 1 | 0 | R_COMP
NEQ  | result1 = op1 != op2         | 0 | 0 | 0 | 1 | 1 | R_COMP
SHL  | result1 = op1 << op2[4:0]    | 0 | 1 | 0 | 0 | 1 | R_SHIFT
SHR  | result1 = op1 >> op2[4:0]    | 0 | 1 | 0 | 0 | 0 | R_SHIFT
SHRA | result1 = op1 >>> op2[4:0]   | 0 | 0 | 0 | 0 | 0 | R_SHIFT


The decoder generates the above minimal control signals (and there is no further decoding at the ALU at all!). The Primary track generates 5 result pathways, and the output mux deciding `result1` is set by the decoder.


## Secondary Track

The secondary track is 32b adder generating `result2` from `OP3` and `OP4`. When `align` is set, the LSB of the result is blanked.

![Kronos ALU](_images/kronos_alu2.svg)

Secondary track functions | Operation | align
:----|----|----
ADD  | result2 = op3 + op4 | 0
ADD_ALIGN  | result2 = (op3 + op4) & ~1 | 1