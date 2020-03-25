# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Rules to generate test data using the riscv toolchain
# Needs riscv toolchain and srecord to translate the binary code
# into SystemVerilog readable memory files

if(NOT RISCV_FOUND OR NOT SRECORD_FOUND)
    return()
endif()

if (NOT TESTDATA_ENV_SETUP)
    set(TESTDATA_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/data"
        CACHE INTERNAL "Test data output directory" FORCE)
    file(MAKE_DIRECTORY "${TESTDATA_OUTPUT_DIR}")

    # A target to collect all testdata generators
    if (NOT TARGET testdata-all)
        add_custom_target(testdata-all)
    endif()

    set(TESTDATA_ENV_SETUP 1)
endif()

function(add_riscv_test_data source)
    # Create RISCV compilation target and translate the object 
    # into a SystemVerilog memory file
    # Note: This rule expects a single source file and an optional linker script

    set(one_value_arguments
        LINKER_SCRIPT
        USING_STDLIB
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
    init_arg(ARG_USING_STDLIB 0)
    init_arg(ARG_LINKER_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/link.ld")

    set_realpath(ARG_SOURCES)
    set_realpath(ARG_LINKER_SCRIPT)

    set(memfile "${name}.mem")
    set(elf "${name}.elf")
    set(objdump "${name}.objdump")
    set(binary "${name}.bin")
    set(target "testdata-${name}")

    set(NOSTDLIB "-nostdlib")
    if (ARG_USING_STDLIB EQUAL 0)
        set(NOSTDLIB)
    endif()

    # Setup command and target to generate the test data
    add_custom_command(
        OUTPUT
            ${memfile}
        BYPRODUCTS
            ${elf}
            ${objdump}
            ${binary}
        COMMAND
            ${RISCV_GCC}
        ARGS
            -march=rv32i
            -mabi=ilp32
            -static
            -fvisibility=hidden
            ${NOSTDLIB}
            -nostartfiles
            -ffreestanding
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
        COMMAND
            ${SREC_CAT}
        ARGS
            ${binary} -binary -byte-swap 4 
            -o ${memfile} -vmem
        WORKING_DIRECTORY
            ${TESTDATA_OUTPUT_DIR}
    )

    
    add_custom_target(${target}
        DEPENDS
            "${name}.mem"
    )

    add_dependencies(testdata-all ${target})
endfunction()
