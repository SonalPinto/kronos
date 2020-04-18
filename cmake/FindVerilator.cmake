# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Find Verilator
# https://www.veripool.org/projects/verilator

function(find_verilator)
  find_package(PackageHandleStandardArgs REQUIRED)

  find_program(VERILATOR_BIN verilator
    PATHS
      $ENV{VERILATOR_ROOT}/../../
    PATH_SUFFIXES bin
    DOC "Path to verilator transpiler"
  )

  find_package_handle_standard_args(Verilator
    REQUIRED_VARS
      VERILATOR_BIN
  )

  set(VERILATOR_FOUND ${VERILATOR_FOUND} PARENT_SCOPE)
  set(VERILATOR_BIN "${VERILATOR_BIN}" PARENT_SCOPE)
endfunction()

find_verilator()
