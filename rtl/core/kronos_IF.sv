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
//  High Throughput, One Block Lookahead fetch
//
// FIXME: Critical paths on memory access - use skid buffers

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

logic [31:0] pc, pc_last;
logic update_pc;
logic fetch_rdy, fetch_vld;

enum logic [1:0] {
    INIT,
    FETCH,
    STALL
} state, next_state;


// ============================================================
// Program Counter (PC) Generation
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pc <= PC_START;
        pc_last <= '0;
    end
    else begin
        if (update_pc) begin
            pc <= branch ? branch_target : (pc + 32'h4);
            pc_last <= pc;
        end
    end
end

assign update_pc = next_state == FETCH;

// ============================================================
//  Instruction Fetch

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) state <= INIT;
    else state <= next_state;
end

always_comb begin
    next_state = state;
    case (state)
        INIT: next_state = FETCH;

        FETCH:
            if (instr_gnt && fetch_rdy) next_state = FETCH;
            else next_state = STALL;

        STALL:
            if (instr_gnt && fetch_rdy) next_state = FETCH;

    endcase // state
end

// FIXME - Swap this out to a skid buffer
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        pipe_IFID <= '0;
        fetch_vld <= '0;
    end
    else begin
        if (instr_gnt && fetch_rdy) begin
            pipe_IFID.pc <= pc_last;
            pipe_IFID.ir <= instr_data;
            fetch_vld <= 1'b1;
        end
        else if (fetch_vld && pipe_rdy) begin
            fetch_vld <= 1'b0;
        end
    end
end

assign fetch_rdy = ~fetch_vld | pipe_rdy;

// Memory Interface
assign instr_addr = (next_state != FETCH) ? pc_last : pc;
assign instr_req = fetch_rdy;

// Next Stage pipe interface
assign pipe_vld = fetch_vld;

endmodule