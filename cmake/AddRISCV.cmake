# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Rules to generate test data using the riscv toolchain
# Needs riscv toolchain and srecord to translate the binary code
# into SystemVerilog readable memory files

if(NOT RISCV_FOUND)
  return()
endif()

if (NOT TESTDATA_ENV_SETUP)
    # A target to collect all testdata generators
  if (NOT TARGET testdata-all)
    add_custom_target(testdata-all)
  endif()

  set(TESTDATA_ENV_SETUP 1)
endif()

function(add_riscv_executable source)
  # Create RISCV compilation target and translate the object 
  # into a SystemVerilog memory file

  set(one_value_arguments
    LINKER_SCRIPT
    KRZ_APP
  )

  set(multi_value_arguments
    SOURCES
    INCLUDES
    DEFINES
  )

  # Resolve keywords into ARG_#
  cmake_parse_arguments(ARG
    "" 
    "${one_value_arguments}"
    "${multi_value_arguments}" 
    ${ARGN}
  )

  # Check if the file exists
  get_filename_component(source "${source}" REALPATH)
  if (NOT EXISTS "${source}")
    message(FATAL_ERROR "Source file doesn't exist: ${source}")
  endif()

  get_filename_component(name "${source}" NAME_WE)

  # Init args
  init_arg(ARG_SOURCES "")
  init_arg(ARG_INCLUDES ${CMAKE_CURRENT_LIST_DIR})
  init_arg(ARG_DEFINES "")
  init_arg(ARG_LINKER_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/link.ld")
  init_arg(ARG_KRZ_APP FALSE)

  set_realpath(ARG_SOURCES)
  set_realpath(ARG_INCLUDES)
  set_realpath(ARG_LINKER_SCRIPT)

  set(includes)
  foreach (inc ${ARG_INCLUDES})
    list(APPEND includes "-I${inc}")
  endforeach()

  set(defines)
  foreach (def ${ARG_DEFINES})
    list(APPEND defines "-D${def}")
  endforeach()

  set(memfile "${name}.mem")
  set(elf "${name}.elf")
  set(objdump "${name}.objdump")
  set(binary "${name}.bin")
  set(target "riscv-${name}")

  # Setup command and target to generate the basic riscv program
  # and corresponding test format
  add_custom_command(
    OUTPUT
      ${binary}
    BYPRODUCTS
      ${elf}
      ${objdump}
    COMMAND
      ${RISCV_GCC}
    ARGS
      -O2
      -march=rv32i
      -mabi=ilp32
      -static
      -nostartfiles
      --specs=nano.specs
      --specs=nosys.specs
      ${defines}
      ${includes}
      -T${ARG_LINKER_SCRIPT}
      ${ARG_SOURCES} ${source}
      -o ${elf}
    COMMAND
      ${RISCV_OBJDUMP}
    ARGS
      -D ${elf} > ${objdump}
    COMMAND
      ${RISCV_OBJCOPY}
    ARGS
      -O binary ${elf} ${binary}
    COMMAND
      srec_cat
    ARGS
      ${binary} -binary -byte-swap 4 
      -o ${memfile} -vmem
    WORKING_DIRECTORY
      ${TESTDATA_OUTPUT_DIR}
  )

  add_custom_target(${target}
    DEPENDS
      ${binary}
  )

  add_dependencies(testdata-all ${target})

  if (${ARG_KRZ_APP})
    # If this is an application, then prepare binary to be flashed
    set(appfile "${TESTDATA_OUTPUT_DIR}/${name}.krz.bin")
    set(appmemfile "${TESTDATA_OUTPUT_DIR}/${name}.krz.mem")

    set(outputs)

    add_custom_command(
      OUTPUT
        ${appfile}
      COMMAND
        ${Python3_EXECUTABLE}
      ARGS
        ${UTILS}/krzprog.py
        --bin ${TESTDATA_OUTPUT_DIR}/${binary}
      COMMAND
        srec_cat
      ARGS
        ${appfile} -binary -byte-swap 4 
        -o ${appmemfile} -vmem
    )

    add_custom_target(krz-${target}
      DEPENDS
        ${appfile}        
    )

    add_dependencies(krz-${target}
      ${target} 
    )

    add_dependencies(testdata-all "krz-${target}")
  endif()
  
endfunction()
