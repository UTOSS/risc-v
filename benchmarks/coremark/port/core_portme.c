/*
 * Bare-metal CoreMark port implementation for utoss-risc-v.
 */
#include <stdarg.h>

#include "coremark.h"
#include "core_portme.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

static inline ee_u32
mmio_read32(ee_u32 addr)
{
    return *(volatile ee_u32 *)(ee_ptr_int)addr;
}

static inline void
mmio_write32(ee_u32 addr, ee_u32 val)
{
    *(volatile ee_u32 *)(ee_ptr_int)addr = val;
}

static inline void
console_putc(char c)
{
    mmio_write32(UTOSS_MMIO_PUTCHAR, (ee_u32)(unsigned char)c);
}

static int
print_uint(unsigned long val, unsigned base, int width, char pad, int upper)
{
    static const char lower_hex[] = "0123456789abcdef";
    static const char upper_hex[] = "0123456789ABCDEF";
    const char       *digits      = upper ? upper_hex : lower_hex;
    char              buf[32];
    int               len = 0;
    int               n   = 0;

    if (val == 0)
    {
        buf[len++] = '0';
    }
    else
    {
        while (val != 0)
        {
            buf[len++] = digits[val % base];
            val /= base;
        }
    }

    while (len < width)
    {
        console_putc(pad);
        n++;
        width--;
    }

    while (len > 0)
    {
        console_putc(buf[--len]);
        n++;
    }
    return n;
}

int
ee_printf(const char *fmt, ...)
{
    va_list args;
    int     written = 0;

    va_start(args, fmt);
    for (; *fmt != '\0'; fmt++)
    {
        if (*fmt != '%')
        {
            console_putc(*fmt);
            written++;
            continue;
        }

        fmt++;
        char pad   = ' ';
        int  width = 0;
        if (*fmt == '0')
        {
            pad = '0';
            fmt++;
        }
        while (*fmt >= '0' && *fmt <= '9')
        {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }

        int is_long = 0;
        if (*fmt == 'l')
        {
            is_long = 1;
            fmt++;
        }

        switch (*fmt)
        {
            case 'c':
                console_putc((char)va_arg(args, int));
                written++;
                break;
            case 's':
            {
                const char *s = va_arg(args, const char *);
                if (!s)
                    s = "(null)";
                while (*s != '\0')
                {
                    console_putc(*s++);
                    written++;
                }
                break;
            }
            case 'd':
            case 'i':
            {
                long v = is_long ? va_arg(args, long) : (long)va_arg(args, int);
                unsigned long uv;
                if (v < 0)
                {
                    console_putc('-');
                    written++;
                    if (width > 0)
                        width--;
                    uv = (unsigned long)(-(v + 1)) + 1ul;
                }
                else
                {
                    uv = (unsigned long)v;
                }
                written += print_uint(uv, 10u, width, pad, 0);
                break;
            }
            case 'u':
            {
                unsigned long uv = is_long ? va_arg(args, unsigned long)
                                           : (unsigned long)va_arg(args, unsigned int);
                written += print_uint(uv, 10u, width, pad, 0);
                break;
            }
            case 'x':
            case 'X':
            {
                unsigned long uv = is_long ? va_arg(args, unsigned long)
                                           : (unsigned long)va_arg(args, unsigned int);
                written += print_uint(uv, 16u, width, pad, (*fmt == 'X'));
                break;
            }
            case '%':
                console_putc('%');
                written++;
                break;
            case '\0':
                goto done;
            default:
                console_putc('%');
                console_putc(*fmt);
                written += 2;
                break;
        }
    }

done:
    va_end(args);
    return written;
}

CORETIMETYPE
barebones_clock(void)
{
    return mmio_read32(UTOSS_MMIO_CYCLE_LO);
}

#define GETMYTIME(_t)        (*(_t) = barebones_clock())
#define MYTIMEDIFF(fin, ini) ((fin) - (ini))

static CORETIMETYPE start_time_val, stop_time_val;

void
start_time(void)
{
    mmio_write32(UTOSS_MMIO_BENCH_CTRL, 1u);
    GETMYTIME(&start_time_val);
}

void
stop_time(void)
{
    GETMYTIME(&stop_time_val);
    mmio_write32(UTOSS_MMIO_BENCH_CTRL, 0u);
}

CORE_TICKS
get_time(void)
{
    CORE_TICKS elapsed = (CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
    return elapsed;
}

secs_ret
time_in_secs(CORE_TICKS ticks)
{
    secs_ret retval = ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
    return retval;
}

ee_u32 default_num_contexts = 1;

void
portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;

    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *))
    {
        ee_printf(
            "ERROR! Please define ee_ptr_int to a type that holds a "
            "pointer!\n");
    }
    if (sizeof(ee_u32) != 4)
    {
        ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
    }
    p->portable_id = 1;
}

void
portable_fini(core_portable *p)
{
    p->portable_id = 0;
}

/* Minimal freestanding memory helpers in case GCC emits memcpy/memset libcalls */
void *
memcpy(void *dst, const void *src, size_t n)
{
    ee_u8       *d = (ee_u8 *)dst;
    const ee_u8 *s = (const ee_u8 *)src;
    while (n--)
    {
        *d++ = *s++;
    }
    return dst;
}

void *
memset(void *dst, int c, size_t n)
{
    ee_u8 *d = (ee_u8 *)dst;
    while (n--)
    {
        *d++ = (ee_u8)c;
    }
    return dst;
}
