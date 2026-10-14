# test_asm.S
# self-test program: each test stores its answer in a box starting at 0x400
# box n = 0x400 + 4*n, testbench checks them at the end
# 0x600 = spare word for load/store tests

    .text
    .globl _start
_start:
    addi x8, x0, 0x400          # x8 = box 0

# math
    addi x1, x0, 5              # x1 = 5
    addi x2, x0, 7              # x2 = 7
    add  x3, x1, x2             # 5 + 7
    sw   x3, 0(x8)              # [0] 0000000C
    sub  x3, x3, x1             # 12 - 5
    sw   x3, 4(x8)              # [1] 00000007
    sub  x3, x1, x2             # 5 - 7, goes negative
    sw   x3, 8(x8)              # [2] FFFFFFFE
    addi x3, x3, -2046          # big negative imm
    sw   x3, 12(x8)             # [3] FFFFF800

# big numbers
    lui  x4, 0x12345            # top 20 bits
    addi x4, x4, 0x678          # bottom 12 bits
    sw   x4, 16(x8)             # [4] 12345678
    lui  x5, 0x80000
    addi x5, x5, -1             # biggest positive
    sw   x5, 20(x8)             # [5] 7FFFFFFF
here:
    auipc x6, 0                 # own address
    sw   x6, 24(x8)             # [6] 00000044

# logic
    xori x6, x4, -1             # not
    sw   x6, 28(x8)             # [7]2345678 ^ FFFFFFFF = EDCBA987
    andi x7, x4, 0xFF           # keep low byte
    ori  x7, x7, 0x700          # set some bits
    sw   x7, 32(x8)             # [8] 00000778
    xor  x7, x4, x6             # x ^ ~x
    sw   x7, 36(x8)             # [9] FFFFFFFF
    and  x7, x4, x6             # x & ~x
    sw   x7, 40(x8)             # [10] 00000000
    or   x7, x1, x2             # 5 | 7
    sw   x7, 44(x8)             # [11] 00000007

# shifts
    slli x7, x1, 4              # 5 << 4
    sw   x7, 48(x8)             # [12] 00000050
    srli x7, x6, 28             # zeros fill in
    sw   x7, 52(x8)             # [13] 0000000E
    srai x7, x6, 28             # sign fills in
    sw   x7, 56(x8)             # [14] FFFFFFFE
    sll  x7, x1, x2             # 5 << 7
    sw   x7, 60(x8)             # [15] 00000280
    addi x9, x0, -1             # x9 = all ones
    srl  x7, x9, x1             # all ones >> 5
    sw   x7, 64(x8)             # [16] 07FFFFFF
    sra  x7, x6, x1             # negative >>> 5
    sw   x7, 68(x8)             # [17] FF6E5D4C

# compares
    addi x10, x0, -2            # x10 = -2
    slt  x7, x10, x1            # -2 < 5
    sw   x7, 72(x8)             # [18] 00000001
    sltu x7, x10, x1            # unsigned, FFFFFFFE is huge
    sw   x7, 76(x8)             # [19] 00000000
    slti x7, x10, -1            # -2 < -1
    sw   x7, 80(x8)             # [20] 00000001
    sltiu x7, x1, -1            # 5 < FFFFFFFF
    sw   x7, 84(x8)             # [21] 00000001

# loads and stores
    addi x11, x0, 0x600         # x11 = spare word
    lui  x12, 0x80818
    addi x12, x12, -255         # x12 = 80817F01
    sw   x12, 0(x11)            # bytes: 01 7F 81 80
    lb   x7, 2(x11)             # byte 81, signed
    sw   x7, 88(x8)             # [22] FFFFFF81
    lbu  x7, 2(x11)             # byte 81, unsigned
    sw   x7, 92(x8)             # [23] 00000081
    lh   x7, 2(x11)             # half 8081, signed
    sw   x7, 96(x8)             # [24] FFFF8081
    lhu  x7, 2(x11)             # half 8081, unsigned
    sw   x7, 100(x8)            # [25] 00008081
    lw   x7, 0(x11)             # whole word
    addi x7, x7, 1              # used right away
    sw   x7, 104(x8)            # [26] 80817F02
    sb   x1, 1(x11)             # change one byte
    sh   x2, 2(x11)             # change top half
    lw   x7, 0(x11)             # read it back
    sw   x7, 108(x8)            # [27] 00070501

# branches
# taken ones skip a +100, not taken ones add 1, 2, 4
    addi x13, x0, 0             # score = 0
    beq  x1, x1, b1             # taken
    addi x13, x13, 100          # skipped
b1: bne  x1, x1, b2             # not taken
    addi x13, x13, 1
b2: blt  x10, x1, b3            # taken
    addi x13, x13, 100          # skipped
b3: bge  x10, x1, b4            # not taken
    addi x13, x13, 2
b4: bltu x10, x1, b5            # not taken
    addi x13, x13, 4
b5: bgeu x10, x1, b6            # taken
    addi x13, x13, 100          # skipped
b6: sw   x13, 112(x8)           # [28] 00000007

# loop: 10 + 9 + ... + 1
    addi x14, x0, 0             # total
    addi x15, x0, 10            # count
loop:
    add  x14, x14, x15          # total += count
    addi x15, x15, -1           # count--
    bne  x15, x0, loop          # until 0
    sw   x14, 116(x8)           # [29] 00000037 (55)

# function calls
    addi x10, x0, 21
    jal  x1, double             # call
    sw   x10, 120(x8)           # [30] 0000002A (42)
    jal  x1, double             # call again
ret2:
    sw   x10, 124(x8)           # [31] 00000054 (84)
    sw   x1, 128(x8)            # [32] 0000017C (return address)
    jal  x0, after_func         # skip over the function
double:
    add  x10, x10, x10          # x10 * 2
    jalr x0, 0(x1)              # return
after_func:

# mul / div
    addi x16, x0, 6             # x16 = 6
    addi x17, x0, -7            # x17 = -7
    mul  x7, x16, x17           # 6 * -7
    sw   x7, 132(x8)            # [33] FFFFFFD6
    lui  x18, 0x80000           # most negative
    mulh x7, x18, x18           # top half, signed
    sw   x7, 136(x8)            # [34] 40000000
    mulhu x7, x9, x9            # top half, unsigned
    sw   x7, 140(x8)            # [35] FFFFFFFE
    mulhsu x7, x9, x9           # top half, signed * unsigned
    sw   x7, 144(x8)            # [36] FFFFFFFF
    addi x19, x0, -20           # x19 = -20
    div  x7, x19, x16           # -20 / 6, rounds toward 0
    sw   x7, 148(x8)            # [37] FFFFFFFD
    rem  x7, x19, x16           # -20 % 6
    sw   x7, 152(x8)            # [38] FFFFFFFE
    divu x7, x9, x16            # unsigned divide
    sw   x7, 156(x8)            # [39] 2AAAAAAA
    remu x7, x9, x16            # unsigned remainder
    sw   x7, 160(x8)            # [40] 00000003
    div  x7, x16, x0            # divide by 0 :(
    sw   x7, 164(x8)            # [41] FFFFFFFF
    rem  x7, x16, x0            # remainder by 0
    sw   x7, 168(x8)            # [42] 00000006
    div  x7, x18, x9            # overflow
    sw   x7, 172(x8)            # [43] 80000000

# fibonacci, 20 steps
    addi x20, x0, 0             # a = 0
    addi x21, x0, 1             # b = 1
    addi x22, x0, 20            # steps
fib:
    add  x23, x20, x21          # next = a + b
    addi x20, x21, 0            # a = b
    addi x21, x23, 0            # b = next
    addi x22, x22, -1           # steps--
    bne  x22, x0, fib           # until 0
    sw   x20, 176(x8)           # [44] 00001A6D (6765)

# x0 stays 0
    addi x0, x0, 123            # ignored
    sw   x0, 180(x8)            # [45] 00000000

# done
    lui  x7, 0xD0E00
    addi x7, x7, 0x0D           # "DONE"
    sw   x7, 184(x8)            # [46] D0E0000D
end:
    jal  x0, end                # wait here forever