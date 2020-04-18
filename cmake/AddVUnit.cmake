# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# HDL Unit Test rule using Python3/VUnit

if(NOT VUNIT_FOUND)
  return()
endif()

if (NOT UNITTEST_ENV_SETUP)
  set(UNITTEST_OUTPUT_DIR "${CMAKE_BINARY_DIR}/output/tests"
    CACHE INTERNAL "Unit test output directory" FORCE)
  file(MAKE_DIRECTORY "${UNITTEST_OUTPUT_DIR}")

  set(UNITTEST_ENV_SETUP 1)
endif()

function(add_hdl_unit_test hdl_test_file)
  # Create an HDL unit test target

  set(one_value_arguments
    NAME
  )

  set(multi_value_arguments
    SOURCES
    DEFINES
    DEPENDS
    INCLUDES
    TESTDATA
  )

  # Resolve keywords into ARG_#
  cmake_parse_arguments(ARG
    "" 
    "${one_value_arguments}"
    "${multi_value_arguments}" 
    ${ARGN}
  )

  # Check if the file exists
  get_filename_component(hdl_test_file "${hdl_test_file}" REALPATH)
  if (NOT EXISTS "${hdl_test_file}")
    message(FATAL_ERROR "HDL file doesn't exist: ${hdl_test_file}")
  endif()

  get_filename_component(hdl_test_name "${hdl_test_file}" NAME_WE)

  # Init args
  init_arg(ARG_NAME ${hdl_test_name})
  init_arg(ARG_SOURCES ${hdl_test_file})
  init_arg(ARG_DEFINES "")
  init_arg(ARG_DEPENDS "")
  init_arg(ARG_INCLUDES "")
  init_arg(ARG_TESTDATA "")

  set_realpath(ARG_SOURCES)
  set_realpath(ARG_INCLUDES)

  # Make a container for the HDL Test File
  add_hdl_source("${ARG_SOURCE}"
    SYNTHESIZABLE FALSE
    LINT FALSE
    NAME ${ARG_NAME}
    SOURCES ${ARG_SOURCES}
    DEFINES ${ARG_DEFINES}
    DEPENDS ${ARG_DEPENDS}
    INCLUDES ${ARG_INCLUDES}
  )

  # Setup test output directory
  set(TEST_OUTPUT_DIR "${UNITTEST_OUTPUT_DIR}/${ARG_NAME}")

  # Get HDL Sources
  get_hdl_sources(${ARG_NAME} TEST_SOURCES)
  get_hdl_libs(${ARG_NAME} EXTERNAL_LIBS)
  get_hdl_includes(${ARG_NAME} INCLUDE_DIRS)

  # Configure VUnit testrunner script using ARGS defined so far
  set(testrunner_script "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}_testrunner.py")

  configure_file("${CMAKE_MODULE_PATH}/vunit_testrunner.py.in"
    "${testrunner_script}")

  # A target to run that script
  add_custom_target("test-${ARG_NAME}"
    COMMAND
      ${Python3_EXECUTABLE} ${testrunner_script}
    WORKING_DIRECTORY
      ${CMAKE_BINARY_DIR}
  )

  foreach(dep ${ARG_TESTDATA})
    if (NOT TARGET riscv-${dep})
      message(FATAL_ERROR "Test Data target does not exist: riscv-${dep}")
    endif()
    add_dependencies("test-${ARG_NAME}" "riscv-${dep}")
  endforeach(dep)

  # Bind to global test suite
  add_test(
    NAME
      ${ARG_NAME}
    COMMAND
      ${Python3_EXECUTABLE} ${testrunner_script}
    WORKING_DIRECTORY
      ${CMAKE_BINARY_DIR}
  )

endfunction()

