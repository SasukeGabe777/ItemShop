"""Convert a GameShark Advance ".gsv" save container into the raw BizHawk/mGBA
"SaveRAM" file (`GBA/SaveRAM/<gamedb name>.SaveRAM`).

Companion to sps_convert.py (which handles Datel *SharkPort* battery saves).
GameFAQs also serves GameShark ".gsv" containers; these are a DIFFERENT wrapper,
verified against `dragon-ball-z-the-legacy-of-goku-ii.22863.gsv` by booting the
produced SaveRAM in BizHawk 2.11.1 and seeing the completed files load.

## Container layout (ADVSAVEG, as seen on the DBZ:LoG II capture)

```
"ADVSAVEGQC\0\0"            12-byte magic
<title 12 bytes>            ROM header title @0xA0 (e.g. "DBZLGCYGOKU2")
u32 0
u32 4                       (version/kind?)
u32 checksum?               (0x742e on the DBZ file)
u32 payload_len             raw cartridge-save size (0x2000 = 8192 => EEPROM 8K)
u32 0
<comment, NUL-terminated>   the uploader's note ("I put in all this work ...")
<raw save payload>          exactly payload_len bytes, at EOF
```

## EEPROM -> BizHawk transform (same quirk as SharkPort)

The 8 KiB EEPROM payload is stored in 8-byte blocks with each block's byte
order REVERSED vs. what mGBA's SaveRAM wants. Native order (candidate A) boots
to three empty "NEW GAME" slots; un-reversing each 8-byte block (candidate B)
boots to the real files. mGBA then wants the payload, 0xFF padding up to
0x20000, then 16 more 0xFF bytes -> a fixed 131088-byte file (identical tail
convention to the Minish/M&L EEPROM saves handled by sps_convert.py).

Only the EEPROM-8K path is verified here. Flash/SRAM .gsv payloads would pad
differently (no 8-byte reversal) -- add + verify per game before trusting.
"""
import argparse
import struct

SAVERAM_TOTAL = 131088  # 0x20000 payload region + 16-byte footer (mGBA EEPROM)


def parse_gsv(data: bytes):
    if data[:8] != b"ADVSAVEG":
        raise ValueError("not a GameShark Advance (.gsv) container (bad magic)")
    payload_len = struct.unpack_from("<I", data, 0x24)[0]
    if payload_len <= 0 or payload_len > len(data):
        raise ValueError(f"implausible payload_len {payload_len}")
    return data[-payload_len:], payload_len


def unreverse_8byte(p: bytes) -> bytes:
    out = bytearray()
    for i in range(0, len(p), 8):
        out += p[i:i + 8][::-1]
    return bytes(out)


def build_eeprom_saveram(payload: bytes) -> bytes:
    body = unreverse_8byte(payload)
    buf = bytearray(body) + b"\xff" * (0x20000 - len(body)) + b"\xff" * 16
    assert len(buf) == SAVERAM_TOTAL, len(buf)
    return bytes(buf)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("gsv")
    ap.add_argument("--out", required=True, help="output .SaveRAM path (name it by the gamedb canonical name)")
    args = ap.parse_args()
    data = open(args.gsv, "rb").read()
    payload, plen = parse_gsv(data)
    if plen != 8192:
        raise SystemExit(f"payload is {plen} bytes; only EEPROM-8K is verified. "
                         "Check the save type and add a Flash/SRAM path before trusting.")
    saveram = build_eeprom_saveram(payload)
    with open(args.out, "wb") as f:
        f.write(saveram)
    print(f"payload={plen} (EEPROM 8K, 8-byte-unreversed) -> {args.out} ({len(saveram)} bytes)")


if __name__ == "__main__":
    main()
