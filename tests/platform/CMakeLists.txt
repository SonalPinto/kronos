# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_unit_test(icebreaker_lite_unit_test.sv
    DEPENDS
        icebreaker_lite_top
        rv32_assembler
    TESTDATA
       doubler
)
