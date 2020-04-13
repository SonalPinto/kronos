// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

`include "vunit_defines.svh"

module tb_krz_sysbus_ut;

import krz_map::*;

logic clk;
logic rstz;

logic [23:0] sys_adr;
logic [31:0] sys_rdat;
logic [31:0] sys_wdat;
logic sys_we;
logic [3:0] sys_sel;
logic sys_stb;
logic sys_ack;

logic [7:0] perif_adr;
logic [31:0] perif_dat;
logic perif_we;

logic gpreg_stb;
logic uart_stb;
logic spim_stb;

logic gpreg_ack;
logic uart_ack;
logic spim_ack;

logic [31:0] gpreg_dat;
logic [7:0] uart_dat;
logic [7:0] spim_dat;

logic uart_tx_ack;
logic uart_rx_ack;

logic [15:0] gpio_dir;
logic [15:0] gpio_write;
logic [15:0] gpio_read;
logic [15:0] uart_prescaler;
logic uart_tx_clear;
logic [15:0] uart_tx_size;
logic [15:0] spim_prescaler;
logic spim_cpol;
logic spim_cpha;
logic spim_tx_clear;
logic spim_rx_clear;
logic [15:0] spim_tx_size;
logic [15:0] spim_rx_size;

logic uart_tx;

krz_sysbus u_sysbus (
    .clk        (clk      ),
    .rstz       (rstz     ),
    .sys_adr_i  (sys_adr  ),
    .sys_dat_i  (sys_wdat ),
    .sys_dat_o  (sys_rdat ),
    .sys_we_i   (sys_we   ),
    .sys_sel_i  (sys_sel  ),
    .sys_stb_i  (sys_stb  ),
    .sys_ack_o  (sys_ack  ),
    .perif_adr_o(perif_adr),
    .perif_dat_o(perif_dat),
    .perif_we_o (perif_we ),
    .gpreg_stb_o(gpreg_stb),
    .uart_stb_o (uart_stb ),
    .spim_stb_o (spim_stb ),
    .gpreg_ack_i(gpreg_ack),
    .uart_ack_i (uart_ack ),
    .spim_ack_i (spim_ack ),
    .gpreg_dat_i(gpreg_dat),
    .uart_dat_i (uart_dat ),
    .spim_dat_i (spim_dat )
);

assign uart_ack = uart_tx_ack | uart_rx_ack;

krz_gpreg u_gpr (
    .clk           (clk           ),
    .rstz          (rstz          ),
    .gpreg_adr_i   (perif_adr     ),
    .gpreg_dat_i   (perif_dat     ),
    .gpreg_dat_o   (gpreg_dat     ),
    .gpreg_we_i    (perif_we      ),
    .gpreg_stb_i   (gpreg_stb     ),
    .gpreg_ack_o   (gpreg_ack     ),
    .gpio_dir      (gpio_dir      ),
    .gpio_write    (gpio_write    ),
    .gpio_read     (gpio_read     ),
    .uart_prescaler(uart_prescaler),
    .uart_tx_clear (uart_tx_clear ),
    .uart_tx_size  (uart_tx_size  ),
    .spim_prescaler(spim_prescaler),
    .spim_cpol     (spim_cpol     ),
    .spim_cpha     (spim_cpha     ),
    .spim_tx_clear (spim_tx_clear ),
    .spim_rx_clear (spim_rx_clear ),
    .spim_tx_size  (spim_tx_size  ),
    .spim_rx_size  (spim_rx_size  )
);

wb_uart_tx u_uart_tx (
    .clk      (clk           ),
    .rstz     (rstz          ),
    .tx       (uart_tx       ),
    .prescaler(uart_prescaler),
    .clear    (uart_tx_clear ),
    .size     (uart_tx_size  ),
    .dat_i    (perif_dat[7:0]),
    .we_i     (perif_we      ),
    .stb_i    (uart_stb      ),
    .ack_o    (uart_tx_ack   )
);

logic [1:0] line;
int state;
always_ff @(posedge clk) begin
    line <= {line[0], uart_tx};
end

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input sys_ack, sys_rdat;
    output sys_stb, sys_we, sys_sel, sys_wdat, sys_adr;
    input uart_stb, perif_we;
    output uart_rx_ack, uart_dat;
endclocking

// ============================================================
logic [7:0] TX [$], RX [$];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        sys_stb = 0;
        gpio_read = 0;
        uart_dat = 0;
        uart_rx_ack = 0;
        spim_dat = 0;
        spim_ack = 0;

        fork 
            forever #1ns clk = ~clk;
        join_none

        ##4 rstz = 1;
    end

    `TEST_CASE("gpreg") begin
        logic [7:0] addr;
        logic [31:0] write_data, written_data, read_data;
        logic is_write;
        logic [23:0] gpreg_page_addr, sys_addr;
        int gpreg;

        gpreg_page_addr = 24'h800000 | (1<<(PAGE_GPREG+8));

        sys_sel = 4'hF;

        repeat (1024) begin
            // generate random valid scenario
            gpreg =  $urandom_range(0, 4);
            addr = gpreg << 2;
            write_data = $urandom();
            is_write = $urandom();
            sys_addr = gpreg_page_addr | addr;

            gpio_read = $urandom();

            @(cb);
            cb.sys_adr <= sys_addr;
            cb.sys_wdat <= write_data;
            cb.sys_we <= is_write;
            cb.sys_stb <= 1'b1;

            $display("sys_adr = %h", sys_addr);
            $display("sys_wdat = %h", write_data);
            $display("sys_we = %h", is_write);

            @(cb iff cb.sys_ack);
            cb.sys_stb <= 1'b0;

            // check registers
            case(gpreg)
                KRZ_SCRATCH:        read_data = u_gpr.scratch;
                KRZ_BOOTVEC:        read_data = u_gpr.bootvec;
                KRZ_GPIO_DIR:       read_data = gpio_dir;
                KRZ_GPIO_WRITE:     read_data = gpio_write;
                KRZ_GPIO_READ:      read_data = gpio_read;
            endcase // addr
            $display("reg[%0d] = %h", gpreg, read_data);

            if (is_write) begin
                case(gpreg)
                    KRZ_SCRATCH:     written_data = write_data;
                    KRZ_BOOTVEC:     written_data = write_data[23:0];
                    KRZ_GPIO_DIR:    written_data = write_data[15:0];
                    KRZ_GPIO_WRITE:  written_data = write_data[15:0];
                    KRZ_GPIO_READ:   written_data = read_data;
                endcase // addr
                $display("expected write = %h", written_data);
                assert(read_data == written_data);
            end
            else begin            
                $display("sys_rdat = %h", cb.sys_rdat);
                assert(read_data == cb.sys_rdat);
            end

            $display("------------------------------");
        end

        ##64;
    end

    `TEST_CASE("uart_tx") begin
        logic [3:0][7:0] write_data;
        logic [3:0] mask;
        int n;

        sys_adr = 24'h800000 | (1<<(PAGE_UART+8));
        u_gpr.uart_prescaler = 7;

        fork
            uart_monitor();
        join_none

        repeat (128) begin
            // generate random valid scenario
            write_data = $urandom();

            case ($urandom_range(0,2))
                0: mask = 4'h1;
                1: mask = 4'h3;
                2: mask = 4'hF;
            endcase

            @(cb);
            cb.sys_wdat <= write_data;
            cb.sys_sel <= mask;
            cb.sys_we <= 1'b1;
            cb.sys_stb <= 1'b1;

            $display("sys_wdat = %h", write_data);
            $display("sys_sel = %b", mask);

            @(cb iff cb.sys_ack);
            cb.sys_stb <= 1'b0;

            wait(u_uart_tx.txq_empty);
            ##128;

            n = $countones(mask);
            assert(n == RX.size());
            foreach(RX[i]) begin
                assert(RX[i] == write_data[i]);
            end
            $display("------------------------------");

            RX = {};
        end
    end

    `TEST_CASE("read8") begin
        logic [3:0][7:0] read_data, expected;
        logic [3:0] mask;
        int n, m;

        sys_adr = 24'h800000 | (1<<(PAGE_UART+8));
        sys_we = 1'b0;

        repeat (8) begin
            // generate random valid scenario
            read_data = $urandom();

            n = $urandom_range(0,2);
            case (n)
                0: mask = 4'h1;
                1: mask = 4'h3;
                2: mask = 4'hF;
            endcase
            m = $countones(mask);

            @(cb);
            cb.sys_sel <= mask;
            cb.sys_stb <= 1'b1;

            $display("Read Data = %h", read_data);
            $display("sys_sel = %b", mask);

            @(cb);
            for (int i=0; i<m; i++) begin
                @(cb iff cb.uart_stb);
                assert(~cb.perif_we);
                cb.uart_dat <= read_data[i];
                cb.uart_rx_ack <= 1;
                $display("rx = %h", read_data[i]);
            end
            @(cb);
            cb.uart_rx_ack <= 0;

            @(cb iff cb.sys_ack);
            cb.sys_stb <= 1'b0;

            $display("sys_rdat = %h", cb.sys_rdat);

            case (n)
                0: expected = read_data[0];
                1: expected = {read_data[0], read_data[1]};
                2: expected = {read_data[0], read_data[1], read_data[2], read_data[3]};
            endcase

            $display("expected = %h", expected);
            assert(cb.sys_rdat == expected);
            
            $display("------------------------------");
        end
    end
end

`WATCHDOG(1ms);

// ============================================================
// METHODS
// ============================================================

task automatic uart_monitor();
    logic [7:0] data;
    int count;

    state = 0;
    forever @(cb) begin
        // look for start
        if (state == 0) begin
            if( line == 2'b10) begin
                // $display("%t s=%0d | %h", $realtime, state, line);
                state = 1;
                data = 'x;
                ##2;
            end
        end
        else if (state > 0 && state < 9) begin
            ##(u_gpr.uart_prescaler);
            // $display("%t s=%0d > %b", $realtime, state, uart_tx);
            data = {uart_tx, data[7:1]};
            state++;
        end
        else if (state == 9) begin
            $display(">>> uart received: %h", data);
            state = 0;
            RX.push_back(data);
        end
    end
endtask

endmodule
