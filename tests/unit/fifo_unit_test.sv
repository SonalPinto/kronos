// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ns
`include "vunit_defines.svh"

module tb_fifo;

logic clk;
logic rstz;
logic clear;
logic [$clog2(32):0] size;
logic full;
logic empty;
logic [7:0] din;
logic din_vld;
logic din_rdy;
logic [7:0] dout;
logic dout_vld;
logic dout_rdy;

fifo #(
    .WIDTH(8),
    .DEPTH(32)
) u_dut (
    .clk     (clk     ),
    .rstz    (rstz    ),
    .clear   (clear   ),
    .size    (size    ),
    .full    (full    ),
    .empty   (empty   ),
    .din     (din     ),
    .din_vld (din_vld ),
    .din_rdy (din_rdy ),
    .dout    (dout    ),
    .dout_vld(dout_vld),
    .dout_rdy(dout_rdy)
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input din_rdy, dout, dout_vld, size, full, empty;
    output din, din_vld, dout_rdy;
endclocking

// ============================================================
logic [7:0] TX [$], RX [$];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        clear = 0;
        din_vld = 0;
        dout_rdy = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("rw") begin
        logic [7:0] data;
        int n;
        logic check;

        repeat (128) begin

            TX = {};
            RX = {};

            // write some words into the fifo
            n = $urandom_range(1,31);
            check = 0;
            repeat (n) begin
                data = $urandom();
                @(cb)
                if (check) assert (cb.din_rdy);
                cb.din <= data;
                cb.din_vld <= 1;
                check = 1;

                TX.push_back(data);
            end
            @(cb) cb.din_vld <= 0;

            // check fifo size
            assert(size == TX.size());

            // Write more until full
            repeat (32) begin
                data = $urandom();
                @(cb)
                cb.din <= data;
                cb.din_vld <= 1;
            end
            @(cb) cb.din_vld <= 0;

            assert(full);
            assert(size == 33);

            // Read back
            check = 0;
            repeat (n) begin
                @(cb iff cb.dout_vld) begin
                    if (check) begin
                        data = cb.dout;
                        RX.push_back(data);
                    end
                    cb.dout_rdy <= 1;
                    check = 1;
                end
            end
            @(cb);
            data = cb.dout;
            RX.push_back(data);
            cb.dout_rdy <= 0;
            @(cb);

            assert(size == 33 - n);

            foreach (TX[i]) begin
                $display("[%0d] TX: %h, RX: %h", i, TX[i], RX[i]);
            end

            assert (RX == TX);

            // Read more until empty
            repeat (32) begin
                @(cb) cb.dout_rdy <= 1;
            end
            @(cb) cb.dout_rdy <= 0;

            assert (size == 0);
            assert (empty);
            assert (~full);

            $display("------------------------------");
            ##8;
        end

        ##64;
    end

    `TEST_CASE("real") begin
        int n;
        logic tx_busy, rx_busy;

        repeat (128) begin
            TX = {};
            RX = {};

            n = $urandom_range(2, 512);
            tx_busy = $urandom_range(0,1);
            rx_busy = $urandom_range(0,1);

            $display("N = %0d", n);
            $display("TX busy = %h", tx_busy);
            $display("RX busy = %h", rx_busy);

            fork
                driver(n, tx_busy);
                monitor(n, rx_busy);
            join

            foreach (TX[i]) begin
                $display("[%0d] TX: %h, RX: %h", i, TX[i], RX[i]);
            end

            assert (TX == RX);
            assert (size == 0);
            assert (empty);
            assert (~full);

            $display("------------------------------");
            ##8;
        end

        ##64;
    end
end
`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic driver(int N=32, logic throttle=0);
    logic [7:0] data;
    int i;

    data = $urandom();
    TX.push_back(data);
    i=1;
    @(cb)
    cb.din <= data; 
    cb.din_vld <= 1;

    forever @(cb) begin
        if (cb.din_rdy) begin
            if (throttle) begin
                cb.din_vld <= 0;
                ##($urandom_range(1,4));
            end

            data = $urandom();
            TX.push_back(data);

            cb.din <= data;
            cb.din_vld <= 1;

            i++;
            if (i == N) begin
                break;
            end
        end
    end
    @(cb iff cb.din_rdy) cb.din_vld <= 0;
endtask

task automatic monitor(int N=32, logic throttle=0);
    logic [7:0] data;
    int i;

    i = 0;
    @(cb) cb.dout_rdy <= 0;
    forever @(cb) begin
        if (cb.dout_vld) begin
            if (cb.dout_rdy && cb.dout_vld) begin
                $display("HERE: %d : %d", i, N);
                data = cb.dout;
                RX.push_back(data);

                i++;
                if (i == N) begin
                    cb.dout_rdy <= 0;
                    break;
                end
            end

            if (throttle) begin
                cb.dout_rdy <= 0;
                ##($urandom_range(1,4));
            end

            cb.dout_rdy <= 1;
        end
        else cb.dout_rdy <= 0;
    end
endtask


endmodule
