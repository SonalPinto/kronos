// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Instruction Fetch
  - Instruction Skid Buffer to avoid re-fetch on stalls.
  - One Block Lookahead.
    * Attempt to fetch next instruction after setting up fetch for the current instr_addr
    * If instr_ack doesn't appear in one cycle, then seamlessly revert instr_addr.
  - Ideal Throughput.
  - Designed to work well with Synchronous Single-Port SRAM.
    * Synchronous SPSRAM is the most common form of FPGA memory.
    * If instr_req/addr is asserted in the current cycle, then the instr_ack/data may
      be leisurely driven valid next cycle. No need to clock the SPSRAM on the off-edge
      to get the ack on the same cycle as the req. You could if you wanted to, but not
      required.
  - Houses the Kronos Register File

FAST_BRANCH
  - Branch instructions take 2 cycles because the PC is set first. But, with FAST_BRANCH,
    the branch_target is forwarded for instruction fetch. Costs an extra adder, 
    but jumps are 1 cycle faster.
*/

module kronos_IF
  import kronos_types::*;
#(
  parameter logic [31:0] BOOT_ADDR = 32'h0,
  parameter FAST_BRANCH = 0
)(
  input  logic        clk,
  input  logic        rstz,
  // Instruction interface
  output logic [31:0] instr_addr,
  input  logic [31:0] instr_data,
  output logic        instr_req,
  input  logic        instr_ack,
  // IF/ID interface
  output pipeIFID_t   fetch,
  output logic [31:0] immediate,
  output logic [31:0] regrd_rs1,
  output logic [31:0] regrd_rs2,
  output logic        regrd_rs1_en,
  output logic        regrd_rs2_en,
  output logic        fetch_vld,
  input  logic        fetch_rdy,
  // BRANCH
  input logic [31:0]  branch_target,
  input logic         branch,
  // Write back
  input  logic [31:0] regwr_data,
  input  logic [4:0]  regwr_sel,
  input  logic        regwr_en
);

logic [31:0] pc, pc_last;
logic [31:0] skid_buffer;
logic pipe_rdy;
logic instr_vld;
logic [31:0] next_instr;

enum logic [1:0] {
  INIT,
  FETCH,
  MISS,
  STALL
} state, next_state;


// ============================================================
// Program Counter (PC) Generation
always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    pc <= BOOT_ADDR;
    pc_last <= '0;
  end
  else if (branch) begin
    if (FAST_BRANCH) begin
      pc <= branch_target + 32'h4;
      pc_last <= branch_target;
    end
    else begin
      pc <= branch_target;
    end
  end
  else if (next_state == FETCH) begin
    pc <= pc + 32'h4;
    pc_last <= pc;
  end
end


// ============================================================
// Instruction Fetch
always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) state <= INIT;
  else if (branch) state <= FAST_BRANCH ? FETCH : INIT;
  else state <= next_state;
end

always_comb begin
  next_state = state;
  /* verilator lint_off CASEINCOMPLETE */
  unique case (state)
    INIT: next_state = FETCH;

    FETCH:
      if (instr_ack) begin
        if (pipe_rdy) next_state = FETCH;
        else next_state = STALL;
      end
      else next_state = MISS;

    MISS: if (instr_ack) begin
      if (pipe_rdy) next_state = FETCH;
      else next_state = STALL;
    end

    STALL: if (fetch_rdy) next_state = FETCH;

  endcase // state
  /* verilator lint_on CASEINCOMPLETE */
end

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    fetch_vld <= '0;
  end
  else begin
    if (branch) begin
      fetch_vld <= 1'b0;
    end
    else if ((state == FETCH || state == MISS) && instr_ack) begin
      if (pipe_rdy) begin
        // Successful fetch if instruction is read and the pipeline can accept it
        fetch.pc <= pc_last;
        fetch.ir <= instr_data;
        fetch_vld <= 1'b1;
      end
      else begin
        // Instruction fetch is good, but pipeline is stalling, hence stow
        // fetched instruction in a skid buffer
        skid_buffer <= instr_data;
      end
    end
    else if (state == STALL && fetch_rdy) begin
      // Flush the skid buffer when the pipeline is ready
      fetch.pc <= pc_last;
      fetch.ir <= skid_buffer;
      fetch_vld <= 1'b1;
    end
    else if (fetch_vld && fetch_rdy) begin
      fetch_vld <= 1'b0;
    end
  end
end

assign pipe_rdy = ~fetch_vld || fetch_rdy;


// ============================================================
// Instruction Memory Interface

always_comb begin
  if (FAST_BRANCH & branch) instr_addr = branch_target;
  else instr_addr = ((state == FETCH || state == MISS) && ~instr_ack) ? pc_last : pc;
end
assign instr_req = 1'b1;

// ============================================================
// Register File

always_comb begin
  if ((state == FETCH || state == MISS) && instr_ack && pipe_rdy) begin
    instr_vld = 1'b1;
    next_instr = instr_data;
  end
  else if (state == STALL && fetch_rdy) begin
    instr_vld = 1'b1;
    next_instr = skid_buffer;
  end
  else begin
    instr_vld = 1'b0;
    next_instr = instr_data;
  end
end

kronos_RF u_rf (
  .clk         (clk         ),
  .rstz        (rstz        ),
  .instr_data  (next_instr  ),
  .instr_vld   (instr_vld   ),
  .fetch_rdy   (fetch_rdy   ),
  .immediate   (immediate   ),
  .regrd_rs1   (regrd_rs1   ),
  .regrd_rs2   (regrd_rs2   ),
  .regrd_rs1_en(regrd_rs1_en),
  .regrd_rs2_en(regrd_rs2_en),
  .regwr_data  (regwr_data  ),
  .regwr_sel   (regwr_sel   ),
  .regwr_en    (regwr_en    )
);

endmodule
