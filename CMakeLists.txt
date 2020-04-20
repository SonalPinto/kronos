# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


cmake_minimum_required(VERSION 3.10)

project(kronos)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
set(UTILS "${CMAKE_CURRENT_LIST_DIR}/utils")

# Setup output dirs
set(BIN_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/bin")
set(LIB_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/lib")
set(TESTDATA_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/data")
set(LINT_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/lint")
set(VERILATOR_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/verilator")
set(UNITTEST_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/tests")

file(MAKE_DIRECTORY ${BIN_OUTPUT_DIR})
file(MAKE_DIRECTORY ${LIB_OUTPUT_DIR})
file(MAKE_DIRECTORY ${TESTDATA_OUTPUT_DIR})
file(MAKE_DIRECTORY ${LINT_OUTPUT_DIR})
file(MAKE_DIRECTORY ${VERILATOR_OUTPUT_DIR})
file(MAKE_DIRECTORY ${UNITTEST_OUTPUT_DIR})

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${LIB_OUTPUT_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${LIB_OUTPUT_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${BIN_OUTPUT_DIR})

# =============================================================
if (${CMAKE_BUILD_TYPE} MATCHES "Dev")
  #
  # Development Environment
  #

  set(LATTICE_LIBRARY $ENV{LATTICE_LIBRARY})

  enable_testing()
  find_package(RISCV REQUIRED)
  find_package(Verilator REQUIRED)
  find_package(Python3 REQUIRED)
  find_package(VUnit REQUIRED)

  include(macros)
  include(AddHDL)
  include(AddRISCV)
  include(AddVUnit)

  add_subdirectory(rtl)
  add_subdirectory(src)
  add_subdirectory(impl)
  add_subdirectory(riscv-compliance)
  add_subdirectory(riscv-tests)
  add_subdirectory(tests)
  
else()
  #
  # Release/Compliance Testing Environment
  #
  
  find_package(RISCV REQUIRED)
  find_package(Python3 REQUIRED)
  find_package(Verilator)

  include(macros)
  include(AddHDL)
  include(AddRISCV)

  add_subdirectory(rtl)
  add_subdirectory(src)
  add_subdirectory(impl)
  add_subdirectory(riscv-compliance)
  add_subdirectory(riscv-tests)

endif()
