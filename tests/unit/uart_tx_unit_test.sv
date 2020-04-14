// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ns
`include "vunit_defines.svh"

module tb_uart;

logic clk;
logic rstz;
logic tx;
logic [11:0] prescaler;
logic clear;
logic [7:0] size;
logic [7:0] dat_i;
logic we_i;
logic stb_i;
logic ack_o;

wb_uart_tx #(
    .BUFFER(256),
    .PRESCALER_WIDTH(12)
) u_dut (
    .clk      (clk      ),
    .rstz     (rstz     ),
    .tx       (tx       ),
    .prescaler(prescaler),
    .clear    (clear    ),
    .size     (size     ),
    .dat_i    (dat_i    ),
    .we_i     (we_i     ),
    .stb_i    (stb_i    ),
    .ack_o    (ack_o    )
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    output dat_i, we_i, stb_i;
    input ack_o;
endclocking

logic [1:0] line;
int state;
always_ff @(posedge clk) begin
    line <= {line[0], tx};
end

// ============================================================
logic [7:0] TX [$], RX [$];


`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        stb_i = 0;
        we_i = 0;
        prescaler = 7;
        clear = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("transmit") begin
        logic [7:0] data;
        int n;

        repeat (128) begin
            TX = {};
            RX = {};

            n = $urandom_range(1,7);

            fork 
                driver(n);
                monitor(n);
            join

            assert(RX == TX);

            $display("------------------");
        end

        ##64;
    end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic driver(int N=32);
    logic [7:0] data;

    @(cb);
    data = $urandom();
    TX.push_back(data);

    cb.dat_i <= data;
    cb.stb_i <= 1;
    cb.we_i <= 1;
    $display("tx: %h", data);

    repeat (N-1) begin
        @(cb iff cb.ack_o);
        data = $urandom();
        TX.push_back(data);

        cb.dat_i <= data;
        $display("tx: %h", data);
    end
    @(cb iff cb.ack_o);
    cb.stb_i <= 0;
    cb.we_i <= 0;
endtask

task automatic monitor(int N=32);
    logic [7:0] data;
    int i;
    int count;

    i = 0;
    state = 0;
    forever @(cb) begin
        // look for start
        if (state == 0) begin
            if( line == 2'b10) begin
                // $display("%t s=%0d | %h", $realtime, state, line);
                state = 1;
                data = 'x;
                ##1;
            end
        end
        else if (state > 0 && state < 9) begin
            ##(prescaler);
            // $display("%t s=%0d > %b", $realtime, state, tx);
            data = {tx, data[7:1]};
            state++;
        end
        else if (state == 9) begin
            $display(">>> rx: %h", data);
            state = 0;

            RX.push_back(data);
            i++;
            if (i == N) break;
        end
    end
endtask

endmodule