from .transaction import ALUTransaction

MASK32 = 0xFFFF_FFFF


def _signed(value):
    value &= MASK32
    return value - (1 << 32) if value & (1 << 31) else value


def expected_result(transaction: ALUTransaction) -> int:
    """Return the 32-bit ALU result for a transaction."""
    a = transaction.a & MASK32
    b = transaction.b & MASK32
    shift = b & 0x1F
    control = transaction.alu_control

    if control == 0:
        result = a + b
    elif control == 1:
        result = a - b
    elif control == 2:
        result = a << shift
    elif control == 3:
        result = 1 if _signed(a) < _signed(b) else 0
    elif control == 4:
        result = 1 if a < b else 0
    elif control == 5:
        result = a ^ b
    elif control == 6:
        result = a >> shift
    elif control == 7:
        result = _signed(a) >> shift
    elif control == 8:
        result = a | b
    elif control == 9:
        result = a & b
    else:
        result = 0
    return result & MASK32


def predict(transaction: ALUTransaction) -> tuple[int, bool]:
    result = expected_result(transaction)
    return result, result == 0
