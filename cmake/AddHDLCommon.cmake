# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

#
# Collection of useful function for cmake HDL rules
#
# Note: cmake macro/function args are text replacement abstractions
# 
# When passing an "arg" to a macro/function, ${arg} will represent the variable
# and ${${arg}} will represent the variable value
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


function(get_hdl_sources hdl_target hdl_sources_out)
  # Get all sources defining this target

  set(hdl_sources "")

  # get dependencies
  get_hdl_depends(${hdl_target} all_hdl_targets)
  # add self to the list
  set(all_hdl_targets ${all_hdl_targets} ${hdl_target})

  # collect SOURCES property
  foreach(target ${all_hdl_targets})
    get_target_property(sources ${target} HDL_SOURCES)

    list(APPEND hdl_sources ${sources})
  endforeach()

  list(REMOVE_DUPLICATES hdl_sources)

  set(${hdl_sources_out} ${hdl_sources} PARENT_SCOPE)

endfunction()


function(get_hdl_includes hdl_target hdl_includes_out)
  # Get external library dependencies for this target

  set(hdl_includes "")

  # get dependencies
  get_hdl_depends(${hdl_target} all_hdl_targets)
  # add self to the list
  set(all_hdl_targets ${all_hdl_targets} ${hdl_target})

  # collect INCLUDES property
  foreach(target ${all_hdl_targets})
    get_target_property(includes ${target} HDL_INCLUDES)
    list(APPEND hdl_includes ${includes})
  endforeach()

  list(REMOVE_DUPLICATES hdl_includes)

  set(${hdl_includes_out} ${hdl_includes} PARENT_SCOPE)

endfunction()


function(get_hdl_libs hdl_target hdl_libs_out)
  # Get external library dependencies for this target

  set(hdl_libraries "")

  # get dependencies
  get_hdl_depends(${hdl_target} all_hdl_targets)
  # add self to the list
  set(all_hdl_targets ${all_hdl_targets} ${hdl_target})

  # collect LIBRARIES property
  foreach(target ${all_hdl_targets})
    get_target_property(libs ${target} HDL_LIBRARIES)

    list(APPEND hdl_libraries ${libs})
  endforeach()

  list(REMOVE_DUPLICATES hdl_libraries)

  set(${hdl_libs_out} ${hdl_libraries} PARENT_SCOPE)

endfunction()