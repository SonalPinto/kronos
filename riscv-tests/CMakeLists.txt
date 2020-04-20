# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

set(common_srcs common/crt0.S
  common/mini-printf.c
  common/util.c)

add_riscv_executable(dhrystone/dhrystone_main.c
  SOURCES
    ${common_srcs}
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

add_riscv_executable(median/median_main.c
  SOURCES
    ${common_srcs}
    median/median.c
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    median
  KRZ_APP TRUE
)

add_riscv_executable(qsort/qsort_main.c
  SOURCES
    ${common_srcs}
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    qsort
  KRZ_APP TRUE
)

add_riscv_executable(multiply/multiply_main.c
  SOURCES
    ${common_srcs}
    multiply/multiply.c
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    multiply
  KRZ_APP TRUE
)

add_riscv_executable(rsort/rsort.c
  SOURCES
    ${common_srcs}
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    rsort
  KRZ_APP TRUE
)

add_riscv_executable(spmv/spmv_main.c
  SOURCES
    ${common_srcs}
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    spmv
  KRZ_APP TRUE
)

add_riscv_executable(towers/towers_main.c
  SOURCES
    ${common_srcs}
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    towers
  KRZ_APP TRUE
)

add_riscv_executable(vvadd/vvadd_main.c
  SOURCES
    ${common_srcs}
  LINKER_SCRIPT
    common/link.ld
  INCLUDES
    common
    vvadd
  KRZ_APP TRUE
)
