# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0


from vunit import VUnitCLI
from vunit.verilog import VUnit

test_name = "kronos_id_unit_test"

cli = VUnitCLI()
args = cli.parse_args()
args.output_path = "./tests/"+test_name

vu = VUnit.from_args(args=args)

lib = vu.add_library('lib')

source_files = [
    "../rtl/core/kronos_types.sv",
    "../rtl/core/kronos_ID.sv",
    "../tests/unit/kronos_ID_unit_test.sv"
]
for f in source_files:
    lib.add_source_files(f)

vu.set_sim_option("modelsim.vsim_flags", ['-do "add wave -r *"'])

vu.main()
