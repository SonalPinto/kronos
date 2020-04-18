# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Find Verilator
# https://www.veripool.org/projects/verilator

function(find_verilator)
  find_package(PackageHandleStandardArgs REQUIRED)

  # <verilator-install>/bin directory should be in the PATH
  find_program(VERILATOR_BIN verilator
    PATH_SUFFIXES bin
    DOC "Path to Verilator compiler"
  )

  get_filename_component(VERILATOR_BIN_DIR ${VERILATOR_BIN} DIRECTORY)

  find_path(VERILATOR_INCLUDES verilated.h
    PATHS ${VERILATOR_BIN_DIR}/..
    PATH_SUFFIXES include share/verilator/include
    DOC "Path to the Verilator headers"
  )

  find_package_handle_standard_args(Verilator
    REQUIRED_VARS
      VERILATOR_BIN
      VERILATOR_INCLUDES
  )

  set(VERILATOR_FOUND ${VERILATOR_FOUND} PARENT_SCOPE)
  set(VERILATOR_BIN "${VERILATOR_BIN}" PARENT_SCOPE)
  set(VERILATOR_INCLUDES "${VERILATOR_INCLUDES}" PARENT_SCOPE)
endfunction()

find_verilator()
