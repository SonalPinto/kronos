# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_riscv_test_data(blinky.c
    SOURCES
        start.S
    LINKER_SCRIPT
        link.ld
)

add_riscv_test_data(prime.c
    SOURCES
        start.S
    LINKER_SCRIPT
        link.ld
    USING_STDLIB
)
