# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


add_hdl_source(spsram32_model.sv
    SYNTHESIS FALSE
    LINT FALSE
)

add_hdl_source(ice40up_ebr.sv)

add_hdl_source(ice40up_sram64K.sv
    LINT FALSE
    LIBRARIES
        ${LATTICE_LIBRARY}
)

add_hdl_source(ice40up_sram128K.sv
    LINT FALSE
    LIBRARIES
        ${LATTICE_LIBRARY}
)
