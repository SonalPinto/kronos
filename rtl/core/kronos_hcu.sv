// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Hazard Control Unit

The HCU monitors for hazards at the ID/EX interface
in a look-ahead manner. When the decode pipe output 
is ready to latch a new decoded instruction, the 
hazard status is also latched based on history

The check signal is asserted the same time as the decode is 
about to be latched (handoff from the fetch stage)

Registering the hazard status reduces the critical path

*/


module kronos_hcu 
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    input  logic        check,
    input  logic        fwd_vld,
    // Decode inputs
    input  logic [4:0]  rd,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic        rd_write,
    input  logic        op1_regrd,
    input  logic        op2_regrd,
    input  logic        op3_regrd,
    input  logic        op4_regrd,
    // Execute Stage Hazard status
    output hazardEX_t   ex_hazard
);

logic is_pending;
logic is_op1_hzd, is_op2_hzd, is_op3_hzd, is_op4_hzd;

assign is_op1_hzd = op1_regrd && rs1 == rd;
assign is_op2_hzd = op2_regrd && rs2 == rd;
assign is_op3_hzd = op3_regrd && rs1 == rd;
assign is_op4_hzd = op4_regrd && rs2 == rd;

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        is_pending <= 1'b0;
        ex_hazard <= '0;
    end
    else if (check) begin
        // Keep track if some register requires a write
        is_pending <= rd_write;

        if (is_pending) begin
            // OP1/4 only take RS1 and OP2/3 only take RS2
            ex_hazard.op1_hazard <= is_op1_hzd;
            ex_hazard.op2_hazard <= is_op2_hzd;
            ex_hazard.op3_hazard <= is_op3_hzd;
            ex_hazard.op4_hazard <= is_op4_hzd;
            ex_hazard.op_hazard  <= |{is_op1_hzd, is_op2_hzd, is_op3_hzd, is_op4_hzd};
        end
    end
    else if (fwd_vld) begin
        is_pending <= 1'b0;
        ex_hazard <= '0;
    end
end

endmodule