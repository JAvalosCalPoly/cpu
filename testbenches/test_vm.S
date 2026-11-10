.section .text
    .globl _start
    .equ RESULTS, 0x400
    .equ FAULTS, 0x480
    .equ ROOT, 0x2000            # root table, PPN 2
    .equ L0, 0x3000              # level-0 table, PPN 3
    # PTE flags
    .equ KRW, 0xC7               # D A W R V
    .equ KRO, 0x43               # A R V
    .equ URW, 0xD7               # D A U W R V
    .equ PTR, 0x01               # V only: next table

_start:                      # M mode
    li x31, RESULTS
    li x30, FAULTS           # fault log pointer
    la x5, m_handler
    csrw mtvec, x5
    # data at PA 0x1000
    li x5, 0x1000
    li x6, 0xAAAA
    sw x6, 0(x5)
    # root[0] -> L0, root[512] = mega VA 0x80000000 -> PA 0
    li x5, ROOT
    li x6, (L0 >> 12 << 10) | PTR
    sw x6, 0(x5)
    li x6, KRW
    li x7, ROOT + 0x800      # root[512]
    sw x6, 0(x7)
    # L0[0..3]: identity, kernel RW
    li x5, L0
    li x6, (0 << 10) | KRW
    sw x6, 0(x5)
    li x6, (1 << 10) | KRW
    sw x6, 4(x5)
    li x6, (2 << 10) | KRW
    sw x6, 8(x5)
    li x6, (3 << 10) | KRW
    sw x6, 12(x5)
    # L0[5]: VA 0x5000 -> PA 0x1000, kernel RW
    li x6, (1 << 10) | KRW
    sw x6, 20(x5)
    # L0[6]: VA 0x6000 -> PA 0x1000, kernel read-only
    li x6, (1 << 10) | KRO
    sw x6, 24(x5)
    # L0[7]: invalid
    sw x0, 28(x5)
    # L0[8]: VA 0x8000 -> PA 0x1000, user RW
    li x6, (1 << 10) | URW
    sw x6, 32(x5)
    # satp = Sv32, root PPN 2
    li x5, 0x80000000 | (ROOT >> 12)
    csrw satp, x5
    # mstatus = 1 << 11        # MPP = S
    li x5, 1 << 11
    csrw mstatus, x5
    la x5, s_code
    csrw mepc, x5
    mret                     # -> S at s_code

s_code:                      # S mode, data translated
    # [0] VA 0x5000 -> PA 0x1000
    li x10, 0x5000
    lw x11, 0(x10)
    sw x11, 0(x31) # [0] 0xAAAA
    # [1] alias VA 0x6000 -> same PA
    li x10, 0x5000
    li x11, 0xBBBB
    sw x11, 0(x10)           # write through 0x5000
    li x10, 0x6000
    lw x11, 0(x10)
    sw x11, 4(x31) # [1] 0xBBBB
    # [2] megapage VA 0x80001000 -> PA 0x1000
    li x10, 0x80001000
    lw x11, 0(x10)
    sw x11, 8(x31) # [2] 0xBBBB
    # store to read-only page: fault 15
    li x10, 0x6000
    sw x11, 0(x10)           # fault, skipped
    # load from invalid page: fault 13
    li x10, 0x7000
    lw x11, 0(x10)           # fault, skipped
    # S load from user page, SUM=0: fault 13
    li x10, 0x8000
    lw x11, 0(x10)           # fault, skipped
    # [3] same load with SUM=1
    li x12, 1 << 18
    csrs sstatus, x12
    lw x11, 0(x10)
    sw x11, 12(x31) # [3] 0xBBBB
    # [4] remap VA 0x5000 -> PA 0x3000 (the L0 table), then sfence
    li x10, L0 + 20          # L0[5], identity mapped
    li x11, (3 << 10) | KRW
    sw x11, 0(x10)
    li x10, 0x5000
    lw x11, 0(x10)           # tlb still has old entry
    sw x11, 16(x31) # [4] 0xBBBB (stale)
    sfence.vma x0, x0
    lw x11, 0(x10)           # walks again: L0[0]
    sw x11, 20(x31) # [5] 0x000000C7
    ecall                    # cause 9 -> m_handler

m_handler:                   # M mode
    csrr x5, mcause
    li x6, 9
    beq x5, x6, finish
    # log cause, tval, skip the faulting instr
    sw x5, 0(x30)
    csrr x6, mtval
    sw x6, 4(x30)
    addi x30, x30, 8
    csrr x5, mepc
    addi x5, x5, 4
    csrw mepc, x5
    mret                     # back to S

finish:
    li x26, 0xD0E0000D
    sw x26, 240(x31) # [60] DONE marker
done:
    j done