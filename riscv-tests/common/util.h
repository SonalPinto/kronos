// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

#ifndef __UTIL_H
#define __UTIL_H

#include <stdint.h>

#define static_assert(cond) switch(0) { case 0: case !!(long)(cond): ; }

#define read_csr(reg) ({ int __tmp; \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

#define debug_printf printk

void setStats(int enable);
void printStats(void) ;
int verify(int n, const volatile int* test, const int* verify);
int verifyDouble(int n, const volatile double* test, const double* verify);
void printk(const char *fmt, ...);
void delay_us(int count_us);

#endif //__UTIL_H
