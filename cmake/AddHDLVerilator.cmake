# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Verilator Rules for HDL sources
#   lint_hdl- : Lints the HDL source using verilator

if(NOT VERILATOR_FOUND)
  return()
endif()

if (NOT VERILATOR_ENV_SETUP)
  set(LINT_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/lint"
    CACHE INTERNAL "Lint output directory" FORCE)
  file(MAKE_DIRECTORY "${LINT_OUTPUT_DIR}")

  set(VERILATOR_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/verilator"
    CACHE INTERNAL "Verilator output directory" FORCE)
  file(MAKE_DIRECTORY "${VERILATOR_OUTPUT_DIR}")

  set(VERILATOR_ENV_SETUP 1)
endif()

function(lint_hdl)
  # Lint HDL using verilator

  if (NOT DEFINED ARG_LINT OR NOT ARG_LINT)
    return()
  endif()

  # config & env
  set(target "lint-${ARG_NAME}")
  set(lint_output "${ARG_NAME}.lint")

  set(exlibs)
  foreach (lib ${external_libs})
    # cmake will replace with ; with a space. This is basically adding two items to the list
    list(APPEND exlibs "-y;${lib}")
  endforeach()

  set(includes)
  foreach (inc ${include_dirs})
    list(APPEND includes "-I${inc}")
  endforeach()

  add_custom_command(
    OUTPUT
      ${lint_output}
    COMMAND
      ${VERILATOR_BIN}
    ARGS
      --lint-only -Wall
      ${includes}
      ${exlibs}
      -sv ${sources}
      2>&1 | tee ${lint_output}
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

function(verilate_hdl)
  # Verilate HDL

  if (NOT DEFINED ARG_VERILATE OR NOT ARG_VERILATE)
    return()
  endif()

  # config & env
  set(target "verilate-${ARG_NAME}")
  set(verilated_module "${ARG_NAME}__ALL.a")

  set(includes)
  foreach (inc ${include_dirs})
    list(APPEND includes "-I${inc}")
  endforeach()

  set(working_dir "${VERILATOR_OUTPUT_DIR}/${ARG_NAME}")
  file(MAKE_DIRECTORY ${working_dir})

  add_custom_command(
    OUTPUT
      ${verilated_module}
    COMMAND
      ${VERILATOR_BIN}
    ARGS
      -O3 -Wall -cc -Mdir .
      --prefix ${ARG_NAME}
      --top-module ${ARG_NAME}
      ${includes}
      -sv ${sources}
      2>&1 | tee "${ARG_NAME}.verilate.log"
    COMMAND
      make
    ARGS
      -f ${ARG_NAME}.mk
    WORKING_DIRECTORY
      ${working_dir}
    COMMENT
      "Verilator Lint - ${ARG_NAME}"
  )

  add_custom_target(${target}
    DEPENDS
      "${verilated_module}"
  )

endfunction()