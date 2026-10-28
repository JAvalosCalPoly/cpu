# test_csr.S: Zicsr test for the pipelined core
# one result word per test at 0x400 + 4*n, DONE marker last
# build: ./asm.sh test_csr.S

.text
.globl _start
_start:
    li   x31, 0x400              # result base

# --- write / read ---------------------------------------------------
    # [0] csrw then csrr straight after (back-to-back csr)
    li   x1, 0x12345678
    csrw mscratch, x1
    csrr x2, mscratch            # x2 = 12345678
    sw   x2, 0(x31)              # csr-use: sw needs x2

    # [1] csrrw swap: old value to rd
    li   x4, 0xAAAA
    csrrw x3, mscratch, x4       # x3 = 12345678, mscratch = AAAA
    sw   x3, 4(x31)

    # [2] new value after swap
    csrr x5, mscratch            # x5 = AAAA
    sw   x5, 8(x31)

# --- set / clear with a register mask -------------------------------
    # [3] csrrs: old value to rd
    li   x7, 0x0F0F
    csrrs x6, mscratch, x7       # x6 = AAAA, mscratch = AFAF
    sw   x6, 12(x31)

    # [4] value after set
    csrr x6, mscratch            # x6 = AFAF
    sw   x6, 16(x31)

    # [5] csrrc
    li   x9, 0x00FF
    csrrc x8, mscratch, x9       # mscratch = AF00
    csrr x8, mscratch
    sw   x8, 20(x31)

# --- immediate forms on mstatus (only bits 7, 3 exist) --------------
    # [6] csrsi sets MIE
    csrsi mstatus, 8
    csrr x10, mstatus            # x10 = 08
    sw   x10, 24(x31)

    # [7] write all ones, only MPIE + MIE stick
    li   x11, -1
    csrw mstatus, x11
    csrr x10, mstatus            # x10 = 88
    sw   x10, 28(x31)

    # [8] csrrci: old value to rd, clears MIE
    csrrci x10, mstatus, 8       # x10 = 88, mstatus = 80
    sw   x10, 32(x31)

    # [9] value after clear
    csrr x10, mstatus            # x10 = 80
    sw   x10, 36(x31)

# --- mepc low bits ---------------------------------------------------
    # [10] mepc[1:0] always 0
    li   x12, 0x1003
    csrw mepc, x12
    csrr x13, mepc               # x13 = 1000
    sw   x13, 40(x31)

# --- hazards ---------------------------------------------------------
    # [11] csr-use: csrr then addi needs it right away
    csrr x14, mscratch           # AF00
    addi x15, x14, 1             # stall, x15 = AF01
    sw   x15, 44(x31)

    # [12] forward into csr src: li then csrw right away
    li   x16, 0x55
    csrw mscratch, x16           # src forwarded from EX/MEM
    csrr x17, mscratch           # x17 = 55
    sw   x17, 48(x31)

    # [13] one instr gap: MEM/WB forward
    csrr x18, mscratch           # 55
    addi x0, x0, 0               # gap
    add  x19, x18, x18           # x19 = AA
    sw   x19, 52(x31)

# --- x0 rules (table 21) --------------------------------------------
    # [14] csrrs rs1=x0: read only, no write
    li   x20, 0x77
    csrw mscratch, x20
    csrrs x21, mscratch, x0      # x21 = 77
    sw   x21, 56(x31)

    # [15] still 77 after the read
    csrr x21, mscratch
    sw   x21, 60(x31)

    # [16] csrrw rs1=x0 writes zero
    csrrw x0, mscratch, x0
    csrr x22, mscratch           # x22 = 0
    sw   x22, 64(x31)

    # [17] csrrwi: uimm zero-extended
    csrrwi x0, mscratch, 31
    csrr x23, mscratch           # x23 = 1F
    sw   x23, 68(x31)

# --- other csrs ------------------------------------------------------
    # [18] mtvec
    li   x24, 0x100
    csrw mtvec, x24
    csrr x25, mtvec              # x25 = 100
    sw   x25, 72(x31)

    # [19] mcause
    li   x24, 11
    csrw mcause, x24
    csrr x25, mcause             # x25 = B
    sw   x25, 76(x31)

    # [20] moved to test_trap.S (unknown csr traps now)

# --- done ------------------------------------------------------------
    # [21] DONE marker
    li   x28, 0xD0E0000D
    sw   x28, 84(x31)

end:
    j    end