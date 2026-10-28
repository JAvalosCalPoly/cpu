#!/bin/bash
# turns a .S file into a .hex file


name=${1%.S}    # .S removed if it's there

llvm-mc -triple=riscv32 -mattr=+m+zicsr,-relax -filetype=obj $name.S -o $name.o   # assemble
llvm-objcopy -O binary -j .text $name.o $name.bin                          # keep only the machine code
od -An -v -t x4 -w4 $name.bin | tr -d ' ' > $name.hex                      # one 32-bit word per line
llvm-objdump -d -M no-aliases -M numeric $name.o > $name.lst               # readable listing
rm $name.o $name.bin
echo "$name.hex: $(wc -l < $name.hex) instructions"