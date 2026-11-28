/*
 * Bare-metal Embench-IoT board support header for utoss-risc-v.
 */
#ifndef BOARDSUPPORT_H
#define BOARDSUPPORT_H

#define UTOSS_MMIO_BASE       0x10000000u
#define UTOSS_MMIO_PUTCHAR    (UTOSS_MMIO_BASE + 0x00u)
#define UTOSS_MMIO_BENCH_CTRL (UTOSS_MMIO_BASE + 0x04u)
#define UTOSS_MMIO_EXIT       (UTOSS_MMIO_BASE + 0x08u)

#endif /* BOARDSUPPORT_H */
