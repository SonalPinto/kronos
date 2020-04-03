// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Instruction Fetch
*/

module kronos_IF
    import kronos_types::*;
#(
    parameter BOOT_ADDR = 32'h0
)(
    input  logic    clk,
    input  logic    rstz,
    // Instruction interface
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_data,
    output logic        instr_req,
    input  logic        instr_ack,
    // IF/ID interface
    output pipeIFID_t   fetch,
    output logic        pipe_out_vld,
    input  logic        pipe_out_rdy,
    // BRANCH
    input logic [31:0]  branch_target,
    input logic         branch
);

logic [31:0] pc;
logic fetch_rdy, fetch_vld;
logic fetch_success;

// ============================================================
// Program Counter (PC) Generation
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) pc <= BOOT_ADDR;
    else if (branch) pc <= branch_target;
    else if (fetch_success) pc <= (pc + 32'h4);
end

// Successful fetch if instruction is read and the pipeline can accept it
assign fetch_success = instr_req && instr_ack && fetch_rdy;

// ============================================================
//  Instruction Fetch

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        fetch_vld <= '0;
    end
    else begin
        if (branch) begin
            fetch_vld <= 1'b0;
        end
        else if (fetch_success) begin
            fetch.pc <= pc;
            fetch.ir <= instr_data;
            fetch_vld <= 1'b1;
        end
        else if (fetch_vld && pipe_out_rdy) begin
            fetch_vld <= 1'b0;
        end
    end
end

assign fetch_rdy = ~fetch_vld | pipe_out_rdy;

// Memory Interface
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz)  instr_req <= 1'b0;
    else instr_req <= fetch_rdy;
end

assign instr_addr = pc;

// Next Stage pipe interface
assign pipe_out_vld = fetch_vld;

endmodule
