from csr.reference_model import CSRReferenceModel


def test_csr_write_set_clear_masks_and_suppression():
    model = CSRReferenceModel()
    model.execute(0x340, "write", 5, 0x13579BDF, True)
    model.execute(0x340, "set", 6, 0xF, True)
    model.execute(0x340, "clear", 7, 3, True)
    model.execute(0x340, "set", 8, 0, False)
    assert model.register_writes == [(5, 0), (6, 0x13579BDF),
                                     (7, 0x13579BDF), (8, 0x13579BDC)]
    assert model.values[0x340] == 0x13579BDC
    assert model.csr_writes == [(0x340, 0x13579BDF),
                                (0x340, 0x13579BDF), (0x340, 0x13579BDC)]


def test_csr_warl_masks_and_unimplemented_write_bus_request():
    model = CSRReferenceModel()
    model.execute(0x305, "write", 1, 0x103, True)
    model.execute(0xF14, "write", 2, 0x55, True)
    model.execute(0x7C0, "write", 3, 0xAA, True)
    assert model.values[0x305] == 0x100
    assert model.values[0xF14] == 0
    assert 0x7C0 not in model.values
    assert model.csr_writes == [(0x305, 0x103), (0xF14, 0x55), (0x7C0, 0xAA)]
