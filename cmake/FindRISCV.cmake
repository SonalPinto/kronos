# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Add RISCV Toolchain
# We are _NOT_ setting up cmake for cross-compile
# Just porting in the binary tools for setting up test inputs

function(find_riscv)
  find_package(PackageHandleStandardArgs REQUIRED)

  find_program(RISCV_GCC riscv32-unknown-elf-gcc
    PATHS
      $ENV{RISCV_TOOLCHAIN_DIR}
      /opt/riscv32i
    PATH_SUFFIXES bin
    DOC "Path to RISCV-32 toolchain gcc"
  )

  find_program(RISCV_OBJDUMP riscv32-unknown-elf-objdump
    PATHS
      $ENV{RISCV_TOOLCHAIN_DIR}
      /opt/riscv32i
    PATH_SUFFIXES bin
    DOC "Path to RISCV-32 toolchain objdump"
    )

  find_program(RISCV_OBJCOPY riscv32-unknown-elf-objcopy
    PATHS
      $ENV{RISCV_TOOLCHAIN_DIR}
      /opt/riscv32i
    PATH_SUFFIXES bin
    DOC "Path to RISCV-32 toolchain objcopy"
  )

  find_package_handle_standard_args(RISCV
    REQUIRED_VARS
      RISCV_GCC
      RISCV_OBJDUMP
      RISCV_OBJCOPY
  )

  set(RISCV_FOUND ${RISCV_FOUND} PARENT_SCOPE)
  set(RISCV_GCC "${RISCV_GCC}" PARENT_SCOPE)
  set(RISCV_OBJDUMP "${RISCV_OBJDUMP}" PARENT_SCOPE)
  set(RISCV_OBJCOPY "${RISCV_OBJCOPY}" PARENT_SCOPE)
endfunction()

find_riscv()
