.section .text
    .globl _start
    .equ RESULTS, 0x400

_start:
    li x31, RESULTS
    la t0, m_handler
    csrw mtvec, t0

    # [0]-[3]: AMOADD and forwarding tests
    li a0, 0x600
    li t1, 12
    sw t1, 0(a0)
    li t1, 7
    amoadd.w t0, t1, (a0)
    sw t0, 0(x31)
    lw t2, 0(a0)
    sw t2, 4(x31)

    li t1, 5
    amoadd.w x0, t1, (a0)
    lw t2, 0(a0)
    sw t2, 8(x31)

    li t2, 25
    amoswap.w t0, t2, (a0)
    addi t3, t0, 1
    sw t3, 12(x31)

    # [4] AMOAND: 0x604 = 0xC, rs2 = 0xA
    li a0, 0x604
    li t1, 12
    sw t1, 0(a0)
    li t1, 10
    amoand.w t0, t1, (a0)
    lw t2, 0(a0)
    sw t2, 16(x31)

    # [5] AMOOR: 0x608 = 0xC
    li a0, 0x608
    li t1, 12
    sw t1, 0(a0)
    li t1, 2
    amoor.w t0, t1, (a0)
    lw t2, 0(a0)
    sw t2, 20(x31)

    # [6] AMOXOR: 0x60C = 0xC
    li a0, 0x60C
    li t1, 12
    sw t1, 0(a0)
    li t1, 10
    amoxor.w t0, t1, (a0)
    lw t2, 0(a0)
    sw t2, 24(x31)

    # [7] AMOMIN signed: min(5, -1) = -1
    li a0, 0x610
    li t1, 5
    sw t1, 0(a0)
    li t1, -1
    amomin.w t0, t1, (a0)
    lw t2, 0(a0)
    sw t2, 28(x31)

    # [8] AMOMAXU: max unsigned(5, 0xFFFFFFFF) = 0xFFFFFFFF
    li a0, 0x614
    li t1, 5
    sw t1, 0(a0)
    li t1, -1
    amomaxu.w t0, t1, (a0)
    lw t2, 0(a0)
    sw t2, 32(x31)

    # [9]-[12]: LR and successful/failed SC
    li a0, 0x618
    sw x0, 0(a0)
    lr.w t0, (a0)
    li t1, 0x77
    sc.w t2, t1, (a0)
    sw t2, 36(x31)
    lw t3, 0(a0)
    sw t3, 40(x31)

    li t1, 0x99
    sc.w t2, t1, (a0)
    sw t2, 44(x31)
    lw t3, 0(a0)
    sw t3, 48(x31)

    # [13] SC to a different word fails
    lr.w t0, (a0)
    li t1, 0x66
    li a1, 0x61C
    sc.w t2, t1, (a1)
    sw t2, 52(x31)

    # [14] trap clears reservation
    li a0, 0x618
    lr.w t0, (a0)
    li t1, 0x33
    ecall
    sc.w t2, t1, (a0)
    sw t2, 56(x31)

    # [15] LR load-use: LR value + 1 with no intervening instruction
    li a0, 0x618
    lr.w t0, (a0)
    addi t1, t0, 1
    sw t1, 60(x31)

    # [16] AQ/RL bits
    li a0, 0x620
    li t1, 10
    sw t1, 0(a0)
    li t1, 3
    amoadd.w.aqrl t0, t1, (a0)
    lw t2, 0(a0)
    sw t2, 64(x31)

    li t0, 0xD0E0000D
    sw t0, 240(x31)

done:
    j done

m_handler:
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret