# test_trap.S: exceptions and mret on the pipelined core
# results at 0x400 + 4*n, DONE marker last
# build: sw/asm.sh testbenches/test_trap.S
#
# handler records mcause/mepc/mstatus into the slot pointed to by x18,
# then returns to mepc + x19 (x19 = bytes to skip)

.text
.globl _start
_start:
    li   x31, 0x400              # result base
    la   x1, handler
    csrw mtvec, x1
    li   x20, 0                  # handler call count
    li   x19, 4                  # skip 1 instr by default
    csrsi mstatus, 8             # MIE = 1

# --- ecall -----------------------------------------------------------
    # [0] mcause  [1] mepc  [2] mstatus in handler  [3] addr of e1
    addi x18, x31, 0
    la   x5, e1
    sw   x5, 12(x31)
e1: ecall

# --- ebreak ----------------------------------------------------------
    # [4] mcause  [5] mepc  [6] mstatus  [7] addr of e2
    addi x18, x31, 16
    la   x5, e2
    sw   x5, 28(x31)
e2: ebreak

# --- illegal (all zeros) ---------------------------------------------
    # [8] mcause  [9] mepc  [10] mstatus  [11] addr of e3
    addi x18, x31, 32
    la   x5, e3
    sw   x5, 44(x31)
e3: .word 0x00000000

# --- after the returns -----------------------------------------------
    # [12] mstatus after mret: MIE back on
    csrr x6, mstatus
    sw   x6, 48(x31)

# --- illegal R-type must not write rd ---------------------------------
    # [13] x10 unchanged  (0xFEB50533 = bad funct7, rd = x10)
    li   x10, 0x77
    addi x18, x31, 128           # scratch slots [32..34]
    .word 0xFEB50533
    sw   x10, 52(x31)

# --- store right behind a trap must not happen ------------------------
    # [14] still 0: handler skips the ecall AND the sw
    sw   x0, 56(x31)
    li   x5, 0xBAD
    li   x19, 8                  # skip 2 instrs
    addi x18, x31, 128
    ecall
    sw   x5, 56(x31)             # flushed, never runs
    li   x19, 4

# --- div flushed by a trap --------------------------------------------
    # [15] handler's own div result (1000/10 = 100)
    li   x2, 100
    li   x3, 7
    li   x19, 8                  # skip ecall and div
    addi x18, x31, 128
    ecall
    div  x6, x2, x3              # flushed while dividing
    li   x19, 4
    sw   x27, 60(x31)

# --- unknown csr is illegal ------------------------------------------
    # [18] mcause  [19] mepc  [20] addr of e4  [21] rd not written
    addi x18, x31, 72            # handler writes [18], [19], [20]
    li   x11, 0x55
    li   x12, -1
e4: csrrw x11, 0x7C0, x12        # traps, x11 must stay 0x55
    sw   x11, 84(x31)            # [21]
    la   x5, e4
    sw   x5, 80(x31)             # [20] replaces handler's mstatus

# --- done ------------------------------------------------------------
    # [16] handler ran 7 times
    sw   x20, 64(x31)
    # [17] DONE marker
    li   x8, 0xD0E0000D
    sw   x8, 68(x31)
end:
    j    end

# --- trap handler ----------------------------------------------------
handler:
    csrr x22, mcause
    sw   x22, 0(x18)
    csrr x23, mepc
    sw   x23, 4(x18)
    csrr x24, mstatus
    sw   x24, 8(x18)
    li   x25, 1000
    li   x26, 10
    div  x27, x25, x26           # 100, for [15]
    addi x20, x20, 1             # count
    add  x23, x23, x19           # skip trapping instr(s)
    csrw mepc, x23
    mret