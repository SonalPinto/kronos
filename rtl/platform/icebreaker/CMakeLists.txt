# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


add_hdl_source(icebreaker_memory.sv
    LINT FALSE
    LIBRARIES
        ${LATTICE_LIBRARY}
)

add_hdl_source(icebreaker_memory_lite.sv)
add_hdl_source(icebreaker_system_bus_lite.sv)

add_hdl_source(icebreaker_lite_top.sv
    DEPENDS
        kronos_core
        icebreaker_memory_lite
        icebreaker_system_bus_lite
    LIBRARIES
        ${LATTICE_LIBRARY}
)
