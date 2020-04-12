// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
KRZ Simple Debouncer
*/

module krz_debounce (
    input  logic        clk,
    output logic [15:0] read,
    input  logic [15:0] gpio_in
);

generate
    genvar i;

    for (i=0; i<16; i++) begin : DEBOUNCE
        logic [3:0] sync;
        logic stable;

        // sync inputs
        always_ff @(posedge clk) begin
            sync <= {sync[2:0], gpio_in[i]};
        end

        // check if stable
        assign stable = sync[3:1] == 3'b000 || sync[3:1] == 3'b111;

        // Latch if stable
        always_ff @(posedge clk) begin
            if (stable) read[i] <= sync[3];
        end
    end
endgenerate

endmodule