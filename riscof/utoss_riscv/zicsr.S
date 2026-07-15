#include "model_test.h"

  .section .text.init
  .globl rvtest_entry_point
rvtest_entry_point:
  li x1,  0x11111111
  li x2,  0x22222222
  li x3,  0x00000007
  li x4,  0x67676767
  li x7,  0x0000000f
  li t6,  0x67676767
  li t0,  0x12345678

  csrw mstatus, t0
  csrr s0, mstatus
  csrrw s1, mstatus, x1
  csrrs s2, mstatus, x2
  csrrc s3, mstatus, x3
  csrrw x0, mstatus, x7
  csrrs s4, mstatus, x0

  csrw mtvec, t6
  csrrwi s5, mtvec, 0x7
  csrrsi s6, mtvec, 0x0
  csrrci s7, mtvec, 0x1
  csrrs s8, mtvec, x0

  csrr s9, mstatus
  csrr s10, mtvec

  /* One fun extra value, just to make the signature obvious. */
  csrrw s11, mstatus, x4

  la a0, begin_signature
  sw s0,  0(a0)
  sw s1,  4(a0)
  sw s2,  8(a0)
  sw s3, 12(a0)
  sw s4, 16(a0)
  sw s5, 20(a0)
  sw s6, 24(a0)
  sw s7, 28(a0)
  sw s8, 32(a0)
  sw s9, 36(a0)
  sw s10, 40(a0)
  sw s11, 44(a0)

  RVMODEL_HALT

  RVMODEL_DATA_BEGIN
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  .word 0
  RVMODEL_DATA_END
