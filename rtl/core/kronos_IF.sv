// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0


// Simple Pipelined Instruction Fetch - Lite


module kronos_IF
    import kronos_types::*;
#(
    parameter PC_START = 32'h0
)(
    input  logic    clk,
    input  logic    rstz,
    // IMEM interface
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_data,
    output logic        instr_req,
    input  logic        instr_gnt,
    // IF/ID interface
    output pipeIFID_t   pipe_IFID,
    output logic        pipe_vld,
    input  logic        pipe_rdy,
    // BRANCH
    input logic [31:0]  branch_target,
    input logic         branch
);

logic [31:0] pc;
logic fetch_vld;

// ============================================================
// Program Counter (PC) Generation
//  & Instruction Fetch

// This is a simple two-cycle fetch,
//  as the memory data/gnt is valid a cycle after the request
//  The halved throughput compared to kronos_IF is acceptable
//  because the simple kronos_ID decode stage takes 2 cycles
//  as it uses block ram for the register file
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pc <= PC_START;
        pipe_IFID <= '0;
        fetch_vld <= '0;
    end
    else begin
        if (instr_gnt) begin
            pipe_IFID.pc <= instr_addr;
            pipe_IFID.ir <= instr_data;
            pc <= branch ? branch_target : (pc + 32'h4);
            fetch_vld <= 1'b1;
        end
        else if (fetch_vld && pipe_rdy) begin
            fetch_vld <= 1'b0;
        end
    end
end

// Memory Interface
assign instr_addr = pc;
assign instr_req = ~instr_gnt && (~fetch_vld | pipe_rdy);

// Next Stage pipe interface
assign pipe_vld = fetch_vld;

endmodule