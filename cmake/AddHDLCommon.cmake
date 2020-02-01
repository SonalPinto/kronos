# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

#
# Collection of useful function for cmake HDL rules
#

function(get_hdl_depends hdl_target hdl_depends_flat)
    # Flatten HDL dependency list by recursively traversing targets

    set(hdl_depends "")

    get_target_property(target_depends ${hdl_target} HDL_DEPENDS)

    foreach (name ${target_depends})
        get_hdl_depends(${name} depends)

        list(APPEND hdl_depends ${depends})
        list(APPEND hdl_depends ${name})
    endforeach()

    list(REMOVE_DUPLICATES hdl_depends)

    set(${hdl_depends_flat} ${hdl_depends} PARENT_SCOPE)

endfunction()
