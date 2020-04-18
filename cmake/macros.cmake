# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


#
# Collection of useful macros
#
# Note: cmake macro/function args are text replacement abstractions
# 
# When passing an "arg" to a macro/function, ${arg} will reperesent the variable
# and ${${arg}} will represent the variable value
#

macro(init_arg arg val)
  # Set default value for args
  if (NOT DEFINED ${arg})
    set(${arg} ${val})
  endif()
endmacro()


macro(subdirlist result curdir)
  # List sub directories
  # ref: https://stackoverflow.com/questions/7787823/cmake-how-to-get-the-name-of-all-subdirectories-of-a-directory
  #
  # Ex:
  #   subdirlist(subdirs ${CMAKE_CURRENT_SOURCE_DIR})
  #
  #   foreach(dir ${subdirs})
  #       message("subdir: ${dir}")
  #   endforeach()
  #

  file(GLOB children RELATIVE ${curdir} ${curdir}/*)
  set(dirlist "")
  foreach(child ${children})
    if (IS_DIRECTORY ${curdir}/${child})
      list (APPEND dirlist ${child})
    endif()
  endforeach()
  set(${result} ${dirlist})
endmacro()


macro(set_realpath arg)
  # Resolve absolute path
  set(paths "")

  foreach (path ${${arg}})
    get_filename_component(path "${path}" REALPATH)
    list(APPEND paths "${path}")
  endforeach()

  list(REMOVE_DUPLICATES paths)
  set(${arg} ${paths})
endmacro()
