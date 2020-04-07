# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_source(krz_intercon.sv)

add_hdl_source(krz_top.sv
    DEPENDS
        kronos_core
        krz_intercon
        ice40up_ebr4K
        ice40up_sram64K
)
