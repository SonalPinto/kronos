# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

#
# CMake Target Rules for HDL source
#
# Derived from Tymoteusz Blazejczyk's [Logic]
# Ref: https://github.com/tymonx/logic.git
#


include(AddHDLCommon)
include(AddHDLVerilator)


function(add_hdl_source hdl_file)
   # Create an HDL source target as a container for its properties

   set(one_value_arguments
      NAME
      SYNTHESIS
      LINT
   )

   set(multi_value_arguments
      SOURCES
      DEFINES
      DEPENDS
      INCLUDES
   )

   # Resolve keywords into ARG_#
   cmake_parse_arguments(ARG
      "" 
      "${one_value_arguments}"
      "${multi_value_arguments}" 
      ${ARGN}
   )

   # Check if the file exists
   get_filename_component(hdl_file "${hdl_file}" REALPATH)
   if (NOT EXISTS "${hdl_file}")
      message(FATAL_ERROR "HDL file doesn't exist: ${hdl_file}")
   endif()

   get_filename_component(hdl_name "${hdl_file}" NAME_WE)

   # Init args
   init_arg(ARG_NAME ${hdl_name})
   init_arg(ARG_SYNTHESIS TRUE)
   init_arg(ARG_LINT TRUE)
   init_arg(ARG_SOURCES ${hdl_file})
   init_arg(ARG_DEFINES "")
   init_arg(ARG_DEPENDS "")
   init_arg(ARG_INCLUDES "")

   set_realpath(ARG_SOURCES)
   set_realpath(ARG_INCLUDES)
   

   # Create source file target and bind it's properties
   # This target doesn't do anything on its own
   # It's a just a great container for its properties!
   set(target "${ARG_NAME}")
   add_custom_target(${target})

   foreach (arg ${one_value_arguments} ${multi_value_arguments})
      set_target_properties(${target}
         PROPERTIES
            HDL_${arg} "${ARG_${arg}}"
      )
   endforeach()

   # Check and Bind dependencies
   foreach (dep ${ARG_DEPENDS})
      if (NOT TARGET ${dep})
         message(FATAL_ERROR "${target}'s HDL dependancy doesn't exist: ${name}")
      endif()
      add_dependencies(${target} ${dep})
   endforeach()

   # Derived Targets
   lint_hdl()

endfunction()

