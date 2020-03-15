// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RISC-V 32I Execution Unit

Pipestage with the Kronos ALU

*/


module kronos_EX
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    input  logic        flush,
    // IF/ID
    input  pipeIDEX_t   decode,
    input  logic        pipe_in_vld,
    output logic        pipe_in_rdy,
    // EX/WB
    output pipeEXWB_t   execute,
    output logic        pipe_out_vld,
    input  logic        pipe_out_rdy
);

logic [31:0] result1;
logic [31:0] result2;

// ============================================================
// ALU
kronos_alu u_alu (
    .op1    (decode.op1  ),
    .op2    (decode.op2  ),
    .op3    (decode.op3  ),
    .op4    (decode.op4  ),
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
    end
    else begin
        if (flush) begin
            pipe_out_vld <= 1'b0;
        end
        else if(pipe_in_vld && pipe_in_rdy) begin
            pipe_out_vld <= 1'b1;

            // Results
            execute.result1 <= result1;
            execute.result2 <= result2;

            // Forward WB controls
            execute.rd          <= decode.rd;
            execute.rd_write    <= decode.rd_write;
            execute.branch      <= decode.branch;
            execute.branch_cond <= decode.branch_cond;
            execute.ld          <= decode.ld;
            execute.st          <= decode.st;
            execute.data_size   <= decode.data_size;
            execute.data_uns    <= decode.data_uns;

            // Forward caught exceptions
            execute.is_illegal  <= decode.is_illegal;
        end
        else if (pipe_out_vld && pipe_out_rdy) begin
            pipe_out_vld <= 1'b0;
        end
    end
end

// Pipethru can only happen in the EX1 state
assign pipe_in_rdy = ~pipe_out_vld | pipe_out_rdy;

endmodule