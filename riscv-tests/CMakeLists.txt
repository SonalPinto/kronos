# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_riscv_executable(dhrystone/dhrystone_main.c
  SOURCES
    common/crt0.S
    common/mini-printf.c
    common/util.c
    dhrystone/dhrystone.c
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    dhrystone
  DEFINES
    HZ=24000000
  KRZ_APP TRUE
)
