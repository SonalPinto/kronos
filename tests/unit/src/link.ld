OUTPUT_ARCH( "riscv" )

ENTRY(main)

SECTIONS
{
  . = 0x00000000;
  .text : { *(.text) }

  . = 0x000003C0;
  .data : { *(.data) }
}
