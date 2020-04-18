# Copyright (c) 2020 Sonal Pinto
# SPDX-License-Identifier: Apache-2.0

.section .init;
.globl _start;
_start:
    la gp, _global_pointer;
    la sp, _stack_pointer;
    j main;
