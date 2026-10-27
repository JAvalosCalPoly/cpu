/* code at 0, data after */
ENTRY(_start)
SECTIONS {
  . = 0x0;
  .text : { *(.text*) }                 /* code first, always at 0 */
  . = ALIGN(16);
  .data : {                             /* data after code */
    *(.rodata*) *(.data*) *(.sdata*)
    *(.sbss*) *(.bss*) *(COMMON)        /* bss zero filled */
  }
}
