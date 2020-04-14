OUTPUT_ARCH( "riscv" )

MEMORY {
    bootrom  (rx) : ORIGIN = 0x00000000, LENGTH = 1K
    ram      (rwx): ORIGIN = 0x00010000, LENGTH = 128K
    system   (rw) : ORIGIN = 0x00800000, LENGTH = 8M
}

ENTRY(_start)

SECTIONS
{
    .text (ORIGIN(ram)) :
    {
        *(.text)
        *(.rodata)
        PROVIDE(_etext = .);
    } > ram

    .data : ALIGN(4)
    {
        . = ALIGN(4);

        PROVIDE(_global_pointer = . + 0x800);

        PROVIDE(_sdata = .);
        *(.data)
        . = ALIGN(4);
        PROVIDE(_edata = .);
    } > ram

    .bss (NOLOAD) : ALIGN(4)
    {   
         . = ALIGN(4);
        PROVIDE(_sbss = .);
        *(.bss)
        *(COMMON)
         . = ALIGN(4);
        PROVIDE(_ebss = .);
    } > ram

    /* Stack Pointer - End of Memory */
    PROVIDE(_stack_pointer = ORIGIN(ram) + LENGTH(ram));
}