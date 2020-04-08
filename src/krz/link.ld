OUTPUT_ARCH( "riscv" )

MEMORY {
    bootrom  (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    ram      (rwx): ORIGIN = 0x00010000, LENGTH = 128K
    system   (rw) : ORIGIN = 0x00800000, LENGTH = 8M
}

ENTRY(_start)

SECTIONS
{
    . = 0x00000000;
    /* gp is set to start of memory for gp relative addressing of static vars*/
    /* gp start is ram origin + 0x800 --- because offset for load/store is 12b */
    /* 12b signed = -2048 to +2047 */
    PROVIDE(_global_pointer = . + 0x800);

    .text (ORIGIN(bootrom)) :
    {
        *(.text)
    } > bootrom

    .data (ORIGIN(ram)) :
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
    PROVIDE(_stack_pointer = ORIGIN(ram) + LENGTH(ram));
}