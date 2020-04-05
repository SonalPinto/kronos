# Control and Status Registers

The Kronos CSR unit not only houses the platform specific Privileged ISA Machine Mode CSRs but also acts as an interrupter for the core and can execute the necessary macro operations for activating and return from traps. The following CSR are implemented in Kronos

| Address | CSR        | Description |
| --------|------------|-------------|
| 0x300   | mstatus    | machine status register |
| 0x304   | mie        | machine interrupt enable register|
| 0x305   | mtvec      | machine trap vector base-address register|
| 0x340   | mscratch   | machine scratch register|
| 0x341   | mepc       | machine exception program counter|
| 0x342   | mcause     | machine cause register|
| 0x343   | mtval      | machine trap value|
| 0x344   | mip        | machine interrupt pending register|
| 0xB00   | mcycle     | machine cycle counter |
| 0xB02   | minstret   | machine instruction retired counter|
| 0xB80   | mcycleh    | machine cycle counter, higher word|
| 0xB82   | minsterth  | machine instruction retired counter, higher word|

In the `mstatus` register, only the bits `mie` and `mpie` are implemented. 
- mie (mstatus[3]): Global interrupt enable. 
- mpie (mstatus[7]): Previous mie, used as a stack for mie when jumping/returning from traps. Hardwired to `0b11` (privilege level: machine).

For `mie` and `mip`, just the machine timer, software and external enables are implemented.
- msie (mie[3]) : Machine software interrupt enable
- mtie (mie[7]) : Machine timer interrupt enable
- meie (mie[11]) : Machine external interrupt enable
- msip (mip[3]) : Machine software interrupt pending
- mtip (mip[7]) : Machine timer interrupt pending
- meip (mip[11]) : Machine external interrupt pending

The `mip` is merely a aggregator for interrupt sources. These interrupts are not a part of the Kronos core, and are left to the platform design. The interrupt is cleared by addressing the interrupt.
- msip: clear the memory mapped software interrupt register
- mtip: cleared by writing to `mtimecmp` (machine timer compare register)
- meip: cleared by addressing external interrupt handler (PLIC)

Kronos only supports direct mode trap handler jumps. Thus, the lower two bits of the `mtvec` is hardwired to `0b00` and only the upper 30b forms the word-aligned address of the trap handler.

When a Write Back stage decides to jump to the trap handler, the CSR unit does the following:
- jump address = mtvec
- mstatus.mie = 0
- mstatus.mpie = mstatus.mie
- mepc = trapped PC, word-aligned
- mcause = trap cause
- mtval = trap value

The trap cause, value and PC and provided by the Write Back stage. This macro operation is called `activate trap`.

For returning from the trap (MRET instruction), the Write Back stage instructs the CSR unit to perform the macro operation `return_trap` where:
- jump address = mepc
- mstatus.mie = mstatus.mpie
- mstatus.mpie = 1

The macros are executed in a single cycle, and forms the trap/return setup phase. The very next cycle, the core jumps to the CSR unit's jump address.

Two hardware performance counters are implemented as well! The `mcycle`, which ticks up on every cycle and the `minstret` which counts the number of instructions executed. There's a neat trick about how these 64b counters are designed for Kronos - which needs to run on the iCE40UP5K. The counter is made of two 32b counters splitting the critical path. The two words of the counter do not update together. When the lower word saturates, a tick event is registered. The next cycle, the upper word counts up. The count read is only valid when the tick update isn't pending. You'd almost never encounter this tick, but if you do, the read of the upper word is delayed merely by a cycle. 

These counters are ripe for being optimized out or reduced to 32b, if the use case doesn't require a 64b counter.
