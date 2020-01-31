"""
    Copyright (c) 2020 Sonal Pinto <sonalpinto@gmail.com>

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
"""

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
