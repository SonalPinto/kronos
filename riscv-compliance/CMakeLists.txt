# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# -------------------------------------------------------------
# Compliance test using SystemVerilog + VUnit/Modelsim
# -------------------------------------------------------------
# Make a container for the test file
add_hdl_source(kronos_compliance_vsim.sv
    SYNTHESIZABLE FALSE
    LINT FALSE
    DEPENDS
        spsram32_model
        kronos_core
)

set(TEST_RUN_DIR "${CMAKE_BINARY_DIR}/output/compliance/sim")
set(TEST_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/compliance/rv32i")

file(MAKE_DIRECTORY "${TEST_RUN_DIR}")
file(MAKE_DIRECTORY "${TEST_OUTPUT_DIR}")

# Get HDL Sources
get_hdl_sources(kronos_compliance_vsim TEST_SOURCES)

# Configure VUnit testrunner script
set(testrunner_script "${CMAKE_CURRENT_BINARY_DIR}/kronos_compliance_vsim.py")
configure_file("${CMAKE_CURRENT_LIST_DIR}/kronos_compliance_vsim.py.in"
        "${testrunner_script}")


# -------------------------------------------------------------
# Compliance test using Verilator + C++
# -------------------------------------------------------------
add_hdl_source(kronos_compliance_top.sv
  VERILATE TRUE
  DEPENDS
    kronos_core
    generic_spram
)

add_executable(kronos_compliance
  kronos_compliance.cpp
)

target_link_libraries(kronos_compliance
  verilated-kronos_compliance_top
)
