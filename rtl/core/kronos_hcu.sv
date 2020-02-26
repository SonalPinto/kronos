// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Hazard Control Unit

The HCU monitors for Register Read hazards at the Decode Stage
These hazards occur when a register is being read before it's
latest value is written back from the Write Back stage,
either as a result of a Direct Write or a Load

*/


module kronos_hcu 
    import kronos_types::*;
(
    input  logic        clk,
    input  logic        rstz,
    input  logic        flush,
    // Decoder inputs
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic        regrd_rs1_en,
    input  logic        regrd_rs2_en,
    input  logic        upgrade,
    // Write Back inputs
    input  logic [4:0]  regwr_sel,
    input  logic        downgrade,
    // Decoder Stall status
    output logic        stall
);

/*
Register Pending Tracker
------------------------
In the Kronos pipeline, there are 2 stages ahead of the Decoder.

Hence, there can be a maximum of two pending writes to any register.

This is tracked as 2b shift register which shifts in a '1' to track
that a write is pending, and shifts out when it is written back.

This is representative of upgrading or downgrading the hazard level
on that register.

The LSB of this 2b hazard vector indicates the hazard status.

Controls,
Upgrade     : decode is ready to register for the next stage, and regwr_rd_en is valid
Downgrade   : write back is valid, i.e. regwr_en

Note,
1. This HCU design scales really well. For deeper levels of 
pending write-backs (downgrades), the hazard vector needs to be widened.
However, the stall conditioned only checks the LSB.
This architecture can pretty much be used anywhere if the IO is generalized

2. There is no forwarding of register data. Register write data can only be 
forwarded if the hazard level is 1. This could easily be implemented here, 
but I didn't feel the resources (and delay on fetch_rdy thru stall) 
were worth it for Kronos.

*/

logic [31:0][1:0] rpend;

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        rpend <= '0;
    end
    else begin
        if (flush) begin
            rpend <= '0;
        end
        else if (upgrade && ~downgrade) begin
            // Decode ready. Upgrade register's hazard level
            rpend[rd] <= {rpend[rd][0], 1'b1};
        end
        else if (~upgrade && downgrade) begin
            // Register written back. Downgrade register's hazard level
            rpend[regwr_sel] <= {1'b0, rpend[regwr_sel][1]};
        end
        else if (upgrade && downgrade) begin
            // Hazard level remains the same if both decoder and write
            // back collide on the same register
            // Else, upgrade and downgrade specified registers
            if (rd != regwr_sel) begin
                rpend[rd] <= {rpend[rd][0], 1'b1};
                rpend[regwr_sel] <= {1'b0, rpend[regwr_sel][1]};
            end
        end
    end
end

// Stall if rs1 or rs2 is pending
assign stall = (regrd_rs1_en && rpend[rs1][0]) || (regrd_rs2_en && rpend[rs2][0]);

endmodule