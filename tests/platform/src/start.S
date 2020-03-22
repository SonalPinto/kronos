.section .init;
.globl _start;
_start:
    la sp, __stack_pointer$;
    j main;
