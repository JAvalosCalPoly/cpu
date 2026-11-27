	.text
	.globl _start
_start:
	li x31, 0x400

	# [0] Distance between INSTRET reads.
	rdinstret a0
	nop
	nop
	nop
	rdinstret a1
	sub a2, a1, a0
	sw a2, 0(x31)

	# [1] Consecutive cycle reads.
	rdcycle a0
	rdcycle a1
	sub a2, a1, a0
	sw a2, 4(x31)

	# [2] Write and read minstret.
	li t0, 100
	csrw minstret, t0
	rdinstret a0
	sw a0, 8(x31)

	# [3] Compare rdtime with memory-mapped MTIME.
	rdtime a0
	li t1, 0x0200BFF8
	lw a1, 0(t1)
	sub a2, a1, a0
	sw a2, 12(x31)

	# [4] Writing read-only cycle must trap.
	la t1, trap_handler
	csrw mtvec, t1
	li t0, 0
	csrw cycle, t0

	# [60] DONE
	li gp, 0xD0E0000D
	sw gp, 240(x31)
1:
	j 1b

	.align 2
trap_handler:
	csrr s1, mcause
	sw s1, 16(x31)
	csrr t1, mepc
	addi t1, t1, 4
	csrw mepc, t1
	mret
