# Exceptions and Interrupts

The following exceptions are caught by the Kronos core:

|Trap Cause | Trap Value |
| ----------| -----------| 
Illegal instruction  | `result1` (IR)
Instruction address misaligned | `result2` (direct branch target)
Breakpoint | `PC`
Machine Environment Call | 0

The interrupts sources are aggregated by the CSR unit into `mip`. These interrupts are blanked by the global interrupt enable (`mstatus.mie`) and their individual interrupt enables in `mie` (`msie`, `mtie`, `meie`).

|Trap Cause | Trap Value |
| ----------| -----------| 
Software interrupt  | 0
Timer interrupt | 0
External interrupt | 0
