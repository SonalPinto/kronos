# RISC-V Tests

I ported over the official [riscv-tests benchmarks](https://github.com/riscv/riscv-tests/tree/master/benchmarks) into the project - [here](https://github.com/SonalPinto/kronos/tree/master/riscv-tests). The benchmarks are run on the KRZ SoC which Kronos configured with:
- BOOT_ADDR = 0x00
- FAST_BRANCH = 1
- EN_COUNTERS = 1
- EN_COUNTERS64B = 0
- CATCH_ILLEGAL_INSTR = 1
- CATCH_MISALIGNED_JMP = 0
- CATCH_MISALIGNED_LDST = 0


## Dhrystone

Compile the Dhrystone benchmark (v2.2) and load KRZ with it.
```
make krz-riscv-dhrystone_main

iceprog -o 1M output/data/dhrystone_main.krz.bin

```

Terminal Output:
```
Dhrystone Benchmark, Version C, Version 2.2
Program compiled with 'register' attribute
Using rdcycle(), HZ=24000000

Trying 500 runs through Dhrystone:
Final values of the variables used in the benchmark:

Int_Glob:            5
        should be:   5
Bool_Glob:           1
        should be:   1
Ch_1_Glob:           A
        should be:   A
Ch_2_Glob:           B
        should be:   B
Arr_1_Glob[8]:       7
        should be:   7
Arr_2_Glob[8][7]:    510
        should be:   Number_Of_Runs + 10
Ptr_Glob->
  Ptr_Comp:          196384
        should be:   (implementation-dependent)
  Discr:             0
        should be:   0
  Enum_Comp:         2
        should be:   2
  Int_Comp:          17
        should be:   17
  Str_Comp:          DHRYSTONE PROGRAM, SOME STRING
        should be:   DHRYSTONE PROGRAM, SOME STRING
Next_Ptr_Glob->
  Ptr_Comp:          196384
        should be:   (implementation-dependent), same as above
  Discr:             0
        should be:   0
  Enum_Comp:         1
        should be:   1
  Int_Comp:          18
        should be:   18
  Str_Comp:          DHRYSTONE PROGRAM, SOME STRING
        should be:   DHRYSTONE PROGRAM, SOME STRING
Int_1_Loc:           5
        should be:   5
Int_2_Loc:           13
        should be:   13
Int_3_Loc:           7
        should be:   7
Enum_Loc:            1
        should be:   1
Str_1_Loc:           DHRYSTONE PROGRAM, 1'ST STRING
        should be:   DHRYSTONE PROGRAM, 1'ST STRING
Str_2_Loc:           DHRYSTONE PROGRAM, 2'ND STRING
        should be:   DHRYSTONE PROGRAM, 2'ND STRING

Number_Of_Runs = 500, User_Time = 400508, HZ = 24000000 

Microseconds for one run through Dhrystone: 33
Dhrystones per Second:                      30000
Dhrystones per Second per MHz:              1248
cycles: 400541
instret: 222024
CPI (x100): 180

```

From the raw (`User_Time = 400508`), the DMIPS (Dhrystone MIPS) and normalized DMIPS/MHz can be obtained as follows.
```
Dhrystone per second  = (HZ * Number_Of_Runs) / User_Time
                      = 24000000 * 500 / 400508
                      = 29961.948325626454


DMIPS                 = Dhrystone per second / 1757
                      = 17.052901722041238


DMIPS/MHz             = DMIPS / 24
                      = 0.7105375717517183
```

Kronos on the KRZ SoC has a DMIPS/MHz of **0.7105**, making it one of the fastest RISC-V cores to run on the the iCE40UP5K, an FPGA with 5280 LUTs.


## Algorithms

The following single-thread algorithm tests have been ported as well, and the `CPI` (Clocks Per Instructions). Yes, they all pass.

```
make krz-riscv-median_main
make krz-riscv-multiply_main
make krz-riscv-qsort_main
make krz-riscv-rsort
make krz-riscv-spmv_main
make krz-riscv-towers_main
make krz-riscv-vvadd_main

```

| Test | Cycles | Instret | CPI
| -----|--------|---------|----
median   |7972  | 4152    | 1.92
multiply |33442 | 20899   | 1.60
qsort    |220435| 123505  | 1.78
rsort    |291505| 171131  | 1.70
spmv     |3143547| 1947328 | 1.61
towers   |10847 | 6168    | 1.75
vvadd    |14037 | 8026    | 1.74
