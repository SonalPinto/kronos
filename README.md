# Kronos RISC-V

Kronos is a 3-stage in-order RISC-V `RV32I_Zicsr_Zifencei` core geared towards FPGA implementations.

![Kronos find primes](https://i.imgur.com/TlzIKzC.gif)

*Finding prime numbers ([sf_prime.c](src/snowflake/sf_prime.c)) with Kronos implemented on iCEBreaker (Demo [Snowflake SoC](https://sonalpinto.github.io/kronos/#/snowflake.md))*


*Arduboy on KRZ SoC* - https://www.youtube.com/watch?v=nveWIcuFHzo


# Features

- RISC-V `RV32I_Zicsr_Zifencei` compliance tested with [riscv-compliance suite](https://sonalpinto.github.io/kronos/#/compliance.md).
  * Complete implementation of the Unprivileged Architecture:
    - RV32I Base Integer ISA, v2.1
    - Zifenci Instruction Fetch Fence extension, v2.0
    - Zicsr Control and Status Register extension, v2.0
  * Partial platform-specific implementation of the Privileged Architecture:
    - Machine-Level ISA, v1.11
- Optimized for single cycle instruction execution.
- DMIPS/MHz of **0.7105** on the KRZ SoC.
- Direct mode trap handler jumps.
- Dual **Wishbone** pipelined master interface for instruction and data.

![Kronos Architecture](https://raw.githubusercontent.com/SonalPinto/kronos/master/docs/_images/kronos_arch.svg)

# News

- Officially listed - https://riscv.org/exchange/cores-socs/
- Kronos makes the news! Article on Hackster.io - [LINK](https://www.hackster.io/news/sonal-pinto-recreates-the-arduboy-using-a-homebrew-risc-v-soc-the-kronos-zero-degree-fc03046a1fdd)
- A group at Taiwan Tech (NTUST) compared their [work on IEEE Access](https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=9200617) against Kronos RISC-V. I am truly honored! I didn't think this day would evere come. As you can see, in single-issue comparisions, Kronos smashes the crowd favorite PicoRV32. A corrective note to add is that the utlization of 5280 is the entire size of the iCE40UP5K, out of which the Kronos takes up 1600 to 2100 LUTs (LUT-4) depending on bells and whistles added.
- [arduboy-pmod v0.1](https://github.com/SonalPinto/arduboy-pmod) pcb has been layed out and fab'd.
- [Native Arduboy port](https://github.com/SonalPinto/krz-arduboy2) is coming along well. Checkit out:

![](https://github.com/SonalPinto/krz-arduboy2/blob/master/docs/arduboy-krz.png)

# Documentation

https://sonalpinto.github.io/kronos/


# Integration 

All of the HDL for the Kronos core is located in the [rtl/core](https://github.com/SonalPinto/kronos/tree/master/rtl/core) directory, with the top design file being [`kronos_core.sv`](rtl/core/kronos_core.sv).

Instantiation template and IO description at [docs/integration](https://sonalpinto.github.io/kronos/#/integration.md)


# KRZ SoC

Kronos Zero Degree (KRZ) is the System-on-Chip packaged in this project to show-off the Kronos core. It is designed for the iCE40UP5K with the following features.

  - 24MHz system clock.
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

![KRZ SoC](https://raw.githubusercontent.com/SonalPinto/kronos/master/docs/_images/krz_soc.svg)

Read More - [KRZ SoC](https://sonalpinto.github.io/kronos/#/krz_soc.md)


# Performance
Kronos running on the KRZ SoC hits a DMIPS/MHz of **0.7105**. making it one of the fastest RISC-V cores to run on the the iCE40UP5K, an FPGA with 5280 LUTs. More details [here](https://sonalpinto.github.io/kronos/#/riscv_tests.md). 

The following single-thread algorithm tests have been ported as well, and the `CPI` (Clocks Per Instructions) is recorded. Yes, they all pass.


| Test | Cycles | Instret | CPI
| -----|--------|---------|----
median   |7972  | 4152    | 1.92
multiply |33442 | 20899   | 1.60
qsort    |220435| 123505  | 1.78
rsort    |291505| 171131  | 1.70
spmv     |3143547| 1947328 | 1.61
towers   |10847 | 6168    | 1.75
vvadd    |14037 | 8026    | 1.74


# Status

- The `kronos_core` is feature complete and RISC-V compliant.
- Kronos: Zero Degree, `KRZ`, a Kronos-powered SoC is ready.
- **Todo**:
  * Make the project yosys/nextpnr-ice40 friendly.
  * Rigorous verification of the core (riscv-torture, riscv-formal, etc).
- **Goal**: Run Arduboy on the iCEBreaker. Custom loader to boot any game from a library on the onboard flash. Interface: 1 oled, 6 buttons and a piezo speaker.


# License

Licensed under Apache License, Version 2.0 (see [LICENSE](LICENSE) for full text).


# Miscellaneous

I initially started this project to build some _street cred_ as a digital designer. The RISC-V ISA and the open-source community that has grown around it is absolutely beautiful, and I want to be a part of it. If it wasn't for the maturity of the riscv-toolchain and the effort the community has put into it, I wouldn't have attempted to build this core. A core can only shine when it runs awesome software. As a bonus, I also get something neat to present during job interviews, instead of just my prosaic grad school work on formal theory.
