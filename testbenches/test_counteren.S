# test_counteren.S: mcounteren / scounteren from S and U mode
# results at 0x400 + 4*n, DONE marker at [60]
#
# [0] S rdtime,  mcounteren.TM = 1 -> 1 (no trap)
# [1] S rdcycle, mcounteren.CY = 0 -> 2 (illegal)
# [2] U rdtime,  scounteren.TM = 0 -> 2 (illegal)
# [3] U rdtime,  scounteren.TM = 1 -> 1 (no trap)
# [60] DONE

    .section .text
    .globl _start
    .equ RESULTS, 0x400

_start:                         # M mode
    li x31, RESULTS
    sw x0, 16(x31)          # [4] = 0: no unexpected trap
    li x20, 0               # ecall counter
    la t0, m_handler
    csrw mtvec, t0
    csrwi mcounteren, 2
    # drop to S at s_code
    li t0, 1 << 11              # MPP = S
    csrw mstatus, t0
    la t0, s_code
    csrw mepc, t0
    mret

s_code:                         # S mode
    addi x18, x31, 16
    # [0] allowed
    li t0, 0
    rdtime t0
    sw t0, 0(x31)
    # [1] not allowed: handler writes mcause to (x18)
    addi x18, x31, 4            # x18 -> [1]
    rdcycle t0

    # drop to U at u_code_a
    csrwi scounteren, 0
    li t0, 1 << 8               # SPP bit
    csrc sstatus, t0            # SPP = U
    la t0, u_code_a
    csrw sepc, t0
    sret

u_code_a:                       # U mode, scounteren = 0
    # [2] not allowed
    addi x18, x31, 8            # x18 -> [2]
    rdtime t0
    ecall                       # cause 8: back to M to change scounteren

u_code_b:                       # U mode, scounteren = TM
    # [3] allowed
    addi x18, x31, 16
    li t0, 0
    rdtime t0
    sw t0, 12(x31)
    ecall                       # cause 8 again: finish

m_handler:                      # M mode
    csrr t0, mcause
    li t1, 8
    beq t0, t1, from_u_ecall
    # illegal instruction: log it and skip
    sw t0, 0(x18)               # mcause -> box
    csrr t1, mepc
    addi t1, t1, 4              # skip the trapping instr
    csrw mepc, t1
    mret                        # back to the mode it came from (MPP)

from_u_ecall:
    addi x20, x20, 1
    li t1, 2
    beq x20, t1, finish
    li t0, 2
    csrw scounteren, t0
    la t0, u_code_b
    csrw mepc, t0
    mret

finish:
    li t0, 0xD0E0000D
    sw t0, 240(x31)
done:
    j done
