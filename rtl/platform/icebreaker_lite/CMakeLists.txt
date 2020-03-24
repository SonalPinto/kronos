# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_source(icebreaker_lite_memory.sv)
add_hdl_source(icebreaker_lite_system_bus.sv)

add_hdl_source(icebreaker_lite_top.sv
    DEPENDS
        kronos_core
        icebreaker_lite_memory
        icebreaker_lite_system_bus
    LIBRARIES
        ${LATTICE_LIBRARY}
)
