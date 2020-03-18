# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_subdirectory(src)

add_hdl_unit_test(kronos_IF_unit_test.sv
    DEPENDS
        spsram32_model
        kronos_IF
)

add_hdl_unit_test(kronos_ID_unit_test.sv
    DEPENDS
        kronos_ID
        rv32_assembler
        common
)

add_hdl_unit_test(kronos_EX_unit_test.sv
    DEPENDS
        kronos_EX
        common
)

add_hdl_unit_test(kronos_WB_lsu_unit_test.sv
    DEPENDS
        spsram32_model
        kronos_WB
)

add_hdl_unit_test(kronos_WB_counters_unit_test.sv
    DEPENDS
        kronos_WB
        rv32_assembler
        common
)

add_hdl_unit_test(core_basic_unit_test.sv
    DEPENDS
        spsram32_model
        kronos_core
        rv32_assembler
)

add_hdl_unit_test(core_adv_unit_test.sv
    DEPENDS
        spsram32_model
        kronos_core
        rv32_assembler
    TESTDATA
       doubler
       fibonnaci
)

add_hdl_unit_test(hcu_unit_test.sv
    DEPENDS
        kronos_ID
        rv32_assembler
        common
)

add_hdl_unit_test(branch_unit_test.sv
    DEPENDS
        kronos_ID
        kronos_EX
        kronos_WB
        rv32_assembler
)
