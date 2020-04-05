# Development Environment

> Note: This section talks about the development environment for the project. Integrating and using the Kronos Core doesn't require setting up the development environment! Head on over to the [integration section](integration.md).

The Kronos core is entirely written in SystemVerilog. The development environment is listed below:

- HDL: SystemVerilog
- Unit Testing: [VUnit](https://vunit.github.io/), a python based unit testing framework for SystemVerilog. The project has excepts this package installed for python3
- SV Simulator: [Modelsim FPGA Starter Edition](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/model-sim.html). It's "free", and the waveform viewer is leagues ahead of gtkwave.
- Linting - [Verilator](https://www.veripool.org/wiki/verilator)
- Build System: CMake
- RISC-V GNU toolchain configured for `rv32i`
- Other: 
    * [srec_cat](http://srecord.sourceforge.net/man/man1/srec_cat.html) : for converting compiled hex dumps into SV readable memory files
    * [Lattice Radiant](http://www.latticesemi.com/Products/DesignSoftwareAndIP/FPGAandLDS/Radiant) : For implementing the design on the iCE40UP5K and for iterative feedback on design choices.
    * [iceprog](https://github.com/cliffordwolf/icestorm/tree/master/iceprog) : for programming the iCEBreaker board, and I dislike the Radiant programmer.

This is my go-to dev setup for digital design work. Linting with verilator, unit testing with vunit and seamless HDL dependency maintenance and build with cmake.

In order for cmake to find all the dependencies and tools, certain environment variables need to be setup (in your bashrc) and in your PATH.

```
export VERILATOR_ROOT=/opt/verilator-v4.026/bin         # your verilator install
export LATTICE_LIBRARY="~/work/icelib/ice40up"          # lattice compiled lib
export RISCV_TOOLCHAIN_DIR="/opt/riscv32i"              # your riscv-gnu toolchain

PATH="$PATH:$VERILATOR_ROOT"
PATH="$PATH:/opt/intelFPGA_pro/19.4/modelsim_ase/bin"   # your modelsim install
PATH="$PATH:/opt/lscc/radiant/2.0/bin/lin64"            # your radiant install
```

Where the Lattice lib points to the pre-compliled iCE40UP series primitive/simulation library for modelsim. To compile the library for modelsim (and this is the **only** simualtor Lattice supports right now). This is only needed by test targets and designs (platforms) that use Lattice primitives.

```    
export FOUNDRY=/opt/lscc/radiant/2.0/bin                  # where radiant is installed. The script needs this temporary env var defined

cd ${FOUNDARY}/../cae_library/simulation/scripts              

tclsh cmpl_libs.tcl \
    -sim_path /opt/intelFPGA_pro/19.4/modelsim_ase/bin \ # your modelsim install
    -device ice40up \
    -target_path ~/work/icelib                           # where you want the lib to be compiled to

```

CMake is an out-of-source build, and thus you need to create a build directory before setting up the build targets.
```
cd kronos
mkdir build
cd build
cmake ..

make help               # list all available targets

make lint-kronos_core   # lint the kronos_core

make testdata-all       # compile all riscv test programs and convert them to SV memory files

make test               # run all tests in the project

```


