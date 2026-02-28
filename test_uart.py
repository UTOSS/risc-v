import serial
import time

COM = "COM8" # change to your device's serial port
BAUD = 115200
TIMEOUT = 1.0

WORDS = [
    0xFE010113, 0x00112E23, 0x00812C23, 0x00912A23,
    0x02010413, 0x00000493, 0x00148793, 0x3FF7F493,
    0x100007B7, 0x0097A023, 0xFE042623, 0x0100006F,
    0xFEC42783, 0x00178793, 0xFEF42623, 0xFEC42703,
    0x000F47B7, 0x23F78793, 0xFEE7D4E3, 0xFCDFF06F,
]

def hx(b: bytes) -> str:
    return " ".join(f"{x:02x}" for x in b)

def xor_chk(bs: bytes) -> int:
    c = 0
    for b in bs:
        c ^= b
    return c & 0xFF

def read_exact(ser, n) -> bytes:
    d = ser.read(n)
    if len(d) != n:
        raise RuntimeError(f"need {n}, got {len(d)}: {hx(d)}")
    return d

def expect_ack(resp: bytes, label: str) -> int:

    if len(resp) != 4 or resp[0] != 0x5A or resp[1] != 0x90:
        raise RuntimeError(f"{label}: not ACK: {hx(resp)}")
    status = resp[2]
    chk = resp[3]
    exp = (0x90 ^ status) & 0xFF
    if chk != exp:
        raise RuntimeError(f"{label}: bad ACK chk got {chk:02x} expect {exp:02x} frame={hx(resp)}")
    return status

def cmd_halt(ser):
    ser.write(bytes([0xA5, 0x13, 0x13]))  # CHK=0x13
    resp = read_exact(ser, 4)
    st = expect_ack(resp, "HALT")
    print("HALT resp:", hx(resp), "status=", hex(st))
    return st

def cmd_run(ser):
    ser.write(bytes([0xA5, 0x12, 0x12]))  # CHK=0x12
    resp = read_exact(ser, 4)
    st = expect_ack(resp, "RUN")
    print("RUN  resp:", hx(resp), "status=", hex(st))
    return st

def cmd_wr32(ser, addr: int, data: int):
    pkt = bytearray([0xA5, 0x10])
    pkt += addr.to_bytes(4, "little")
    pkt += data.to_bytes(4, "little")
    pkt += bytes([xor_chk(pkt[1:])])
    ser.write(pkt)
    resp = read_exact(ser, 4)
    st = expect_ack(resp, "WR32")
    if st != 0:
        raise RuntimeError(f"WR32 status={st:02x} addr=0x{addr:08x} resp={hx(resp)}")
    return st

def cmd_rdreg(ser, reg_idx: int) -> int:
    reg_idx &= 0x1F
    cmd = 0x14
    chk = cmd ^ reg_idx
    ser.write(bytes([0xA5, cmd, reg_idx, chk]))

    hdr = read_exact(ser, 2)

    if hdr == bytes([0x5A, 0x90]):
        tail = read_exact(ser, 2)
        st = expect_ack(hdr + tail, "RDREG(ACK)")
        raise RuntimeError(f"RDREG returned ACK status=0x{st:02x} frame={hx(hdr+tail)}")

    if hdr != bytes([0x5A, 0x92]):
        rest = ser.read(16)
        raise RuntimeError(f"RDREG bad header: {hx(hdr)} rest={hx(rest)}")

    rest = read_exact(ser, 5)  # d0 d1 d2 d3 chk
    d0, d1, d2, d3, rcv_chk = rest
    exp_chk = (0x92 ^ d0 ^ d1 ^ d2 ^ d3) & 0xFF
    if rcv_chk != exp_chk:
        raise RuntimeError(f"RDREG bad chk got {rcv_chk:02x} expect {exp_chk:02x} frame={hx(hdr+rest)}")

    return int.from_bytes(bytes([d0, d1, d2, d3]), "little")

def main():
    ser = serial.Serial(COM, BAUD, timeout=TIMEOUT)
    time.sleep(0.2)
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    cmd_halt(ser)

    print("Loading program...")
    base = 0x00000000
    for i, w in enumerate(WORDS):
        addr = base + 4*i
        cmd_wr32(ser, addr, w)
        if (i % 4) == 3:
            print(f"  wrote up to 0x{addr:08x}")

    cmd_run(ser)
    print("Core running. LEDR should be counting now.")

    print("Reading cnt from x9 (s1).")
    last = None
    try:
        while True:
            v = cmd_rdreg(ser, 9)  # x9 = cnt
            if last is None:
                print(f"cnt = {v:4d}  (0x{v:08x})")
            else:
                print(f"cnt = {v:4d}  (0x{v:08x})  ")
            last = v
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        ser.close()

if __name__ == "__main__":
    main()
