# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_subdirectory(src)

add_hdl_unit_test(snowflake_unit_test.sv
    DEPENDS
        snowflake_top
        rv32_assembler
    TESTDATA
       doubler2
       blinky
       prime
)

add_hdl_unit_test(krz_xbar_unit_test.sv
    DEPENDS
        krz_xbar
        spsram32_model
)

add_hdl_unit_test(krz_sysbus_unit_test.sv
    DEPENDS
        krz_sysbus
        krz_gpreg
        wb_uart_tx
)


add_hdl_unit_test(krz_blinky_unit_test.sv
    DEPENDS
        krz_top
    TESTDATA
        krz_blinky
)
