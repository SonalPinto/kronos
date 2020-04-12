// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ns
`include "vunit_defines.svh"

module tb_spim;

logic clk;
logic rstz;
logic sclk;
logic mosi;
logic miso;
logic [15:0] prescaler;
logic cpol;
logic cpha;
logic tx_clear;
logic rx_clear;
logic [15:0] tx_size;
logic [15:0] rx_size;
logic [7:0] dat_i;
logic [7:0] dat_o;
logic we_i;
logic stb_i;
logic ack_o;

wb_spi_master u_dut (
    .clk      (clk      ),
    .rstz     (rstz     ),
    .sclk     (sclk     ),
    .mosi     (mosi     ),
    .miso     (miso     ),
    .prescaler(prescaler),
    .cpol     (cpol     ),
    .cpha     (cpha     ),
    .tx_clear (tx_clear ),
    .rx_clear (rx_clear ),
    .tx_size  (tx_size  ),
    .rx_size  (rx_size  ),
    .dat_i    (dat_i    ),
    .dat_o    (dat_o    ),
    .we_i     (we_i     ),
    .stb_i    (stb_i    ),
    .ack_o    (ack_o    )
);

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    output dat_i, we_i, stb_i;
    input ack_o, dat_o;
endclocking

// ============================================================
logic [7:0] MTX [$], MRX [$];
logic [7:0] STX [$], SRX [$];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        stb_i = 0;
        we_i = 0;
        cpol = 0;
        cpha = 0;
        prescaler = 0;

        tx_clear = 0;
        rx_clear = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("transact") begin
        logic [7:0] data;
        int n;

        repeat (128) begin

            // Setup random scenario
            ##8;
            cpol = $urandom();
            cpha = $urandom();
            prescaler = $urandom_range(0,7);
            ##8;

            $display("CONFIG: prescaler=%0d, CPOL=%b CPHA=%b", prescaler, cpol, cpha);

            MTX = {};
            MRX = {};
            STX = {};
            SRX = {};

            n = $urandom_range(1,31);

            fork
                driver(n);
                spi_slave(n);
            join

            ##32;
            drain_rxq(n);

            assert(MTX == SRX);
            assert(MRX == STX);

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
    MTX.push_back(data);

    cb.dat_i <= data;
    cb.stb_i <= 1;
    cb.we_i <= 1;
    $display("tx: %h", data);

    repeat (N-1) begin
        @(cb iff cb.ack_o);
        data = $urandom();
        MTX.push_back(data);

        cb.dat_i <= data;
        $display("tx: %h", data);
    end
    @(cb iff cb.ack_o);
    cb.stb_i <= 0;
    cb.we_i <= 0;
endtask

task automatic drain_rxq(int N=32);
    logic [7:0] data;

    cb.stb_i <= 1;
    cb.we_i <= 0;

    repeat (N) begin
        @(cb iff cb.ack_o);
        data = cb.dat_o;

        $display("rx: %h", data);
        MRX.push_back(data);
    end
    cb.stb_i <= 0;
    cb.we_i <= 0;
endtask

task automatic spi_slave(int N=32);
    logic [7:0] tx_data, rx_data;

    miso = 0;

    repeat(N) begin
        tx_data = $urandom();

        $display("MISO = %h", tx_data);
        STX.push_back(tx_data);

        // Collect 1 byte
        case({cpol, cpha})
            0: begin
                {miso, tx_data} = {tx_data, 1'b0};
                repeat (7) begin
                    @(posedge sclk) rx_data = {rx_data[6:0], mosi};
                    @(negedge sclk) {miso, tx_data} = {tx_data, 1'b0};
                end
                @(posedge sclk) rx_data = {rx_data[6:0], mosi};
            end
            1: begin
                @(posedge sclk) {miso, tx_data} = {tx_data, 1'b0};
                repeat (7) begin
                    @(negedge sclk) rx_data = {rx_data[6:0], mosi};
                    @(posedge sclk) {miso, tx_data} = {tx_data, 1'b0};
                end
                @(negedge sclk) rx_data = {rx_data[6:0], mosi};
            end
            2: begin
                {miso, tx_data} = {tx_data, 1'b0};
                repeat (7) begin
                    @(negedge sclk) rx_data = {rx_data[6:0], mosi};
                    @(posedge sclk) {miso, tx_data} = {tx_data, 1'b0};
                end
                @(negedge sclk) rx_data = {rx_data[6:0], mosi};
            end
            3: begin
                @(negedge sclk) {miso, tx_data} = {tx_data, 1'b0};
                repeat (7) begin
                    @(posedge sclk) rx_data = {rx_data[6:0], mosi};
                    @(negedge sclk) {miso, tx_data} = {tx_data, 1'b0};
                end
                @(posedge sclk) rx_data = {rx_data[6:0], mosi};
            end
        endcase

        $display("MOSI = %h", rx_data);
        SRX.push_back(rx_data);
    end

endtask

endmodule