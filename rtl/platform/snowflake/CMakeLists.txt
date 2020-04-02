# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_source(snowflake_system_bus.sv)
add_hdl_source(snowflake_7sd_driver.sv)

add_hdl_source(snowflake_top.sv
    DEPENDS
        kronos_core
        ice40up_memory_lite
        snowflake_system_bus
        snowflake_7sd_driver
    LIBRARIES
        ${LATTICE_LIBRARY}
)
