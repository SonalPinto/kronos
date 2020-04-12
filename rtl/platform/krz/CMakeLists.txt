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

add_hdl_source(krz_debounce.sv)

add_hdl_source(krz_top.sv
    DEPENDS
        kronos_core
        krz_xbar
        krz_sysbus
        krz_gpreg
        krz_debounce
        uart_tx
        ice40up_ebr4K
        ice40up_sram64K
)
