# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Make a container for the test file
add_hdl_source(kronos_compliance.sv
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
get_hdl_sources(kronos_compliance TEST_SOURCES)

# Configure VUnit testrunner script
set(testrunner_script "${CMAKE_CURRENT_BINARY_DIR}/kronos_compliance_testrunner.py")
configure_file("${CMAKE_CURRENT_LIST_DIR}/kronos_compliance_testrunner.py.in"
        "${testrunner_script}")
