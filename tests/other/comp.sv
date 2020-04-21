// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

module comp1 (
  input logic signed [7:0] a,
  input logic signed [7:0] b,
  output logic [1:0] c
);

always_comb begin
  if (a < b) c = 2'b01;
  else if (a > b) c = 2'b10;
  else c = 2'b00;
end

endmodule

module comp1u (
  input logic [7:0] a,
  input logic [7:0] b,
  output logic [1:0] c
);

always_comb begin
  if (a < b) c = 2'b01;
  else if (a > b) c = 2'b10;
  else c = 2'b00;
end

endmodule


module comp2 (
  input logic [7:0] a,
  input logic [7:0] b,
  output logic [1:0] c
);

always_comb begin
  c = 2'b00;

  if (~a[7] & b[7]) c = 2'b10;
  else if (a[7] & ~b[7]) c = 2'b01;
  else begin

    for (int i=6; i>=0; i--) begin
      if (c == 2'b00) begin
        if (~a[i] & b[i]) c = 2'b01;
        else if (a[i] & ~b[i]) c = 2'b10;
      end
    end
  
  end
end

endmodule

module comp2u (
  input logic [7:0] a,
  input logic [7:0] b,
  output logic [1:0] c
);

always_comb begin
  c = 2'b00;

  for (int i=7; i>=0; i--) begin
    if (c == 2'b00) begin
      if (~a[i] & b[i]) c = 2'b01;
      else if (a[i] & ~b[i]) c = 2'b10;
    end
  end
end

endmodule
