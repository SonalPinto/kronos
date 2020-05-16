# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_source(krz_map.sv)

add_hdl_source(krz_xbar.sv
  DEPENDS
    krz_map
)

add_hdl_source(krz_sysbus.sv
  DEPENDS
    krz_map
)

add_hdl_source(krz_gpreg.sv
  DEPENDS
    krz_map
)

add_hdl_source(krz_top.sv
  DEPENDS
    kronos_core
    krz_xbar
    krz_sysbus
    krz_gpreg
    input_debouncer
    wb_uart_tx
    wb_spi_master
    generic_rom
    ice40up_sram64K
)

add_hdl_source(krzboy.sv
  DEPENDS
    kronos_core
    krz_xbar
    krz_sysbus
    krz_gpreg
    input_debouncer
    wb_uart_tx
    wb_spi_master
    generic_rom
    ice40up_sram64K
)

