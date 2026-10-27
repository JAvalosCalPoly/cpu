/* code at 0, data right after */
SECTIONS {
  . = 0x0;
  .text : { *(.text*) }
  . = ALIGN(16);
  .data : { *(.data*) *(.sdata*) *(.rodata*) *(.bss*) }
}
