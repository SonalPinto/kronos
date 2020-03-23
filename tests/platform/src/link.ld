OUTPUT_ARCH( "riscv" )

MEMORY {
    ram  (rwx): ORIGIN = 0x00000000, LENGTH = 0x00001000
    gpio (rw) : ORIGIN = 0x00001000, LENGTH = 0x00000100
}

ENTRY(_start)

SECTIONS
{
    . = 0x00000000;
    /* gp is set to start of memory for gp relative addressing of static vars*/
    /* gp start is ram origin + 0x800 --- because offset for load/store is 12b */
    /* 12b signed = -2048 to +2047 */
    PROVIDE(__global_pointer$ = . + 0x800);

    .init ORIGIN(ram) : 
    { 
        *(.init)
    } > ram

    .text (ORIGIN(ram) + 0x100) :
    { 
        *(.text)
    } > ram

    .data (ORIGIN(ram) + 0x400) :
    {
        PROVIDE(_sdata = .);
        *(.result)
        *(.data)
        PROVIDE(_edata = .);
    } > ram

    .bss :
    {
        *(.bss)
    } > ram

    /* Stack Pointer - End of Memory */
    PROVIDE(__stack_pointer$ = ORIGIN(ram) + LENGTH(ram));
}