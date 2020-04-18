# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Add VUnit, an open source unit testing framework for VHDL/SystemVerilog
# https://vunit.github.io/about.html

# python3 -c 'import vunit'
# Python3_EXECUTABLE

if(NOT Python3_FOUND)
  return()
endif()

function(find_vunit)
  find_package(PackageHandleStandardArgs REQUIRED)

  execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "import re, vunit; print(re.sub(\"/__init__.py\", \"\", vunit.__file__))"
    OUTPUT_VARIABLE VUNIT_PACKAGE_SITE 
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  find_path(VUNIT_DIR verilog.py
    PATHS
      ${VUNIT_PACKAGE_SITE}
    PATH_SUFFIXES vunit
    DOC "Path to the VUnit Python3 module"
  )

  find_package_handle_standard_args(VUnit
    REQUIRED_VARS
      VUNIT_DIR
  )

  set(VUNIT_FOUND ${VUNIT_FOUND} PARENT_SCOPE)
  set(VUNIT_DIR "${VUNIT_DIR}" PARENT_SCOPE)
endfunction()

find_vunit()
