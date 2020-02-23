# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


cmake_minimum_required(VERSION 3.10)

project(kronos)

enable_testing()

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# Add Verilator cmake package
# Note: this will run some c++ compiler flag checks on build
set(verilator_DIR "$ENV{VERILATOR_ROOT}/../share/verilator")
find_package(verilator)

find_package(Python3)
find_package(VUnit)

# Add HDL packages
include(macros)
include(AddHDL)
include(AddVUnit)

add_subdirectory(rtl)
add_subdirectory(tests)
