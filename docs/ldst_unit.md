# Load Store Unit

The Load Store Unit (LSU) in the Write Back stage operates on all data memory access instructions. The LSU is a Wishbone master with read/write control (unlike the Fetch stage which only reads from the instruction memory). 

The Kronos LSU natively supports misaligned memory access. Moreover, misaligned access which require a word boundary cross (data spread across two words) are handled as two aligned accesses. As seen form the outside, the LSU's memory access is always word-aligned (32-bit, i.e `addr[1:0] == 2'b00`).

> As a result of hardware implementation of misaligned memory access, the rv32i compliance test, `I-MISALIGN_LDST-01` fails because it expects the core to issue an exception on misaligned access, and then jump to the trap handler. The ISA spec does not demand that misaligned access should not be handled in hardware. There's even an git issue raised on this - [riscv-compliance issue#22](https://github.com/riscv/riscv-compliance/issues/22).

For load instructions (LB, LBU, LH, LHU and LW), the data memory read address is generated in `result1`. The data load size (in bytes) and whether the load data should be sign extended or not is also passed along from the decoder. 

Byte read are always aligned. Halfword access are misaligned if the byte offset is not 0 or 2. And, halfword access with a byte offset of 3, requires a boundary cross. Word access are misaligned if the byte offset is not 0, and require a boundary cross.

The data read from the memory is byte-rotated and then masked to obtain the load data. The rotation degree is determined from the lowest two bits of the address (`byte_index`). For loads that need a boundary cross, I need to read two consecutive words from the memory. An example is shown below, where I need to load a word (4 bytes) from a misaligned address, at byte index = 3.

![Kronos LSU Load](_images/kronos_lsu-load2.svg)

For store instructions (SB, SH and SW), the data memory write address is generated in `result1` and the store data is in `result2`. Just like the load operation, the store data is rotated byte-wise for misaligned and boundary cross access. The byte-wise write mask is derived from the size of the store data and is shifted by the `byte_index`. The store of the previously loaded data, back to the same address is illustrated below.

![Kronos LSU Store](_images/kronos_lsu-store.svg)

Overall, the control logic is represented by this FSM. Under ideal circumstances, aligned or misaligned with no boundary crossing memory operations take 2 cycles, and boundary crossing ones take 3 cycles. Surely this could be cut down by a cycle, but I chose to register the memory controls, address and data.

![Kronos LSU FSM](_images/kronos_lsu-ctrl.svg)
