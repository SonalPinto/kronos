# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


cmake_minimum_required(VERSION 3.10)

project(kronos)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# Add Verilator cmake package
# Note: this will run some c++ compiler flag checks on buil
set(verilator_DIR "$ENV{VERILATOR_ROOT}/../share/verilator")
find_package(verilator)

# Add HDL packages
include(macros)
include(AddHDL)

add_subdirectory(rtl)
