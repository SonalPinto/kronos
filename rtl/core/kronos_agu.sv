// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Address Generation Unit
  - Fancy name for a 32b adder
*/

module kronos_agu
  import kronos_types::*;
(
  input  logic [31:0] instr,
  input  logic [31:0] base,
  input  logic [31:0] offset,
  output logic [31:0] addr,
  output logic        misaligned
);

logic [4:0] OP;
logic [1:0] data_size;

logic align;
logic [31:0] addr_raw;
logic [1:0] byte_addr;

// ============================================================
// IR segments
assign OP = instr[6:2];
assign data_size = instr[13:12];

// ============================================================
// Adder
assign align = OP == INSTR_JALR;

always_comb begin
  addr_raw = base + offset;
  addr[31:1] = addr_raw[31:1];
  // blank the LSB for aligned add (JALR)
  addr[0] = ~align & addr_raw[0];
end

// Tap the lowest 2b of the adder chain to detect misaligned access
// based on instruction.
assign byte_addr = addr[1:0];

// ============================================================
// Misaligned Detect
always_comb begin
  unique case(OP)
    INSTR_JAL,
    INSTR_JALR,
    INSTR_BR: begin
      // All jumps need to be word-aligned for RV32I
      misaligned = byte_addr != 2'b00;
    end
    INSTR_LOAD,
    INSTR_STORE: begin
      // Memory access is misaligned if the access size
      // doesn't land on a boundary divisible by that size.
      if (data_size == WORD && byte_addr != 2'b00) misaligned = 1'b1;
      else if (data_size == HALF && byte_addr[0] != 1'b0) misaligned = 1'b1;
      else misaligned = 1'b0;
    end
    default : misaligned = 1'b0;
  endcase
end


// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
    , instr[31:14]
    , instr[11:7]
    , instr[1:0]
};
`endif

endmodule
