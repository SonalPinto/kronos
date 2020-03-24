.section .init;
.globl _start;
_start:
    la gp, _global_pointer;
    la sp, _stack_pointer;
    j main;
