# Kronos Architecture

Like every other processor designer out there, I designed the the Kronos core with the express objective to maximize performance while using the least resources. In other words, raw performance at a reasonable cost, with a priority on performance. The challenging constraint inspired some interesting design choices which are described in subsequent sections. Most implemented instructions executed in one cycle.

The design was developed on the [iCEBreaker](https://1bitsquared.com/products/icebreaker) FPGA Development board which houses the tiny Lattice iCE40U5K, to showcase its viability as a performance core for low-end embedded FPGA systems.

Kronos is 3-stage pipelined in-order RISC-V core. The RISC-V ISA is well suited to be implemented as a classic pipelined risc architecture, and this core is no exception. An overview of the kronos core is illustrated below, visualizing the three stages.

![Kronos Architecture](_images/kronos_arch.svg)


## Fetch

The instruction fetch stage reads word-aligned (4B) 32-bit instructions over a simple **Wishbone** pipelined master style synchronous interface, designed to play well with synchronous single-port SRAM. The Program Counter (`PC`) is 32b wide as per RV32I spec (`XLEN = 32`). Under ideal circumstances an instruction is fetched every cycle, offering ideal throughput. The `PC` always increments to the next word (`PC+4`) unless the core needs to jump as a result of an instruction or to the trap handler. The 32 RISC-V Integer registers reside in the Fetch stage in the Register File (`RF`). The register operands (`rs1`, `rs2`) and the sign extended Immediate are prepared at this stage.

## Decode

The instruction (`IR`) from the Fetch stage is trivially decoded (thanks to the simplicity of the RISC-V ISA). Two operands (`op1`, `op2`) are prepared for the ALU alongside the appropriate alu operation for the fetched instruction. An address for instructions that require it (branch, load, store) is calculated by the Address Generation Unit (`AGU`, a fancy name for a simple 32b adder). Register operands for branch instructions are compared a handcrafted Branch Comparison Unit (`BCU`). Store data and write-mask are prepared for memory store instructions. Structural hazard checks are maintained by a dedicated and quite simple Hazard Control Unit (`HCU`) and it stalls the Decoder when a register operand that is to be read has a pending write. The Decode stage ensures that operands passed to the next stage are always hazard free. The stage takes one cycle unless stalled.

## Execute

The final stage of the Kronos core is responsible for quite a bit of work. Aside from writing back results to the integer registers, and branching, it also sequences memory access operations (data load/store) and Control-Status Register (`CSR`) operations. And, catches exceptions and responds to interrupts. The Execute stage contains a typical Arithmetic Logic Unit (`ALU`) that consumes the alu operands decoded by the previous stage to generate a result for write back. Register write backs can be either the result of an instruction, some data loaded from the memory, or data read from the CSR. When a branch occurs, the entire pipeline is flushed. The data memory interface is also a synchronous **Wishbone** pipelined master.
