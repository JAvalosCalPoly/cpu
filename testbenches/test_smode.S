.section .text
    .globl _start
    .equ RESULTS, 0x400

_start:                      # M mode
    # x31 = RESULTS
    li x31, RESULTS
    # mtvec  = m_handler
    la x3, m_handler
    csrw mtvec, x3
    # stvec  = s_handler
    la x3, s_handler
    csrw stvec, x3
    # medeleg = 1 << 8         # ecall from U -> S
    li x3, 1 << 8
    csrw medeleg, x3
    # [1] = address of u_ecall
    la x3, u_ecall
    sw x3, 4(x31)
    # mstatus = 1 << 11        # MPP = 01 (S), everything else 0
    li x3, 1 << 11
    csrw mstatus, x3
    # mepc = s_code
    la x3, s_code
    csrw mepc, x3
    mret                     # -> S at s_code

s_code:                      # S mode   
    li x3, 0x5C5C # test value
    csrw sscratch, x3        # S csr works in S
    csrr x3, sscratch
    sw x3, 0(x31)
    # sstatus: clear bit 8     # SPP = U
    li x4, 1 << 8 # SPP bit
    csrc sstatus, x4 # SPP = U
    la x3, u_code
    csrw sepc, x3
    sret                     # -> U at u_code

u_code:                      # U mode
u_ecall:
    ecall                    # cause 8, delegated -> s_handler
spin_u:
    j spin_u                 # should never get here

s_handler:                   # S mode (trap from U)
    # [2] = scause
    # [3] = sepc
    # [4] = sstatus
    # [5] = address of s_ecall
    csrr x21, scause
    csrr x22, sepc
    csrr x23, sstatus
    sw x21, 8(x31) # [2] scause
    sw x22, 12(x31) # [3] sepc
    sw x23, 16(x31) # [4] sstatus
    la x3, s_ecall
    sw x3, 20(x31) # [5] s_ecall addr
s_ecall:
    ecall                    # cause 9, not delegated -> m_handler
spin_s:
    j spin_s                 # should never get here

m_handler:                   # M mode (trap from S)
    # [6] = mcause
    # [7] = mepc
    # [8] = mstatus
    # [60] = 0xD0E0000D
    csrr x21, mcause
    csrr x22, mepc
    csrr x23, mstatus
    sw x21, 24(x31) # [6] mcause
    sw x22, 28(x31) # [7] mepc
    sw x23, 32(x31) # [8] mstatus
    li x26, 0xD0E0000D
    sw x26, 240(x31) # [60] DONE marker
done:
    j done