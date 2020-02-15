# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_unit_test(kronos_IF_unit_test.sv
    DEPENDS
        spsram32_model
        kronos_IF
)

add_hdl_unit_test(kronos_ID_unit_test.sv
    DEPENDS
        kronos_ID
        rv32_assembler
)

add_hdl_unit_test(kronos_EX_unit_test.sv
    DEPENDS
        kronos_EX
)

add_hdl_unit_test(hcu_unit_test.sv
    DEPENDS
        spsram32_model
        kronos_core
        rv32_assembler
)
