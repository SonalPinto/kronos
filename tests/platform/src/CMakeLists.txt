# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_riscv_executable(doubler2.c
    SOURCES
        start.S
    LINKER_SCRIPT
        link.ld
)
