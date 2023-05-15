// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos RISC-V Machine-Level CSRs v1.11

This is a partial implementation with the following CSRs:
- Machine Trap Setup
  * mstatus: mie, mpie, mpp
  * mie: msie, mtie, meie
  * mtvec
- Machine Trap Handling
  * mscratch
  * mepc
  * mcause
  * mtval
  * mip
- Machine Hardware Performance Counters
  * mcycle/mcycleh
  * minstret/minstreth

mtvec takes only Direct mode (mtvec.mode = 2'b00) for trap handler jumps

The module also acts as an interruptor funneling the various interrupt source
spec'd in the privileged machine-level architecture. Namely, External, Timer 
and Software interrupts
*/

module kronos_csr
  import kronos_types::*;
#(
  parameter logic [31:0]  BOOT_ADDR = 32'h0,
  parameter EN_COUNTERS = 1,
  parameter EN_COUNTERS64B = 1
)(
  input  logic        clk,
  input  logic        rstz,
  // CSR
  input  pipeIDEX_t   decode,
  input  logic        csr_vld,
  output logic        csr_rdy,
  output logic [31:0] csr_data,
  output logic        regwr_csr,
  // Trackers
  input  logic        instret,
  // trap handling
  input  logic        activate_trap,
  input  logic        return_trap,
  input  logic [31:0] trap_cause,
  input  logic [31:0] trap_value,
  output logic [31:0] trap_handle,
  output logic        trap_jump,
  // interrupts
  input  logic        software_interrupt,
  input  logic        timer_interrupt,
  input  logic        external_interrupt,
  output logic        core_interrupt,
  output logic [3:0]  core_interrupt_cause
);

logic [2:0] funct3;
logic [11:0] addr;
logic [4:0] zimm, rd;
logic [31:0] wr_data;

logic [31:0] csr_rd_data, csr_wr_data;
logic csr_rd_vld, csr_wr_vld;
logic csr_rd_en, csr_wr_en;

struct packed {
  logic [1:0] mpp;
  logic mpie;
  logic mie;
} mstatus;

struct packed {
  logic meie;
  logic mtie;
  logic msie;
} mie;

struct packed {
  logic meip;
  logic mtip;
  logic msip;
} mip;

struct packed {
  logic [29:0] base;
  logic [1:0] mode;
} mtvec;

logic [31:0] mscratch, mepc, mcause, mtval;

logic mcycle_wrenl, mcycle_wrenh;
logic mcycle_rd_vld;
logic [63:0] mcycle;

logic minstret_wrenl, minstret_wrenh;
logic minstret_rd_vld;
logic [63:0] minstret;

enum logic [1:0] {
  IDLE,
  READ,
  WRITE
} state, next_state;

// ============================================================
// Extract decoded segments

// IR segments
assign addr = decode.ir[31-:12];
assign funct3 = decode.ir[14:12];
assign rd = decode.ir[11:7];
assign zimm = decode.ir[19:15];

// CSR Write data - either zero-extended 5b immediate or REG[rs1]
assign wr_data = funct3[2] ? {27'b0, zimm} : decode.op1;

// ============================================================
// CSR Sequencer
assign csr_rdy = state == WRITE;

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) state <= IDLE;
  else state <= next_state;
end

always_comb begin
  next_state = state;
  /* verilator lint_off CASEINCOMPLETE */
  unique case (state)
    // Atomic Read/Modify/Write
    IDLE: if (csr_vld && decode.csr) next_state = READ;
    READ: if (csr_rd_vld) next_state = WRITE;
    WRITE: next_state = IDLE;
  endcase // state
  /* verilator lint_on CASEINCOMPLETE */
end

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    csr_wr_vld <= 1'b0;
    regwr_csr <= 1'b0;
  end
  else if (state == IDLE && csr_vld && decode.csr) begin
    // Cancel the CSR write for csrrc/rs if rs1(zimm)=0
    csr_wr_vld <= ~((funct3 == 3'b010 || funct3 == 3'b011) && zimm == '0);

    // Cancel the CSR register writeback for rd == 0
    regwr_csr <= rd != '0;
  end
  else if (state == WRITE) begin
    regwr_csr <= 1'b0;
  end
end

// CSR R/W ----------------------------------------------------
// aggregate all read-valid sources
assign csr_rd_vld = mcycle_rd_vld && minstret_rd_vld;

// CSR read/write access
assign csr_rd_en = state == READ && csr_rd_vld;
assign csr_wr_en = state == WRITE && csr_wr_vld;

// Register write back
always_ff @(posedge clk) begin
  if (csr_rd_en) csr_data <= csr_rd_data;
end

// Trap Handling ----------------------------------------------
always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) trap_jump <= 1'b0;
  else if (activate_trap) begin
    trap_jump <= 1'b1;
    trap_handle <= mtvec; // Direct Mode
  end
  else if (return_trap) begin
    trap_jump <= 1'b1;
    trap_handle <= mepc;
  end
  else trap_jump <= 1'b0;
end

// ============================================================
// CSR Read
always_comb begin
  csr_rd_data  = '0;
  /* verilator lint_off CASEINCOMPLETE */
  case(addr)
    MSTATUS : begin
      csr_rd_data[3]    = mstatus.mie; 
      csr_rd_data[7]    = mstatus.mpie;
      csr_rd_data[12:11]= mstatus.mpp;
    end

    MIE : begin
      csr_rd_data[3]  = mie.msie; 
      csr_rd_data[7]  = mie.mtie;
      csr_rd_data[11] = mie.meie;
    end

    MTVEC     : csr_rd_data = mtvec;
    MSCRATCH  : csr_rd_data = mscratch;
    MEPC      : csr_rd_data = mepc;
    MCAUSE    : csr_rd_data = mcause;
    MTVAL     : csr_rd_data = mtval;

    MIP : begin
      csr_rd_data[3]  = mip.msip; 
      csr_rd_data[7]  = mip.mtip;
      csr_rd_data[11] = mip.meip;
    end

    MCYCLE    : csr_rd_data = mcycle[31:0];
    MINSTRET  : csr_rd_data = minstret[31:0];
    MCYCLEH   : csr_rd_data = mcycle[63:32];
    MINSTRETH : csr_rd_data = minstret[63:32];
  endcase // addr
  /* verilator lint_on CASEINCOMPLETE */
end

// ============================================================
// CSR Write
always_comb begin
  // Modify latched rd_data as per operation
  // RS: Set - wr_data as a set mask
  // RC: Clear - wr_data as a clear mask
  // RW/Default: wr_data as write data
  case (funct3[1:0])
    CSR_RS: csr_wr_data = csr_data | wr_data;
    CSR_RC: csr_wr_data = csr_data & ~wr_data;
    default: csr_wr_data = wr_data;
  endcase
end

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    mstatus.mie <= 1'b0;
    mstatus.mpie <= 1'b0;
    mstatus.mpp <= PRIVILEGE_MACHINE; // Machine Mode
    mip <= '0;
    mie <= '0;
    mtvec.base <= BOOT_ADDR[31:2];
    mtvec.mode <= DIRECT_MODE; // Direct Mode
  end
  else begin
    // Machine-mode writable registers
    if (csr_wr_en) begin
      /* verilator lint_off CASEINCOMPLETE */
      case (addr)

        MSTATUS: begin
          // Global Interrupt enable
          mstatus.mie <= csr_wr_data[3];
          // Previous mie, used as a stack for mie when jumping/returning from traps
          mstatus.mpie <= csr_wr_data[7];
        end

        MIE: begin
          // Interrupt Enables: Software, Timer and External
          mie.msie <= csr_wr_data[3];
          mie.mtie <= csr_wr_data[7];
          mie.meie <= csr_wr_data[11];
        end

        MTVEC: begin
          // Trap vector, only Direct Mode is supported
          mtvec.base <= csr_wr_data[31:2];
        end

        // Scratch register
        MSCRATCH: mscratch <= csr_wr_data;

        // Exception Program Counter
        // IALIGN=32, word aligned
        MEPC: mepc <= {csr_wr_data[31:2], 2'b00};

        // Trap cause register
        MCAUSE: mcause <= csr_wr_data;

        // Trap value register
        MTVAL: mtval <= csr_wr_data;

      endcase // addr
      /* verilator lint_on CASEINCOMPLETE */
    end
    else if (activate_trap) begin
      mstatus.mie <= 1'b0;
      mstatus.mpie <= mstatus.mie;
      mepc <= {decode.pc[31:2], 2'b00};
      mcause <= trap_cause;
      mtval <= trap_value;
    end
    else if (return_trap) begin
      mstatus.mie <= mstatus.mpie;
      mstatus.mpie <= 1'b1;
    end

    // MIP: Machine Interrupt Pending is merely a aggregator for interrupt sources
    // The interrupt is cleared by addressing the interrupt
    // msip: clear the memory mapped software interrupt register
    // mtip: cleared by writing to mtimecmp
    // meip: cleared by addressing external interrupt handler (PLIC)
    mip.msip <= software_interrupt & mstatus.mie & mie.msie;
    mip.mtip <= timer_interrupt    & mstatus.mie & mie.mtie;
    mip.meip <= external_interrupt & mstatus.mie & mie.meie;
  end
end

// ============================================================
// Core Interrupter

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    core_interrupt <= 1'b0;
  end
  else begin
    // Inform the WB stage about pending interrupts
    core_interrupt <= |{mip};

    // core_interrupt_cause maps the interrupt cause according to priority
    if (mip.meip)
      core_interrupt_cause <= EXTERNAL_INTERRUPT;
    else if (mip.msip) 
      core_interrupt_cause <= SOFTWARE_INTERRUPT;
    else if (mip.mtip) 
      core_interrupt_cause <= TIMER_INTERRUPT;
  end
end

// ============================================================
// Hardware Performance Monitors

// mcycle, 64b Machine cycle counter
assign mcycle_wrenl = csr_wr_en && addr == MCYCLE;
assign mcycle_wrenh = csr_wr_en && addr == MCYCLEH;

kronos_counter64 #(
  .EN_COUNTERS   (EN_COUNTERS),
  .EN_COUNTERS64B(EN_COUNTERS64B)
) u_hpmcounter0 (
  .clk      (clk          ),
  .rstz     (rstz         ),
  .incr     (1'b1         ),
  .load_data(csr_wr_data  ),
  .load_low (mcycle_wrenl ),
  .load_high(mcycle_wrenh ),
  .count    (mcycle       ),
  .count_vld(mcycle_rd_vld)
);

// minstret, 64b Machine instructions-retired counter
assign minstret_wrenl = csr_wr_en && addr == MINSTRET;
assign minstret_wrenh = csr_wr_en && addr == MINSTRETH;

kronos_counter64 #(
  .EN_COUNTERS   (EN_COUNTERS),
  .EN_COUNTERS64B(EN_COUNTERS64B)
) u_hpmcounter1 (
  .clk      (clk            ),
  .rstz     (rstz           ),
  .incr     (instret        ),
  .load_data(csr_wr_data    ),
  .load_low (minstret_wrenl ),
  .load_high(minstret_wrenh ),
  .count    (minstret       ),
  .count_vld(minstret_rd_vld)
);

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
  , decode
};
`endif

endmodule
