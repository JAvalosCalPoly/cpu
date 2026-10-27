#!/bin/bash
# build one riscv-test into a hex: ./build_rvt.sh rv32ui add
suite=$1; t=$2
T=riscv-tests/isa
clang --target=riscv32 -march=rv32im -mno-relax -nostdlib -c \
  -I env -I $T/macros/scalar $T/$suite/$t.S -o hex/$suite-$t.o || exit 1
ld.lld -T link.ld hex/$suite-$t.o -o hex/$suite-$t.elf || exit 1
llvm-objcopy -O binary hex/$suite-$t.elf hex/$suite-$t.bin
od -An -v -t x4 -w4 hex/$suite-$t.bin | tr -d ' ' > hex/$suite-$t.hex
rm hex/$suite-$t.o hex/$suite-$t.bin
