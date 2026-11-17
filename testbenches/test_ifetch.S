.section .text
    .globl _start
    .equ RESULTS, 0x400
    .equ LOG, 0x480              # fault log: cause, tval, epc
    .equ ROOT, 0x2000            # root table, PPN 2
    .equ L0, 0x3000              # level-0 table, PPN 3
    .equ VBASE, 0x80000000       # S code runs here (megapage)
    # PTE flags
    .equ PTR, 0x01               # V: points to next table
    .equ KRWX, 0xCF              # D A X W R V
    .equ KRW, 0xC7               # D A W R V
    .equ KRX, 0xCB               # D A X R V
    .equ KR, 0x43                # A R V (no X)
# [0] auipc in S (pc is virtual)
# [1] call VA 0x5300 -> stub A (0x11)
# [2] remap, no sfence -> stale itlb (0x11)
# [3] after sfence -> stub B (0x22)
# [4] VA of u_code
# log: [0..2] no-X fetch, [3..5] U fetch of kernel page
# [60] done marker

_start:
    # setup
    li x31, RESULTS # x31 = results
    li x30, LOG # x30 = fault log pointer
    la t0, m_handler
    csrw mtvec, t0
    # stub A at PA 0x1300
    li t0, 0x1300
    li t1, 0x01100513 # li a0, 0x11
    sw t1, 0(t0)
    li t1, 0x00008067 # ret
    sw t1, 4(t0)
    # root table
    li t0, ROOT
    li t1, (L0 >> 12 << 10) | PTR
    sw t1, 0(t0) # root[0] -> L0
    li t1, KRWX
    li t2, ROOT + 0x800
    sw t1, 0(t2) # root[512]: VA 0x80000000 -> PA 0 (mega)
    # L0 table
    li t0, L0
    li t1, (0 << 10) | KRWX
    sw t1, 0(t0) # L0[0]: VA 0x0000 -> PA 0x0000
    li t1, (1 << 10) | KR
    sw t1, 4(t0) # L0[1]: VA 0x1000 -> PA 0x1000, no X
    li t1, (3 << 10) | KRW
    sw t1, 12(t0) # L0[3]: VA 0x3000 -> PA 0x3000 (edit L0 from S)
    li t1, (1 << 10) | KRX
    sw t1, 20(t0) # L0[5]: VA 0x5000 -> PA 0x1000 (stub A)
    # drop to S at the VA of s_code
    li t0, 0x80000000 | (ROOT >> 12)
    csrw satp, t0 # Sv32 on (M ignores it)
    li t0, 1 << 11
    csrw mstatus, t0 # MPP = S
    la t0, s_code
    li t1, VBASE
    add t0, t0, t1 # VA = PA + 0x80000000
    csrw mepc, t0
    mret # priv <- S, pc <- VA of s_code

s_code:
    auipc x10, 0
    sw x10, 0(x31) # [0] pc is 0x8000xxxx
    # call stub A through VA 0x5300
    li x12, 0x5300
    jalr ra, 0(x12)
    sw a0, 4(x31) # [1] 0x11
    # remap L0[5] -> PA 0x0000 (stub B), no sfence yet
    li x12, L0 + 20
    li x13, (0 << 10) | KRX
    sw x13, 0(x12)
    li x12, 0x5300
    jalr ra, 0(x12)
    sw a0, 8(x31) # [2] still 0x11, itlb is stale
    sfence.vma x0, x0
    jalr ra, 0(x12)
    sw a0, 12(x31) # [3] 0x22, walked again
    # fetch from a page without X
    la x29, resume1 # where the handler sends us back
    li x12, 0x1300
    jalr ra, 0(x12) # cause 12
resume1:
    # U mode fetch from a kernel page
    la x29, resume2
    la x12, u_code
    sw x12, 16(x31) # [4] VA of u_code
    csrw sepc, x12
    li x12, 1 << 8
    csrc sstatus, x12 # SPP = U
    sret # priv <- U, pc <- u_code
u_code:
    nop # never runs: U can't fetch a kernel page
resume2:
    ecall # cause 9 -> done

m_handler:
    csrr t0, mcause
    li t1, 9
    beq t0, t1, finish
    # log the fetch fault
    sw t0, 0(x30) # cause
    csrr t1, mtval
    sw t1, 4(x30) # tval
    csrr t1, mepc
    sw t1, 8(x30) # epc
    addi x30, x30, 12
    # back to S at the resume address
    csrw mepc, x29
    li t0, 1 << 11
    csrs mstatus, t0 # MPP = S
    mret

finish:
    li t0, 0xD0E0000D
    sw t0, 240(x31) # [60] done marker
done:
    j done

    .org 0x300
stub_b:
    li a0, 0x22
    ret