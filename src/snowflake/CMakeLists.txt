# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_riscv_executable(sf_blinky.c
    SOURCES
        start.S
    LINKER_SCRIPT
        link.ld
)

add_riscv_executable(sf_prime.c
    SOURCES
        start.S
    LINKER_SCRIPT
        link.ld
)
