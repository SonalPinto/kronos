/*
   Copyright (c) 2020 Sonal Pinto <sonalpinto@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

// Simple Pipelined Instruction Fetch

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

// This is a two-cycle fetch, as the memory data/gnt is valid a cycle after the request
// Fancier techniques could have been employed 
//  say, addr skid buffers, where the fetch loop fetches every cycle and the addr is updated
//  and reverted upon miss/stall
//  as done in kronos_IF2
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