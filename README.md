![project status](https://img.shields.io/badge/work-in%20progress-orange)

# Kronos RISC-V

Kronos is a 4-stage in-order RISC-V `RV32I_Zicsr_Zifencei` core geared towards FPGA implementations.

![Kronos find primes](https://i.imgur.com/TlzIKzC.gif)

*Finding prime numbers ([prime.c](https://github.com/SonalPinto/kronos/blob/master/src/snowflake/prime.c)) with Kronos implemeneted on iCEBreaker*


# Features

- RISC-V `RV32I_Zicsr_Zifencei` compliance tested with [riscv-compliance suite](https://github.com/SonalPinto/riscv-compliance).
  * Complete implementation of the Unprivileged Architecture:
    - RV32I Base Integer ISA, v2.1
    - Zifenci Instruction Fetch Fence extension, v2.0
    - Zicsr Control and Status Register extension, v2.0
  * Partial platform-specific implementation of the Privileged Architecture:
    - Machine-Level ISA, v1.11
- Optimized for single cycle instruction execution.
- Native support for misaligned data access.
- Direct mode trap handler jumps.
- Dual **Wishbone** master interface for instruction and data.
 
 
# Documentation

https://sonalpinto.github.io/kronos/

# Status

- The `kronos_core` is feature complete and RISC-V compliant. Pending testing of interrupt and `wfi` functionality. You can start using the core right now!
- Documentation - in perpetual progress
- Kronos-powered ArduinoCore - `icewing` -  platform in progress
- **Goal**: icewing running Arduboy on the iCEBreaker. Custom loader to boot any game from a library on the onboard flash. Interface: 1 oled, 6 buttons and a piezo speaker.

# License

Licensed under Apache License, Version 2.0 (see [LICENSE](https://github.com/SonalPinto/kronos/blob/master/LICENSE) for full text).


# Miscellaneous

I initially started this project to build some _street cred_ as a digital designer. The RISC-V ISA and the open-source community that has grown around it is absolutely beautiful, and I want to be a part of it. If it wasn't for the maturity of the riscv-toolchain and the effort the community has put into it, I wouldn't have attempted to build this core. A core can only shine when it runs awesome software. As a bonus, I also get something neat to present during job interviews, instead of just my prosaic grad school work on formal theory.
