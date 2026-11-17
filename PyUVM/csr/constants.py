"""Machine CSR addresses, reset values and implemented write masks."""

CSR = {
    0x340: (0x00000000, 0xFFFFFFFF),  # mscratch
    0xF14: (0x00000000, 0x00000000),  # mhartid (read-only)
    0x305: (0x00000000, 0xFFFFFFFC),  # mtvec, direct mode
    0x341: (0x00000000, 0xFFFFFFFE),  # mepc
    0x342: (0x00000000, 0x8000001F),  # mcause
}

NAMES = {0x340: "mscratch", 0xF14: "mhartid", 0x305: "mtvec",
         0x341: "mepc", 0x342: "mcause"}
