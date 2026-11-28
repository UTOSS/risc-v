OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1024K
}

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.init))
    *(.text .text.*)
  } > RAM

  .rodata : ALIGN(4)
  {
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
  } > RAM

  .data : ALIGN(4)
  {
    *(.data .data.*)
    . = ALIGN(4);
    PROVIDE(__global_pointer$ = . + 0x800);
    *(.sdata .sdata.*)
  } > RAM

  .bss (NOLOAD) : ALIGN(4)
  {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM

  PROVIDE(_end = .);
  PROVIDE(end = .);
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
