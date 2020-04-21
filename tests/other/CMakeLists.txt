# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

add_hdl_source(comp.sv)

add_hdl_unit_test(comp_ut.sv
  DEPENDS
    comp
)
