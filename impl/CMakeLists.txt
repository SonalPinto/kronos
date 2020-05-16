# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

# =============================================================
# Snowflake
# =============================================================

# Get HDL Sources
get_hdl_sources(snowflake_top SOURCES)

# Prepare them for Radiant scripts
set(RADIANT_SOURCES)
foreach (src ${SOURCES})
  list(APPEND RADIANT_SOURCES "prj_add_source \"${src}\"")
endforeach()

string (REPLACE ";" "\n" RADIANT_SOURCES "${RADIANT_SOURCES}")

# -------------------------------------------------------------
# Snowflake on iCEBreaker using Radiant
set(PROJECT "sf_icebreaker")
set(PROJECT_PDC "${CMAKE_CURRENT_LIST_DIR}/sf_icebreaker.pdc")

set(prj_dir "${CMAKE_BINARY_DIR}/output/radiant/${PROJECT}")
file(MAKE_DIRECTORY ${prj_dir})

configure_file("${CMAKE_CURRENT_LIST_DIR}/sf.radiant_template.in"
        "${prj_dir}/build_sf.tcl")


# =============================================================
# KRZ
# =============================================================

# Get HDL Sources
get_hdl_sources(krz_top SOURCES)

# Prepare them for Radiant scripts
set(RADIANT_SOURCES)
foreach (src ${SOURCES})
  list(APPEND RADIANT_SOURCES "prj_add_source \"${src}\"")
endforeach()

string (REPLACE ";" "\n" RADIANT_SOURCES "${RADIANT_SOURCES}")

# -------------------------------------------------------------
# KRZ on iCEBreaker using Radiant
set(PROJECT "krz_icebreaker")
set(PROJECT_PDC "${CMAKE_CURRENT_LIST_DIR}/krz_icebreaker.pdc")

set(prj_dir "${CMAKE_BINARY_DIR}/output/radiant/${PROJECT}")
file(MAKE_DIRECTORY ${prj_dir})

configure_file("${CMAKE_CURRENT_LIST_DIR}/krz.radiant_template.in"
        "${prj_dir}/build_krz.tcl")

# =============================================================
# KRZBOY
# =============================================================

# Get HDL Sources
get_hdl_sources(krzboy SOURCES)

# Prepare them for Radiant scripts
set(RADIANT_SOURCES)
foreach (src ${SOURCES})
  list(APPEND RADIANT_SOURCES "prj_add_source \"${src}\"")
endforeach()

string (REPLACE ";" "\n" RADIANT_SOURCES "${RADIANT_SOURCES}")

# -------------------------------------------------------------
# KRZ on iCEBreaker using Radiant
set(PROJECT "krzboy_icebreaker")
set(PROJECT_PDC "${CMAKE_CURRENT_LIST_DIR}/krzboy_icebreaker.pdc")

set(prj_dir "${CMAKE_BINARY_DIR}/output/radiant/${PROJECT}")
file(MAKE_DIRECTORY ${prj_dir})

configure_file("${CMAKE_CURRENT_LIST_DIR}/krzboy.radiant_template.in"
        "${prj_dir}/build_krzboy.tcl")
