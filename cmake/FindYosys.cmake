# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Find Yosys: Open Synthesis Suite
# https://www.clifford.at/yosys/

function(find_yosys)
    find_package(PackageHandleStandardArgs REQUIRED)

    find_program(YOSYS yosys
        PATH_SUFFIXES bin
        DOC "Path to Yosys: yosys"
    )

    find_package_handle_standard_args(Yosys
        REQUIRED_VARS
            YOSYS
    )

    set(YOSYS_FOUND ${YOSYS_FOUND} PARENT_SCOPE)
    set(YOSYS "${YOSYS}" PARENT_SCOPE)
endfunction()

find_yosys()
