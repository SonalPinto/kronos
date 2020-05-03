# Exceptions and Interrupts

The following exceptions are caught by the Kronos core:

|Trap Cause | Trap Value |
| ----------| -----------| 
Illegal instruction  | IR
Instruction address misaligned | addr
Breakpoint | PC
Machine Environment Call | 0
Load address misaligned  | addr
Store address misaligned | addr

> `CATCH_ILLEGAL_INSTR`, `CATCH_MISALIGNED_JMP` and `CATCH_MISALIGNED_LDST` are configurable parameters for Kronos. Setting them to 0 turns off detection of these exceptions and reclaims some decent logic area.

The interrupts sources are aggregated by the CSR unit into `mip`. These interrupts are blanked by the global interrupt enable (`mstatus.mie`) and their individual interrupt enables in `mie` (`msie`, `mtie`, `meie`).

|Trap Cause | Trap Value |
| ----------| -----------| 
Software interrupt  | 0
Timer interrupt | 0
External interrupt | 0
