#!/bin/bash
# turns a .S file into a .hex file

name=${1%.S}                 # .S removed if it's there
ld=$(dirname "$0")/link.ld   # link.ld next to this script

llvm-mc -triple=riscv32 -mattr=+m,+zicsr,-relax -filetype=obj $name.S -o $name.o || exit 1  # assemble
ld.lld -T $ld $name.o -o $name.elf || exit 1                                              # link, real addresses
llvm-objcopy -O binary $name.elf $name.bin                                                # code + data
od -An -v -t x4 -w4 $name.bin | tr -d ' ' > $name.hex                                     # one 32-bit word per line
llvm-objdump -d -M no-aliases -M numeric $name.elf > $name.lst                            # readable listing
llvm-objdump -s -j .data $name.elf >> $name.lst 2>/dev/null                               # data dump
llvm-nm -n $name.elf | grep -v -e ' [aN] ' -e ' \.L' >> $name.lst                                      # label addresses
rm $name.o $name.bin
echo "$name.hex: $(wc -l < $name.hex) words"