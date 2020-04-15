// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ns
`include "vunit_defines.svh"

module tb_debouncer;

logic clk;
logic rstz;
logic [7:0] read;
logic [7:0] gpio_in;

input_debouncer #(.N(8), .DEBOUNCE(4)) u_dut (
    .clk    (clk    ),
    .rstz   (rstz   ),
    .read   (read   ),
    .gpio_in(gpio_in)
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
endclocking

// ============================================================

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        gpio_in = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("transmit") begin
        logic [7:0] data, current_read;

        // let the read settle
        ##64;

        repeat (8) begin
            current_read = read;

            // provide jumpy input
            data = $urandom();

            gpio_in = data;
            repeat (8) begin
                ##($urandom_range(20,31));
                gpio_in = ~gpio_in;
                // read should be all zero
                $display("READ: %h", read);
                assert(read == current_read);
            end

            ##(16*3 + 4);

            $display("READ: %h", read);
            assert(read == data);
        end


        ##64;
    end
end

`WATCHDOG(1ms);

endmodule