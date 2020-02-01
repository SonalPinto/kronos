# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Verilator Rules for HDL sources
#   lint_hdl- : Lints the HDL source using verilator


if(NOT verilator_FOUND)
    return()
endif()

if (NOT VERILATOR_ENV_SETUP)
    set(LINT_OUTPUT_DIR "${CMAKE_BINARY_DIR}/lint"
        CACHE INTERNAL "Lint outpur directory" FORCE)
    file(MAKE_DIRECTORY "${LINT_OUTPUT_DIR}")

    set(VERILATOR_ENV_SETUP 1)
endif()

function(lint_hdl)
    # Lint HDL using verilator

    if (NOT DEFINED ARG_LINT OR NOT ARG_LINT)
        return()
    endif()

    # config & env
    set(target "lint_hdl-${ARG_NAME}")
    set(lint_output "${ARG_NAME}.lint")

    get_hdl_sources(${ARG_NAME} sources)

    add_custom_command(
        OUTPUT
            ${lint_output}
        COMMAND
            ${VERILATOR_BIN}
        ARGS
            --lint-only -Wall -sv ${sources} 2>&1 | tee ${lint_output}
        WORKING_DIRECTORY
            ${LINT_OUTPUT_DIR}
        COMMENT
            "Verilator Lint - ${ARG_NAME}"
    )

    add_custom_target(${target}
        DEPENDS
            ${lint_output}
    )

endfunction()