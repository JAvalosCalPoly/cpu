# To test the core_pipe.v module
# this programs will run with no hazrd handling
# since it is not implemented yet.
# 3 nops between writes and reads to the same register
# 2 nopes between branches and jumps
# array of 6 words at 0x00000600: 7, -3, 12, 0, 25, -8
# answers in boxes at 0x00000400 + 4x
#
# [0] sum              00000021
# [1] max (signed)     00000019
# [2] min (signed)     FFFFFFF8
# [3] negatives        00000002
# [4] max (unsigned)   FFFFFFFD
# [5] product (no 0s)  0000C4E0
# [6] sum / 6          00000005
# [7] sum % 6          00000003
# [8] gcd(48, 18)      00000006
# [9] DONE             D0E0000D
    .equ ARRAY, 0x600
    .text
    .globl _start
_start:
    addi x8, x0, 0x400 # x8 is box 0
    addi x9, x0, ARRAY # array pointer
# sum
    addi x18, x0, 6 # counter
    addi x12, x0, 0 # sum
    nop
sum_loop:
    lw x5, 0(x9)
    addi x18, x18, -1 # counter--
    addi x9, x9, 4 # array pointer++
    nop # wait for lw
    add x12, x12, x5 # sum += array[i]
    bne x18, x0, sum_loop
    nop
    nop # wait for branch target
    sw x12, 0(x8) # store sum in box 0
    addi x9, x0, ARRAY # array pointer reset
# max (signed)
    addi x18, x0, 6 # counter
    lui x13, 0x80000 # max
    nop # wait for x9
max_loop: # if x > max, max = x
    lw x5, 0(x9)
    addi x18, x18, -1 # counter--
    addi x9, x9, 4 # array pointer++
    nop # wait for lw
    bge x13, x5, max_skip # if max >= x, skip
    nop
    nop # wait for branch target
    add x13, x0, x5 # max = x
max_skip:
    bne x18, x0, max_loop
    nop
    nop # wait for branch target
    sw x13, 4(x8) # store max in box 1
    addi x9, x0, ARRAY # array pointer reset

# min (signed)
    lui x14, 0x80000 # min
    addi x18, x0, 6 # counter
    nop # wait for x9
    nop
    addi x14, x14, -1 # min = 0x7FFFFFFF
min_loop: # if x < min, min = x
    lw x5, 0(x9)
    addi x18, x18, -1 # counter--
    addi x9, x9, 4 # array pointer++
    nop # wait for lw
    bge x5, x14, min_skip # if x >= min, skip
    nop
    nop # wait for branch target
    add x14, x0, x5 # min = x
min_skip:
    bne x18, x0, min_loop
    nop
    nop # wait for branch target
    sw x14, 8(x8) # store min in box 1
    addi x9, x0, ARRAY # array pointer reset

# negatives
# neg = 0, loop, if x < 0, neg++, counter--
    addi x15, x0, 0 # neg
    addi x18, x0, 6 # counter
    nop
    nop
neg_loop:
    lw x5, 0(x9)
    addi x18, x18, -1 # counter--
    addi x9, x9, 4 # array pointer++
    nop # wait for lw
    bge x5, x0, neg_skip # if x >= 0, skip
    nop
    nop # wait
    addi x15, x15, 1 # neg++
neg_skip:
    bne x18, x0, neg_loop
    nop
    nop # wait
    sw x15, 12(x8) # store neg in box 3
    addi x9, x0, ARRAY # array pointer reset

# max (unsigned)
# umax = 0, loop, if x > umax (unsigned), umax = x
    addi x18, x0, 6 # counter
    addi x16, x0, 0 # umax
    nop
    nop
umax_loop:
    lw x5, 0(x9)
    addi x18, x18, -1 # counter--
    addi x9, x9, 4 # array pointer++
    nop # wait for lw
    bgeu x16, x5, umax_skip # if umax >= x, skip
    nop
    nop # wait
    add x16, x0, x5 # umax = x
umax_skip:
    bne x18, x0, umax_loop
    nop
    nop # wait
    sw x16, 16(x8) # store umax in box 4
    addi x9, x0, ARRAY # array pointer reset

# product
# prod = 1, loop, if x != 0, prod *= x
    addi x18, x0, 6 # counter
    addi x17, x0, 1 # prod
    nop
    nop
prod_loop:
    lw x5, 0(x9)
    addi x18, x18, -1 # counter--
    addi x9, x9, 4 # array pointer++
    nop # wait for lw
    beq x5, x0, prod_skip # if x == 0, skip
    nop
    nop # wait
    mul x17, x17, x5 # prod *= x
prod_skip:
    bne x18, x0, prod_loop
    nop
    nop # wait
    sw x17, 20(x8) # store prod in box 5

# divide
# sum is still in x12
    addi x19, x0, 6 # six
    nop
    nop
    nop # wait for x19
    div x20, x12, x19 # sum / 6
    rem x21, x12, x19 # sum % 6
    nop
    nop # wait for div, rem
    sw x20, 24(x8) # store sum / 6 in box 6
    sw x21, 28(x8) # store sum % 6 in box 7

# gcd
# a in x10, b in x11, answer in x10
    addi x10, x0, 48 # a
    addi x11, x0, 18 # b
    nop
    nop
    jal x1, gcd # call gcd
    nop
    nop # wait
    sw x10, 32(x8) # store gcd in box 8

# done
    lui x7, 0xD0E00
    nop
    nop
    nop # wait for lui
    addi x7, x7, 0x0D # x7 = D0E0000D
    nop
    nop
    nop # wait for x7
    sw x7, 36(x8) # store DONE in box 9
end:
    j end
    nop
    nop

# gcd function
# while b != 0: t = a % b, a = b, b = t
gcd:
    beq x11, x0, gcd_done # if b == 0, done
    nop
    nop # wait
    rem x5, x10, x11 # t = a % b
    addi x10, x11, 0 # a = b
    nop
    nop # wait for rem
    addi x11, x5, 0 # b = t
    j gcd
    nop
    nop # wait
gcd_done:
    jalr x0, 0(x1) # return
    nop
    nop # wait

    .org 0x600
array:
    .word 7, -3, 12, 0, 25, -8