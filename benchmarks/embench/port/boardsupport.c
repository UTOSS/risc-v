/*
 * Bare-metal Embench-IoT board support implementation for utoss-risc-v.
 */
#include <stdint.h>

#include "boardsupport.h"
#include "support.h"

static inline void
mmio_write32(uint32_t addr, uint32_t val)
{
    *(volatile uint32_t *)(uintptr_t)addr = val;
}

void
initialise_board(void)
{
    /* No hardware peripheral init needed in RTL simulation. */
}

void __attribute__((noinline))
start_trigger(void)
{
    mmio_write32(UTOSS_MMIO_BENCH_CTRL, 1u);
}

void __attribute__((noinline))
stop_trigger(void)
{
    mmio_write32(UTOSS_MMIO_BENCH_CTRL, 0u);
}
