// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Hazard Control Unit

The HCU monitors for hazards at the ID/EX interface
in a look-ahead manner. When the decode pipe output is valid
and the execute is ready for a new decoded input, the 
hazard status is also latched based on history

The check signal is basically the handoff event between
the decode and execute stage

Registering the hazard status reduces the critical path

*/


module kronos_hcu 
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    input  logic        check,
    input  logic        fwd_vld,
    input  IDxHCU_t     id,
    output HCUxEX_t     ex
);

logic is_pending;
logic [4:0] rpend;

logic is_op1_hzd, is_op2_hzd, is_op3_hzd, is_op4_hzd;

assign is_op1_hzd = id.op1_regrd && id.rs1 == rpend;
assign is_op2_hzd = id.op2_regrd && id.rs2 == rpend;
assign is_op3_hzd = id.op3_regrd && id.rs2 == rpend;
assign is_op4_hzd = id.op4_regrd && id.rs1 == rpend;

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        ex.op_hazard <= 1'b0;
        is_pending <= 1'b0;
    end
    else if (check) begin
        // Keep track if some register requires a write
        is_pending <= id.rd_write;
        rpend <= id.rd;

        if (is_pending) begin
            // OP1/4 only take RS1 and OP2/3 only take RS2
            ex.op1_hazard <= is_op1_hzd;
            ex.op2_hazard <= is_op2_hzd;
            ex.op3_hazard <= is_op3_hzd;
            ex.op4_hazard <= is_op4_hzd;
            ex.op_hazard  <= |{is_op1_hzd, is_op2_hzd, is_op3_hzd, is_op4_hzd};
        end
    end
    else if (fwd_vld) begin
        is_pending <= 1'b0;
        ex.op_hazard  <= 1'b0;
    end
end

endmodule