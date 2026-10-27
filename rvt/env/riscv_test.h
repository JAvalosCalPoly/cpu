// minimal env for riscv-tests on a bare RV32IM core (no CSRs)
// result word at 0x3FF0: 1 = pass, (test << 1) | 1 = fail
#ifndef _ENV_MINIMAL_H
#define _ENV_MINIMAL_H

#define RVTEST_RV32U
#define RVTEST_RV64U
#define RVTEST_RV32M
#define RVTEST_RV64M
#define TESTNUM gp

#define RVTEST_CODE_BEGIN  .text; .globl _start; _start: li gp, 0;
#define RVTEST_CODE_END

#define RVTEST_PASS        li t5, 1; li t6, 0x3FF0; sw t5, 0(t6); 1: j 1b;
#define RVTEST_FAIL        slli t5, gp, 1; ori t5, t5, 1; li t6, 0x3FF0; sw t5, 0(t6); 1: j 1b;

#define RVTEST_DATA_BEGIN  .data; .align 4;
#define RVTEST_DATA_END

#endif
