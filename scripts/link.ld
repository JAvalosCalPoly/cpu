/* code at 0, data after */
ENTRY(_start)
SECTIONS {
  . = 0x0;
  .text : { *(.text.start) *(.text*) }  /* startup first, at 0 */
  . = ALIGN(16);
  .data : {                             /* data after code */
    *(.rodata*) *(.data*) *(.sdata*)
  }
  .bss (NOLOAD) : {                     /* zeroed by crt0 */
    __bss_start = .;
    *(.sbss*) *(.bss*) *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  }
}
