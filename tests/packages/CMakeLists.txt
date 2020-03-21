# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_source(utils.sv
    DEPENDS
        kronos_types
)

add_hdl_source(rv32_assembler.sv
    DEPENDS
        kronos_types
)
