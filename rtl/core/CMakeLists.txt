# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_source(kronos_types.sv)

add_hdl_source(kronos_IF.sv
    DEPENDS
        kronos_types
)

add_hdl_source(kronos_hcu.sv
    DEPENDS
        kronos_types
)

add_hdl_source(kronos_ID.sv
    DEPENDS
        kronos_types
)

add_hdl_source(kronos_alu.sv
    DEPENDS
        kronos_types
)

add_hdl_source(kronos_EX.sv
    DEPENDS
        kronos_types
        kronos_alu
)

add_hdl_source(kronos_WB.sv
    DEPENDS
        kronos_types
)
