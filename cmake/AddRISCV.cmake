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
  init_arg(ARG_LINKER_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/link.ld")
  init_arg(ARG_KRZ_APP FALSE)

  set_realpath(ARG_SOURCES)
  set_realpath(ARG_LINKER_SCRIPT)

  set(memfile "${name}.mem")
  set(elf "${name}.elf")
  set(objdump "${name}.objdump")
  set(binary "${name}.bin")
  set(target "riscv-${name}")

  set(outputs)

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
      -Os
      -march=rv32i
      -mabi=ilp32
      -static
      -nostartfiles
      --specs=nano.specs
      --specs=nosys.specs
      -I{CMAKE_CURRENT_LIST_DIR}
      -T${ARG_LINKER_SCRIPT}
      ${source} ${ARG_SOURCES}
      -o ${elf}
    COMMAND
      ${RISCV_OBJDUMP}
    ARGS
      -D ${elf} > ${objdump}
    COMMAND
      ${RISCV_OBJCOPY}
    ARGS
      -O binary ${elf} ${binary}
    WORKING_DIRECTORY
      ${TESTDATA_OUTPUT_DIR}
  )

  list(APPEND outputs ${binary})

  if (${CMAKE_BUILD_TYPE} MATCHES "Dev")
    add_custom_command(
      OUTPUT
        ${memfile}
      COMMAND
        ${SREC_CAT}
      ARGS
        ${binary} -binary -byte-swap 4 
        -o ${memfile} -vmem
      WORKING_DIRECTORY
        ${TESTDATA_OUTPUT_DIR}
      DEPENDS
        ${binary}
    )
    
    list(APPEND outputs ${memfile})
  endif()

  add_custom_target(${target}
    DEPENDS
      ${outputs}
  )

  add_dependencies(testdata-all ${target})

  if (${ARG_KRZ_APP})
    # If this is an application, then prepare binary to be flashed
    set(appfile "${name}.krz.bin")
    set(appmemfile "${name}.krz.mem")

    set(outputs)

    add_custom_command(
      OUTPUT
        ${appfile}
      COMMAND
        ${Python3_EXECUTABLE}
      ARGS
        ${UTILS}/krzprog.py
        --bin ${binary}
      WORKING_DIRECTORY
        ${TESTDATA_OUTPUT_DIR} 
    )

    list(APPEND outputs ${appfile})

    if (${CMAKE_BUILD_TYPE} MATCHES "Dev")
      add_custom_command(
        OUTPUT
          ${appmemfile}
        COMMAND
          ${SREC_CAT}
        ARGS
          ${appfile} -binary -byte-swap 4 
          -o ${appmemfile} -vmem
        WORKING_DIRECTORY
          ${TESTDATA_OUTPUT_DIR}
        DEPENDS
          ${appfile}
      )

      list(APPEND outputs ${appmemfile})
    endif()

    add_custom_target(krz-${target}
      DEPENDS
        ${outputs}        
    )

    add_dependencies(krz-${target}
      ${target} 
    )

    add_dependencies(testdata-all "krz-${target}")
  endif()
  
endfunction()
