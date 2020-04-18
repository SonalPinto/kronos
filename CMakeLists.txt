# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


cmake_minimum_required(VERSION 3.10)

project(kronos)

enable_testing()

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
set(UTILS "${CMAKE_CURRENT_LIST_DIR}/utils")

# Add tools
find_package(Python3)
find_package(RISCV)
find_package(SRecord)
find_package(Verilator)
find_package(VUnit)
find_package(Yosys)

# Add Packages
include(macros)
include(AddHDL)
include(AddVUnit)
include(AddRISCV)

# Globals
# pre-compliled lattice primitive/simulation library for modelsim
set(LATTICE_LIBRARY $ENV{LATTICE_LIBRARY})

add_subdirectory(rtl)
add_subdirectory(src)
add_subdirectory(tests)
