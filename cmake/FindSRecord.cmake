# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# Find SRecord, specifically srec_cat
# ref: http://srecord.sourceforge.net/

function(find_srecord)
  find_package(PackageHandleStandardArgs REQUIRED)

  find_program(SREC_CAT srec_cat
    PATH_SUFFIXES bin
    DOC "Path to SRecord Tool: srec_cat"
  )

  find_package_handle_standard_args(SRecord
    REQUIRED_VARS
    SREC_CAT
  )

  set(SRECORD_FOUND ${SRECORD_FOUND} PARENT_SCOPE)
  set(SREC_CAT "${SREC_CAT}" PARENT_SCOPE)
endfunction()

find_srecord()
