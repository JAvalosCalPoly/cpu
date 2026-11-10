.section .text
    .globl _start
    .equ RESULTS, 0x400

_start:                      # M mode
    # x31 = RESULTS
    li x31, RESULTS
    # mtvec = m_handler
    la x3, m_handler
    csrw mtvec, x3
    sw x0, 8(x31) # [2] = 0, U store must not change it
    sfence.vma x0, x0        # M: no trap
    li x3, 0x11
    sw x3, 0(x31) # [0] past M sfence
    # mstatus = 1 << 11        # MPP = 01 (S)
    li x3, 1 << 11
    csrw mstatus, x3
    la x3, s_code
    csrw mepc, x3
    mret                     # -> S at s_code

s_code:                      # S mode
    sfence.vma a0, a1        # S: no trap
    li x3, 0x22
    sw x3, 4(x31) # [1] past S sfence
    # sstatus: clear bit 8     # SPP = U
    li x4, 1 << 8 # SPP bit
    csrc sstatus, x4 # SPP = U
    la x3, u_code
    csrw sepc, x3
    sret                     # -> U at u_code

u_code:                      # U mode
u_sfence:
    sfence.vma x0, x0        # U: illegal -> m_handler
    li x3, 0xBAD
    sw x3, 8(x31) # [2] never runs
spin_u:
    j spin_u                 # should never get here

m_handler:                   # M mode (trap from U)
    # [3] = mcause
    # [4] = mepc
    # [5] = mtval
    # [6] = address of u_sfence
    # [60] = 0xD0E0000D
    csrr x21, mcause
    csrr x22, mepc
    csrr x23, mtval
    sw x21, 12(x31) # [3] mcause
    sw x22, 16(x31) # [4] mepc
    sw x23, 20(x31) # [5] mtval
    la x3, u_sfence
    sw x3, 24(x31) # [6] u_sfence addr
    li x26, 0xD0E0000D
    sw x26, 240(x31) # [60] DONE marker
done:
    j done