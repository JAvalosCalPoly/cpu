# test_timer.S: machine timer and timer interrupt on the pipelined core
# results at 0x400 + 4*n, partial sums at 0x600, DONE marker last
# build: scripts/asm.sh testbenches/test_timer.S

.text
.globl _start
_start:
    li   x31, 0x400              # result base
    li   x30, 0x600              # partial sums array
    li   x2, 0x02004000          # mtimecmp
    li   x3, 0x0200BFF8          # mtime

# --- bus: loads/stores reach the timer, not ram ------------------------
    # [0] word 0 before  [1] mtimecmp lo readback  [2] mtimecmp hi  [3] word 0 after
    lw   x5, 0(x0)
    sw   x5, 0(x31)
    li   x5, 0x12345678
    sw   x5, 0(x2)
    li   x5, 0x9ABC
    sw   x5, 4(x2)
    lw   x6, 0(x2)
    sw   x6, 4(x31)
    lw   x6, 4(x2)
    sw   x6, 8(x31)
    lw   x6, 0(x0)
    sw   x6, 12(x31)

    # [4] mtime delta over 4 instrs (1 per clock), load-use on timer data
    lw   x7, 0(x3)
    nop
    nop
    nop
    lw   x8, 0(x3)
    sub  x9, x8, x7
    sw   x9, 16(x31)

# --- interrupt setup ---------------------------------------------------
    # [5] mip before: no irq (mtimecmp far away)
    li   x5, -1
    sw   x5, 4(x2)               # mtimecmp hi = max
    csrr x5, mip
    sw   x5, 20(x31)

    la   x1, handler
    csrw mtvec, x1
    li   x20, 0                  # irq count
    lw   x4, 0(x3)               # now
    addi x4, x4, 60              # fire in ~60 cycles, inside the loop
    sw   x4, 0(x2)               # lo first
    sw   x0, 4(x2)               # then hi = 0
    li   x5, 0x80
    csrs mie, x5                 # MTIE
    csrsi mstatus, 8             # MIE

# --- loop the interrupt lands in ----------------------------------------
    # sum 1..50, each partial sum stored: nothing skipped or doubled
    li   x10, 0                  # sum
    li   x11, 1                  # i
    li   x12, 51
loop:
    add  x10, x10, x11           # sum += i
    slli x13, x11, 2
    add  x13, x13, x30
    sw   x10, 0(x13)             # partial[i] = sum
    addi x11, x11, 1
    bne  x11, x12, loop
loop_end:

    # [6] sum = 1275  [7] irq count = 1
    sw   x10, 24(x31)
    sw   x20, 28(x31)
    # [12] mstatus after mret: MIE back on
    csrr x5, mstatus
    sw   x5, 48(x31)
    # [13] mip after handler moved mtimecmp: clear
    csrr x5, mip
    sw   x5, 52(x31)
    # [14] loop start  [15] loop end, for the mepc range check
    la   x5, loop
    sw   x5, 56(x31)
    la   x5, loop_end
    sw   x5, 60(x31)

# --- done ------------------------------------------------------------
    # [16] DONE marker
    li   x5, 0xD0E0000D
    sw   x5, 64(x31)
end:
    j    end

# --- timer handler -----------------------------------------------------
    # [8] mcause  [9] mepc (no +4)  [10] mstatus  [11] mip in handler
handler:
    csrr x21, mcause
    sw   x21, 32(x31)
    csrr x22, mepc
    sw   x22, 36(x31)
    csrr x23, mstatus
    sw   x23, 40(x31)
    csrr x24, mip
    sw   x24, 44(x31)
    li   x25, -1
    sw   x25, 4(x2)              # mtimecmp hi = max: clears MTIP
    addi x20, x20, 1             # count
    mret                         # back to the interrupted instr