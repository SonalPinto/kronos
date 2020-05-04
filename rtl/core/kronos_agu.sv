// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Kronos Address Generation Unit
  - Fancy name for a 32b adder
*/

module kronos_agu
  import kronos_types::*;
#(
  parameter CATCH_MISALIGNED_JMP = 1,
  parameter CATCH_MISALIGNED_LDST = 1
)(
  input  logic [31:0] instr,
  input  logic [31:0] base,
  input  logic [31:0] offset,
  output logic [31:0] addr,
  output logic        misaligned_jmp,
  output logic        misaligned_ldst
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

generate
  if (CATCH_MISALIGNED_JMP) begin
    assign misaligned_jmp = (OP == INSTR_JAL || OP == INSTR_JALR || OP == INSTR_BR)
                        && byte_addr != 2'b00;
  end
  else begin
    assign misaligned_jmp = 1'b0;
  end
endgenerate

generate
  if (CATCH_MISALIGNED_LDST) begin
    always_comb begin
      if (OP == INSTR_LOAD || OP == INSTR_STORE) begin
        // Memory access is misaligned if the access size
        // doesn't land on a boundary divisible by that size.
        if (data_size == WORD && byte_addr != 2'b00) misaligned_ldst = 1'b1;
        else if (data_size == HALF && byte_addr[0] != 1'b0) misaligned_ldst = 1'b1;
        else misaligned_ldst = 1'b0;
      end
      else misaligned_ldst = 1'b0;
    end
  end
  else begin
    assign misaligned_ldst = 1'b0;
  end
endgenerate

// ------------------------------------------------------------
`ifdef verilator
logic _unused = &{1'b0
  , instr[31:14]
  , instr[11:7]
  , instr[1:0]
};
`endif

endmodule
