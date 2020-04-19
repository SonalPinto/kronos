# Kronos RISC-V

Kronos is a 4-stage in-order RISC-V `RV32I_Zicsr_Zifencei` core geared towards FPGA implementations.

![Kronos find primes](https://i.imgur.com/TlzIKzC.gif)

*Finding prime numbers ([sf_prime.c](src/snowflake/sf_prime.c)) with Kronos implemented on iCEBreaker (Demo [Snowflake SoC](https://sonalpinto.github.io/kronos/#/snowflake.md))*


# Features

- RISC-V `RV32I_Zicsr_Zifencei` compliance tested with [riscv-compliance suite](https://sonalpinto.github.io/kronos/#/compliance.md).
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

![Kronos Architecture](docs/_images/kronos_arch.svg)
 
 
# Documentation

https://sonalpinto.github.io/kronos/


# Integration 

All of the HDL for the Kronos core is located in the [rtl/core](https://github.com/SonalPinto/kronos/tree/master/rtl/core) directory, with the top design file being [`kronos_core.sv`](rtl/core/kronos_core.sv).

Instantiation template and IO description at [docs/integration](https://sonalpinto.github.io/kronos/#/integration.md)


# KRZ SoC

Kronos Zero Degree (KRZ) is the System-on-Chip packaged in this project to show-off the Kronos core. It is designed for the iCE40UP5K with the following features.

  - 128KB of RAM as 2 contiguous banks of 64KB.
  - 1KB Bootrom for loading program from flash to RAM.
  - UART TX with 128B buffer.
      - Configurable baud rate
  - SPI Master with 256B RX/TX buffers.
      - Configurable SPI Mode and rate.
      - Max 12MHz.
  - 12 Bidirectional configurable GPIO.
      - Debounced inputs.
  - General Purpose registers

![KRZ SoC](_images/krz_soc.svg)

Read More - [KRZ SoC](https://sonalpinto.github.io/kronos/#/krz_soc.md)


# Status

- The `kronos_core` is feature complete and RISC-V compliant.
- Make the project yosys/nextpnr-ice40 friendly.
- Kronos: Zero Degree, `KRZ`, a Kronos-powered SoC is ready (pending features needed for the Arduboy project).
- Todo: rigorous verification of the core (riscv-torture, riscv-formal, etc).
- **Goal**: Run Arduboy on the iCEBreaker. Custom loader to boot any game from a library on the onboard flash. Interface: 1 oled, 6 buttons and a piezo speaker.


# License

Licensed under Apache License, Version 2.0 (see [LICENSE](LICENSE) for full text).


# Miscellaneous

I initially started this project to build some _street cred_ as a digital designer. The RISC-V ISA and the open-source community that has grown around it is absolutely beautiful, and I want to be a part of it. If it wasn't for the maturity of the riscv-toolchain and the effort the community has put into it, I wouldn't have attempted to build this core. A core can only shine when it runs awesome software. As a bonus, I also get something neat to present during job interviews, instead of just my prosaic grad school work on formal theory.
