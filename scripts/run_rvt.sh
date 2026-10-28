#!/bin/bash
# build and run riscv-tests: ./run_rvt.sh        (single-cycle)
#                            ./run_rvt.sh pipe   (pipeline)
COMMON="memory.v decoder.v immgen.v 32register.v register.v alu.v addersub.v logics.v shifter.v compare.v multiplier.v divider.v branch_unit.v csr.v"
if [ "$1" = "pipe" ]; then
  iverilog -DPIPE -o sim_rvt testbenches/rvt_tb.v top_pipe.v core_pipe.v $COMMON || exit 1
else
  iverilog -o sim_rvt testbenches/rvt_tb.v top.v core.v $COMMON || exit 1
fi
mkdir -p rvt/hex
for suite in rv32ui rv32um; do
  for f in rvt/riscv-tests/isa/$suite/*.S; do
    t=$(basename $f .S)
    [ "$t" = "fence_i" ] && continue   # needs fence.i
    [ "$t" = "ma_data" ] && continue   # needs misaligned access
    (cd rvt && ./build_rvt.sh $suite $t) || continue
    vvp -n sim_rvt +hex=rvt/hex/$suite-$t.hex | grep -E "PASS|FAIL"
  done
done
