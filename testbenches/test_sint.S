.section .text
    .globl _start
    .equ RESULTS, 0x400 # [0] mcause, [1] mstatus, [2] scause, [3] sstatus, [4] sip, [60] DONE
    .equ MTIMECMP, 0x02004000
    .equ MTIME, 0x0200BFF8
    

_start:
    # set up
    li x31, RESULTS
    la t0, m_handler
    csrw mtvec, t0
    la t0, s_handler
    csrw stvec, t0
    li t0, 1 << 5
    csrw mideleg, t0
    li t1, 1 << 7
    li t2, 1 << 5
    or t0, t1, t2
    csrw mie, t0 # enable M and S timer interrupts
    # arm M timer
    li t1, MTIMECMP
    li t2, MTIME
    lw t3, 0(t2) # read MTIME low
    lw t4, 4(t2) # read MTIME high
    addi t3, t3, 0x100
    li t5, -1
    sw t5, 4(t1) # write MTIMECMP high
    sw t3, 0(t1) # write MTIMECMP low
    sw t4, 4(t1)
    # drop to S
    li t0, (1 << 11) | (1 << 7) | (1 << 1)
    csrw mstatus, t0 # MPP = S, SIE = 1, MPIE = 1
    la t0, s_code
    csrw mepc, t0
    mret # priv <- S, pc <- s_code
    
s_code:
    # spin waiting for interrupt
    nop
    nop
    j s_code

m_handler:
    # record mcause and mstatus
    csrr t0, mcause
    sw t0, 0(x31)
    csrr t0, mstatus
    sw t0, 4(x31)
    # silence timer
    li t1, MTIMECMP
    li t5, -1
    sw t5, 4(t1) # high so it won't fire again
    # hand off to S
    li t0, 1 << 5
    csrs mip, t0 # raise STIP
    mret # priv <- S, pc <- mepc
s_handler:
    # record scause, sip, and sstatus
    csrr t0, scause
    sw t0, 8(x31)
    csrr t0, sstatus
    sw t0, 12(x31)
    csrr t0, sip
    sw t0, 16(x31)
    # mark as done
    li t0, 0xD0E0000D
    sw t0, 240(x31)
done:
    j done

