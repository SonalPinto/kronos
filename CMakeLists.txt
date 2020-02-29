# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


cmake_minimum_required(VERSION 3.10)

project(kronos)

enable_testing()

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# Add tools
set(verilator_DIR "$ENV{VERILATOR_ROOT}/../share/verilator")
find_package(verilator)
find_package(Python3)
find_package(VUnit)
find_package(RISCV)
find_package(SRecord)

# Add Packages
include(macros)
include(AddHDL)
include(AddVUnit)
include(AddRISCV)

add_subdirectory(rtl)
add_subdirectory(tests)
