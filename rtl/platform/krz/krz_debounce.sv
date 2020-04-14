// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
KRZ Simple Debouncer
*/

module krz_debounce #(
    parameter N = 16,
    parameter DEBOUNCE = 16
)(
    input  logic        clk,
    input  logic        rstz,
    output logic [N-1:0] read,
    input  logic [N-1:0] gpio_in
);

logic [DEBOUNCE:0] timer;
logic tick;

always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) timer <= '0;
    else if (tick) timer <= '0;
    else timer <= timer + 1'b1;
end

assign tick = timer[DEBOUNCE];

generate
    genvar i;

    for (i=0; i<N; i++) begin
        logic [1:0] sync;
        logic raw_val;
        logic [1:0] poll;

        // sync inputs
        always_ff @(posedge clk) begin
            sync <= {sync[0], gpio_in[i]};
        end
        assign raw_val = sync[1];

        // Poll read value on every tick
        // And if stable (two consecutive reads are the same), latch it
        always_ff @(posedge clk) begin
            if (tick) begin
                poll <= {poll[0], raw_val};
                read[i] <= ^{poll};
            end
        end
    end
endgenerate

endmodule