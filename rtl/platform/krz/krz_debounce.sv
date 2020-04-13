// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
KRZ Simple Debouncer
*/

module krz_debounce #(
    parameter N = 16
)(
    input  logic        clk,
    input  logic        rstz,
    output logic [N-1:0] read,
    input  logic [N-1:0] gpio_in
);

logic [15:0] timer;
logic tick;

// 24MHz/(2^16) ~ 366Hz or 2.73ms
always_ff @(posedge clk or negedge rstz) begin
    if (~rstz) begin
        timer <= '0;
        tick <= '0;
    end
    else begin
        timer <= timer + 1'b1;
        tick <= timer == '0;
    end
end

generate
    genvar i;

    for (i=0; i<N; i++) begin : DEBOUNCE
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