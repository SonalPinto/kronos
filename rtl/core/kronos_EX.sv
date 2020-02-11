// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RISC-V 32I Execution Unit

Hazard control checks for write-back hazards and forwards clean 
operands to the Kronos ALU to get two 32b results

HAZARD CHECKS,
    rs1         : rs1 address
    rs2         : rs2 address
    op#_regrd   : op# is a register operand
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


logic is_pending, stall;
logic [4:0] rpend;
logic op1_hazard, op2_hazard, op3_hazard, op4_hazard;

logic [31:0] op1, op2, op3, op4;
logic [31:0] result1;
logic [31:0] result2;

// ============================================================
// Hazard Check

// Hazard check for register operands
// OP1/4 only take RS1 and OP2/3 only take RS2
assign op1_hazard = is_pending && decode.op1_regrd && decode.rs1 == rpend;
assign op2_hazard = is_pending && decode.op2_regrd && decode.rs2 == rpend;
assign op3_hazard = is_pending && decode.op3_regrd && decode.rs2 == rpend;
assign op4_hazard = is_pending && decode.op4_regrd && decode.rs1 == rpend;

// If there's a hazard, then pick the forwarded register (from the WriteBack stage)
// instead of the stale rs1/rs2 from the Decode stage
assign op1 = (op1_hazard) ? fwd_data : decode.op1;
assign op2 = (op2_hazard) ? fwd_data : decode.op2;
assign op3 = (op3_hazard) ? fwd_data : decode.op3;
assign op4 = (op4_hazard) ? fwd_data : decode.op4;


// ============================================================
// ALU
kronos_alu u_alu (
    .op1    (op1         ),
    .op2    (op2         ),
    .op3    (op3         ),
    .op4    (op4         ),
    .cin    (decode.cin  ),
    .rev    (decode.rev  ),
    .uns    (decode.uns  ),
    .eq     (decode.eq   ),
    .inv    (decode.inv  ),
    .align  (decode.align),
    .sel    (decode.sel  ),
    .result1(result1     ),
    .result2(result2     )
);


// ============================================================
// Execute Output Stage (calculated results)

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_out_vld <= 1'b0;
        is_pending <= 1'b0;
        rpend <= '0;
    end
    else begin
        if(pipe_in_vld && pipe_in_rdy) begin
            pipe_out_vld <= 1'b1;

            // Forwar WB controls
            execute.rd          <= decode.rd;
            execute.rd_write    <= decode.rd_write;
            execute.branch      <= decode.branch;
            execute.branch_cond <= decode.branch_cond;
            execute.ld_size     <= decode.ld_size;
            execute.ld_sign     <= decode.ld_sign;
            execute.st          <= decode.st;
            execute.illegal     <= decode.illegal;

            // Keep track if some register requires a write
            is_pending <= decode.rd_write;
            rpend <= decode.rd;

            // Results
            execute.result1 <= result1;
            execute.result2 <= result2;

        end
        else if (pipe_out_vld && pipe_out_rdy) begin
            pipe_out_vld <= 1'b0;
        end
    end
end

// Stall if there is a hazard, and the forward hasn't arrived
assign stall = |{op1_hazard, op2_hazard, op3_hazard, op4_hazard} & ~fwd_vld;

// Pipethru can only happen in the EX1 state
assign pipe_in_rdy = (~pipe_out_vld | pipe_out_rdy) && ~stall;

endmodule