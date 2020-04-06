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

add_hdl_unit_test(krz_intercon_unit_test.sv
    DEPENDS
        krz_intercon
        spsram32_model
)
