#!/usr/bin/env fish
# runs every test: scripts/run_tests.fish   (from the cpu folder)
# add "rvt" to also run riscv-tests: scripts/run_tests.fish rvt

mkdir -p build
set fails 0

# programs: assemble .S -> .hex
for s in test_asm test_csr test_trap test_timer test_uart
    if not scripts/asm.sh testbenches/$s.S > /dev/null
        echo "ASM FAIL: $s"
        set fails (math $fails + 1)
    end
end

# name testbench pairs
set tests \
    csr_tb      csr_tb \
    timer_tb    timer_tb \
    uart_tb     uart_tb \
    divider_tb  divider_tb \
    asm         top_pipe_asm_tb \
    hazards     top_pipe_tb \
    csr         top_pipe_csr_tb \
    trap        top_pipe_trap_tb \
    timer       top_pipe_timer_tb \
    uart        top_pipe_uart_tb

for i in (seq 1 2 (count $tests))
    set name $tests[$i]
    set tb $tests[(math $i + 1)]
    if not iverilog -o build/$name -y rtl -y rtl/single_cycle testbenches/$tb.v 2> build/$name.err
        echo "COMPILE FAIL: $name (see build/$name.err)"
        set fails (math $fails + 1)
        continue
    end
    set out (vvp -n build/$name 2>&1)
    # summary line + cycle count
    set summary (string match -r -- '.*(?:passed|All tests|^DONE).*' $out | string join ' ')
    set failed (string match -r -- '.*(?:FAIL|Error|[1-9][0-9]* (?:tests )?failed).*' $out)
    if test (count $failed) -gt 0
        echo "FAIL  $name: $summary"
        for line in $failed[1..5]
            echo "      $line"
        end
        set fails (math $fails + 1)
    else
        echo "ok    $name: $summary"
    end
end

# riscv-tests (slower)
if test "$argv[1]" = rvt
    if not iverilog -DPIPE -o build/sim_rvt -y rtl testbenches/rvt_tb.v
        echo "COMPILE FAIL: rvt"
        exit 1
    end
    set pass 0
    set total 0
    for h in rvt/hex/*.hex
        set total (math $total + 1)
        if vvp -n build/sim_rvt +hex=$h | string match -q '*PASS*'
            set pass (math $pass + 1)
        else
            echo "FAIL  rvt: $h"
        end
    end
    echo "rvt: $pass/$total"
    test $pass -ne $total; and set fails (math $fails + 1)
end

echo
if test $fails -eq 0
    echo "ALL PASSED"
else
    echo "$fails FAILED"
end
exit $fails