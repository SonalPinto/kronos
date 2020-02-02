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
        COMMAND ${Python3_EXECUTABLE} -c "import site; print(site.USER_SITE);" 
        OUTPUT_VARIABLE Python3_USER_SITELIB 
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    find_path(VUNIT_DIR verilog.py
        PATHS
            ${Python3_USER_SITELIB}
            ${Python3_STDLIB} ${Python3_STDARCH}
            ${Python3_SITELIB} ${Python3_SITEARCH}
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
