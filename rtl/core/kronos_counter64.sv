// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Staggered 64b counter for Kronos RISC-V

The counter is made of two 32b counters splitting the critical path
for lower-end implementations (ex: Lattice iCE40UP)
The upper word update is delayed by a cycle
*/

module kronos_counter64 #(
  parameter EN_COUNTERS = 1,
  parameter EN_COUNTERS64B = 1
)(
  input  logic        clk,
  input  logic        rstz,
  input  logic        incr,
  input  logic [31:0] load_data,
  input  logic        load_low,
  input  logic        load_high,
  output logic [63:0] count,
  output logic        count_vld
);

logic [31:0] count_low, count_high;
logic incr_high;

always_ff @(posedge clk or negedge rstz) begin
  if (~rstz) begin
    count_low <= '0;
    count_high <= '0;
    incr_high <= 1'b0;
  end
  else begin
    incr_high <= 1'b0;

    // during a load (any segment), the count is paused
    if (load_low) count_low <= load_data;
    else if (load_high) count_high <= load_data;
    else begin
      if (incr) begin
        count_low <= count_low + 1'b1;
        // indicate that the upper word needs to increment
        incr_high <= count_low == '1;
      end

      if (incr_high) count_high <= count_high + 1'b1;
    end
  end
end

generate
  if (EN_COUNTERS) begin
    if (EN_COUNTERS64B) begin
      // the output 64b count is valid when the upper word update has settled
      assign count = {count_high, count_low};
      assign count_vld = ~incr_high;
    end
    else begin
      // the upper word will be optimized out
      assign count = {32'b0, count_low};
      assign count_vld = 1'b1;
    end
  end
  else begin
    assign count = '0;
    assign count_vld = 1'b1;
  end
endgenerate

endmodule
