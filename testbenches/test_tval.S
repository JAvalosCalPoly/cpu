.section .text
    .globl _start
    .equ RESULTS, 0x400
# [0] mcause, [1] mtval (illegal .word)
# [2] mcause, [3] mtval (csrr from not real csr)
# [4] mcause, [5] mtval (ebreak) [6] ebreak address to compare with mtval
# [7] mcause, [8] mtval (ecall)
# [9] scause, [10] stval (illegal in S mode)
# [60] done marker

_start:
    # setup
    li x31, RESULTS # x31 = results
    li x18, RESULTS # pointer to results
    la t0, m_handler
    csrw mtvec, t0
    la t0, s_handler
    csrw stvec, t0
    la t0, break
    sw t0, 24(x31) # [6] ebreak address
    .word 0xFFFFFFFF # decode illegal
    csrr t1, 0x7C0 # csr not real
    break:
    ebreak
    addi x18, x18, 4 # skip [6]
    ecall

    # drop to S
    li t0, 1 << 2
    csrw medeleg, t0 # delegate illegal instruction to S
    li t0, (1 << 11) | (1 << 7) | (1 << 1)
    csrw mstatus, t0 # MPP = S, MPIE = 1, SIE = 1
    la t0, s_code
    csrw mepc, t0
    mret # priv <- S, pc <- s_code

s_code:
    .word 0xFFFFFFFF # decode illegal
    j s_code

m_handler:
    csrr t0, mcause
    sw t0, 0(x18)
    csrr t0, mtval
    sw t0, 4(x18)
    addi x18, x18, 8
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret

s_handler:
    csrr t0, scause
    sw t0, 36(x31) # [9]
    csrr t0, stval
    sw t0, 40(x31) # [10]
    li t0, 0xD0E0000D
    sw t0, 240(x31) # [60] done
    done:
    j done