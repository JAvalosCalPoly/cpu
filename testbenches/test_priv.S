.section .text
    .globl _start
    .equ RESULTS, 0x400

_start:
    # set up the handler, then drop to U mode
    li x31, RESULTS # results base
    li x18, RESULTS + 0x10 # handler slots, from [4]
    li x20, 0 # trap counter
    la t0, handler # trap handler address
    csrw mtvec, t0 # traps go to handler
    sw t0, 4(x31) # [1] handler addr, to check mtvec
    li t0, 0 # MPP = U, MIE = 0
    csrw mstatus, t0 # mret will return to U
    la t0, user # user program address
    csrw mepc, t0 # mret jumps here
    mret # priv <- U, pc <- user

user:
    ecall # trap 0: mcause 8
    li t1, 0x55
    csrr t1, mstatus # trap 1: mcause 2, t1 kept
    sw t1, 0(x31) # [0] t1 should still be 0x55
    csrw mtvec, zero # trap 2: mcause 2, mtvec kept
    mret # trap 3: mcause 2, stays in U
    ecall # trap 4: mcause 8 again, still in U

handler:
    csrr x21, mcause
    csrr x22, mstatus
    csrr x23, mtvec
    sw x21, 0(x18) # mcause
    sw x22, 4(x18) # mstatus
    sw x23, 8(x18) # mtvec
    addi x18, x18, 12 # next slot
    addi x20, x20, 1 # count traps
    # add 4 to mepc
    csrr x24, mepc
    addi x24, x24, 4 # skip the trapping instr
    csrw mepc, x24
    # if it is the 5th trap store done and spin
    li x25, 5
    beq x20, x25, done
    mret # back to U

done:
    li x26, 0xD0E0000D
    sw x26, 0xF0(x31) # [60] DONE marker
    spin:
    j spin