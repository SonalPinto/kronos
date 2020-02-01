# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


cmake_minimum_required(VERSION 3.10)

project(kronos LANGUAGES C CXX)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

set(verilator_DIR "/opt/verilator-v4.026/share/verilator")
find_package(verilator)

include(macros)
include(AddHDL)

add_subdirectory(rtl)
