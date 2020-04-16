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
logic sys_stb;
logic sys_ack;

logic [5:0] perif_adr;
logic [2:0][31:0] perif_rdat;
logic [31:0] perif_wdat;
logic perif_we;
logic [2:0] perif_stb;
logic [2:0] perif_ack;

krz_sysbus u_sysbus (
    .clk        (clk       ),
    .rstz       (rstz      ),
    .sys_adr_i  (sys_adr   ),
    .sys_dat_i  (sys_wdat  ),
    .sys_dat_o  (sys_rdat  ),
    .sys_we_i   (sys_we    ),
    .sys_stb_i  (sys_stb   ),
    .sys_ack_o  (sys_ack   ),
    .perif_adr_o(perif_adr ),
    .perif_dat_i(perif_rdat),
    .perif_dat_o(perif_wdat),
    .perif_we_o (perif_we  ),
    .perif_stb_o(perif_stb ),
    .perif_ack_o(perif_ack )
);


logic [11:0] gpio_dir;
logic [11:0] gpio_write;
logic [11:0] gpio_read;
logic [11:0] uart_prescaler;
logic uart_tx_clear;
logic [7:0] uart_tx_size;
logic [7:0] spim_prescaler;
logic spim_cpol;
logic spim_cpha;
logic spim_tx_clear;
logic spim_rx_clear;
logic [7:0] spim_tx_size;
logic [7:0] spim_rx_size;

krz_gpreg u_gpr (
    .clk           (clk           ),
    .rstz          (rstz          ),
    .adr_i         (perif_adr     ),
    .dat_i         (perif_wdat    ),
    .dat_o         (perif_rdat[0] ),
    .we_i          (perif_we      ),
    .stb_i         (perif_stb[0]  ),
    .ack_o         (perif_ack[0]  ),
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

default clocking cb @(posedge clk);
    default input #10ps output #10ps;
    input sys_ack, sys_rdat;
    output sys_stb, sys_we, sys_wdat, sys_adr;
endclocking

// ============================================================
logic [7:0] TX [$], RX [$];

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        clk = 0;
        rstz = 0;

        sys_stb = 0;
        gpio_read = 0;
        perif_ack[1] = 0;
        perif_ack[2] = 0;
        perif_rdat[1] = '0;
        perif_rdat[2] = '0;

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

        gpreg_page_addr = 24'h800000;

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
                    KRZ_GPIO_DIR:    written_data = write_data[11:0];
                    KRZ_GPIO_WRITE:  written_data = write_data[11:0];
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
end

`WATCHDOG(1ms);

endmodule
