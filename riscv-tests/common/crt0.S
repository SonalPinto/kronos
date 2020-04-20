# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

.global _start
.global trap_handler

.section .init

_start:
  li  x1, 0
  li  x2, 0
  li  x3, 0
  li  x4, 0
  li  x5, 0
  li  x6, 0
  li  x7, 0
  li  x8, 0
  li  x9, 0
  li  x10,0
  li  x11,0
  li  x12,0
  li  x13,0
  li  x14,0
  li  x15,0
  li  x16,0
  li  x17,0
  li  x18,0
  li  x19,0
  li  x20,0
  li  x21,0
  li  x22,0
  li  x23,0
  li  x24,0
  li  x25,0
  li  x26,0
  li  x27,0
  li  x28,0
  li  x29,0
  li  x30,0
  li  x31,0
  j crt_main

trap_entry:
  sw x1,   -1*4(sp)
  sw x5,   -2*4(sp)
  sw x6,   -3*4(sp)
  sw x7,   -4*4(sp)
  sw x10,  -5*4(sp)
  sw x11,  -6*4(sp)
  sw x12,  -7*4(sp)
  sw x13,  -8*4(sp)
  sw x14,  -9*4(sp)
  sw x15, -10*4(sp)
  sw x16, -11*4(sp)
  sw x17, -12*4(sp)
  sw x28, -13*4(sp)
  sw x29, -14*4(sp)
  sw x30, -15*4(sp)
  sw x31, -16*4(sp)
  addi sp,sp,-16*4
  csrrc a0, mcause, zero
  csrrc a1, mtval, zero
  csrrc a2, mepc, zero
  call trap_handler
  lw x1 , 15*4(sp)
  lw x5,  14*4(sp)
  lw x6,  13*4(sp)
  lw x7,  12*4(sp)
  lw x10, 11*4(sp)
  lw x11, 10*4(sp)
  lw x12,  9*4(sp)
  lw x13,  8*4(sp)
  lw x14,  7*4(sp)
  lw x15,  6*4(sp)
  lw x16,  5*4(sp)
  lw x17,  4*4(sp)
  lw x28,  3*4(sp)
  lw x29,  2*4(sp)
  lw x30,  1*4(sp)
  lw x31,  0*4(sp)
  addi sp,sp,16*4
  mret

crt_main:
  la gp, _global_pointer
  la sp, _stack_pointer

  la t0, trap_entry
  csrw mtvec, t0

  la t0, _sbss
  la t1, _ebss
1:
  beq t0, t1, 2f 
  sw zero, 0(t0)
  addi t0, t0, 4
  j 1b
2:
  call main

  j 1b
