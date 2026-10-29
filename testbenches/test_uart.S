# prints the first 16 fibonacci numbers over the uart, one per line

    .section .text
    .globl _start

    .equ UART0,       0x10000000
    .equ UART_TX,     0           # write a byte
    .equ UART_STATUS, 8           # bit 0 = tx_busy

_start:
    li   sp, 0x4000               # top of 16 KB ram
    li   s0, 0                    # fib a
    li   s1, 1                    # fib b
    li   s2, 16                   # numbers to print

fib_loop:
    mv   a0, s0
    jal  ra, print_uint
    li   a0, '\n'
    jal  ra, uart_putc

    add  t0, s0, s1               # next = a + b
    mv   s0, s1
    mv   s1, t0

    addi s2, s2, -1
    bnez s2, fib_loop

# --- done --------------------------------------------------------------
    li   t0, 0x400                # results area
    li   t1, 0xD0E0000D
    sw   t1, 0(t0)                # DONE marker
halt:
    j    halt

# --- uart_putc: send a0[7:0] -------------------------------------------
uart_putc:
    li   t0, UART0
uart_wait:
    lw   t1, UART_STATUS(t0)
    andi t1, t1, 1                # tx_busy
    bnez t1, uart_wait            # wait while busy
    sw   a0, UART_TX(t0)
    ret

# --- print_uint: a0 as decimal, no leading zeros -----------------------
print_uint:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)

    mv   s0, a0                   # value left
    li   s1, 1000000000           # place value
    li   s2, 0                    # printed a digit yet

print_digit:
    divu t0, s0, s1               # digit
    bnez t0, print_it             # nonzero: always print
    beqz s2, skip_zero            # leading zero: skip
print_it:
    li   s2, 1
    addi a0, t0, '0'
    jal  ra, uart_putc
skip_zero:
    remu s0, s0, s1               # drop that digit
    li   t1, 10
    divu s1, s1, t1               # next place
    bnez s1, print_digit

    bnez s2, print_done           # value was 0: print "0"
    li   a0, '0'
    jal  ra, uart_putc

print_done:
    lw   s2, 0(sp)
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret