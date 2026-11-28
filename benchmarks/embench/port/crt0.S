/*
 * Minimal bare-metal RISC-V RV32 startup for utoss-risc-v Embench-IoT simulation.
 */
.section .text.init, "ax"
.global _start
.type _start, @function

_start:
    /* Idempotent first instruction at BOOT_ADDR (0x0000_0000) */
    nop

    /* Initialize global pointer (for linker relaxation) */
.option push
.option norelax
    la   gp, __global_pointer$
.option pop

    /* Initialize stack pointer to top of 1 MB simulation RAM */
    la   sp, _stack_top

    /* Zero .bss */
    la   t0, __bss_start
    la   t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b

2:
    /* Call Embench main(0, NULL); returns 0 on PASS, 1 on FAIL */
    li   a0, 0
    li   a1, 0
    call main

    /* Signal simulation exit via MMIO exit register (0x1000_0008) */
    li   t0, 0x10000008
    sw   a0, 0(t0)

3:
    j    3b

.size _start, . - _start
