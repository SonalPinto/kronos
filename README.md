# Kronos RISC-V

Kronos is a 4-stage RISC-V RV32I_Zicsr_Zifencei core geared towards FPGA implementations.

![Kronos find primes](https://i.imgur.com/TlzIKzC.gif)

*Finding prime numbers ([prime.c](https://github.com/SonalPinto/kronos/blob/master/src/icebreaker_lite/prime.c)) with Kronos implemeneted on iCEBreaker*

# Features

  - RV32I_Zicsr_Zifencei compliance tested with [riscv-compliance suite](https://github.com/SonalPinto/riscv-compliance).
  - Optimized for single cycle instruction execution.
  - Native support for misaligned data access.
  - One block lookahead instruction fetch.
  - Direct mode trap handler jumps.

# Todo
- Complete implementation `wfi` instruction and interrupt handling. Only exceptions are handled right now.
- Intense documentation
