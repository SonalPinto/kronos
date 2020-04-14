// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

package krz_map;

// ============================================================
// General Purpose Registers

// 32b Scratch Register
parameter logic [5:0] KRZ_SCRATCH       = 6'h00;

// 24b Boot Vector (warm-boot start address)
parameter logic [5:0] KRZ_BOOTVEC       = 6'h01;

// GPIO Direction: 0=input (default), 1=output
parameter logic [5:0] KRZ_GPIO_DIR      = 6'h02;

// GPIO Output Write: Driven output value, if pin is configured as output
parameter logic [5:0] KRZ_GPIO_WRITE    = 6'h03;

// GPIO Input Read: Read input value, if pin is configured as input, default: 0
parameter logic [5:0] KRZ_GPIO_READ     = 6'h04;

// UART Control: Clock prescaler, TX Queue clear
parameter logic [5:0] KRZ_UART_CTRL     = 6'h05;

// UART Status: TX Queue size
parameter logic [5:0] KRZ_UART_STATUS   = 6'h06;

// SPIM Control: CPOL, CPHA, Clock prescaler, RX/TX Queue clear
parameter logic [5:0] KRZ_SPIM_CTRL     = 6'h07;

// SPIM Status: RX/TX Queue size
parameter logic [5:0] KRZ_SPIM_STATUS   = 6'h08;

endpackage