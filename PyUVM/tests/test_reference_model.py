from alu.reference_model import predict
from alu.transaction import ALUTransaction


def transaction(a, b, control):
    item = ALUTransaction()
    item.a, item.b, item.alu_control = a, b, control
    return item


def test_add_wraps_to_32_bits():
    assert predict(transaction(0xFFFF_FFFF, 1, 0)) == (0, True)


def test_signed_shift_preserves_sign():
    assert predict(transaction(0x8000_0000, 4, 7)) == (0xF800_0000, False)


def test_signed_and_unsigned_comparisons_differ():
    assert predict(transaction(0xFFFF_FFFF, 0, 3)) == (True, False)
    assert predict(transaction(0xFFFF_FFFF, 0, 4)) == (False, True)


def test_invalid_control_matches_rtl_default():
    assert predict(transaction(1, 2, 15)) == (0, True)
