"""Convert a Datel SharkPort (.sps) GBA battery-save container into the raw
BizHawk/mGBA "SaveRAM" file the emulator reads from
`GBA/SaveRAM/<gamedb name>.SaveRAM`.

Reverse-engineered from a single known-good pair (no public spec was used):
`savestates/the-legend-of-zelda-the-minish-cap.34871.sps` (input) vs.
`savestates/BizHawk-2.11.1-win-x64/GBA/SaveRAM/Legend of Zelda, The - The
Minish Cap (USA).SaveRAM` (a previous session's working output). Byte-level
diffing that pair against the .sps is what pinned every offset below --
re-run `--verify` after any change to prove it still reproduces that file
exactly before trusting a new game's conversion.

## Container layout (SharkPortSave, as used by these 3 captures)

```
u32 13                      "SharkPortSave" length
"SharkPortSave"             literal, then 1 extra NUL (not counted in len)
u16, u16                    unknown (constant 0x0F00, 0x000C-ish region start)
u32 12  <title 12 bytes>    copy of ROM header title @0xA0 (no separate NUL;
                            the 12 bytes ARE the field, whatever the ROM had)
u32 date_len  <date bytes>  NUL-terminated (date_len does NOT include the NUL)
... a few unknown bytes ...
u32 block_len                        <- length of the block that follows
  <title 12 bytes>                   duplicate of the title above
  <code 4 bytes>                     ROM header code @0xAC (e.g. "BZME")
  10 unknown bytes (checksum/flags, unidentified, not needed for extraction)
  <raw save payload, block_len - 28 bytes>
4-byte trailer (CRC?), IF block_start + block_len < end of file
```

`block_len` is trustworthy for Minish Cap and Kingdom Hearts (both cross-checked:
block_start + block_len + 4 == file size, and the payload lengths that fall out,
8192 and 65536, are exactly EEPROM-8K and Flash-64K). Mario & Luigi's capture is
an outlier: its `block_len` field decodes to 131100 (i.e. 128 KiB + 28), bigger
than the whole 8288-byte file -- the dump appears to have been truncated to
just the used bytes, no trailing pad, no 4-byte trailer. We detect that case
(the declared block would overrun the file) and fall back to "payload runs to
EOF", which lands on exactly 8192 bytes -- consistent with M&L's ROM also
advertising an `EEPROM_V124` interface (same 8 KiB EEPROM as Minish Cap).

## Save-type handling

The ROM is scanned for libgba's save-interface ID strings (`EEPROM_V`,
`SRAM_V`, `FLASH_V`, `FLASH512_V`, `FLASH1M_V`) to decide the transform:

- EEPROM: SharkPort stores payload in 8-byte blocks with each block's byte
  order reversed relative to what mGBA's SaveRAM file wants. Proven by
  matching plaintext that appears in the save (Minish Cap embeds the ASCII
  tag "AGBZELDA:THE MINISH CAP:ZELDA..." in its own save data): the .sps
  bytes read that text forwards; the working SaveRAM has it mirrored in
  8-byte chunks ("ADLEZBGA" = "AGBZELDA" reversed). Un-reversing those same
  8-byte blocks is the whole transform.
- SRAM / Flash: no reversal -- the SharkPort payload is byte-identical to
  what mGBA wants (Kingdom Hearts, a 64 KiB Flash game with no EEPROM_V
  string in its ROM, needed nothing but padding).

## Output

mGBA/BizHawk always allocates a full 128 KiB (0x20000) SaveRAM buffer plus a
16-byte all-0xFF tail regardless of the cart's actual chip size (verified by
booting Minish Cap, Kingdom Hearts, and M&L fresh -- all three produced a
131088-byte file). So: payload, then 0xFF padding up to 131072, then 16 more
0xFF bytes. Total is always 131088 bytes.

Usage:
    python sps_convert.py <in.sps> <rom.gba> [--out PATH] [--verify EXPECTED.SaveRAM]

`--verify` diffs the produced bytes against a known-good SaveRAM and reports
PASS/FAIL + first mismatch offset, instead of writing the output file.
"""
import argparse
import struct
import sys
from pathlib import Path

SAVE_SIZE = 128 * 1024  # 0x20000, mGBA's fixed SaveRAM buffer size
TAIL = 16
TOTAL_SIZE = SAVE_SIZE + TAIL
CLEAN_SIZES = (512, 8192, 32768, 65536, 131072)
GAMEDB = Path(__file__).resolve().parents[2] / \
    "savestates/BizHawk-2.11.1-win-x64/gamedb/gamedb_gba.txt"


def rom_header(rom_bytes):
    return rom_bytes[0xA0:0xAC], rom_bytes[0xAC:0xB0]


def detect_save_kind(rom_bytes):
    """Return ('eeprom'|'sram'|'flash', tag) by scanning for libgba's save
    interface ID strings. Falls back to 'flash' (no reversal) if none found
    -- SRAM/Flash are the common case for carts that omit the ID string."""
    for pat, kind in [
        (b"EEPROM_V", "eeprom"),
        (b"FLASH1M_V", "flash"),
        (b"FLASH512_V", "flash"),
        (b"FLASH_V", "flash"),
        (b"SRAM_V", "sram"),
    ]:
        idx = rom_bytes.find(pat)
        if idx >= 0:
            tag = rom_bytes[idx:idx + 16].split(b"\x00")[0].decode("ascii", "replace")
            return kind, tag
    return "flash", "(no ID string found; assuming Flash/SRAM, no reversal)"


def parse_sps(data, rom_code):
    """Locate the raw save payload inside a SharkPortSave container.

    Returns (payload_start, payload_len, note).
    """
    if data[4:17] != b"SharkPortSave":
        raise ValueError("not a SharkPortSave container (bad magic string)")

    off = 4 + 13 + 1  # past "SharkPortSave" + its extra NUL
    idx = data.find(b"\x0c\x00\x00\x00", off)
    if idx < 0:
        raise ValueError("could not find the 12-byte title-length field")
    off2 = idx + 4 + 12
    date_len = struct.unpack_from("<I", data, off2)[0]
    pos_after_date = off2 + 4 + date_len + 1  # +1 for the trailing NUL

    code_pos = data.find(rom_code, pos_after_date)
    if code_pos < 0:
        raise ValueError(f"could not find ROM code {rom_code!r} after the header "
                          f"(offset {pos_after_date}) -- container layout differs")
    block_start = code_pos - 12
    header_len = 28  # title(12) + code(4) + 10 unknown bytes, constant in all 3 captures
    payload_start = block_start + header_len

    block_len = struct.unpack_from("<I", data, block_start - 4)[0]
    candidate_a = block_len - header_len
    candidate_b = len(data) - payload_start  # assume payload runs to EOF, no trailer

    if candidate_a in CLEAN_SIZES and payload_start + candidate_a <= len(data):
        return payload_start, candidate_a, \
            f"used declared block_len={block_len} (payload {candidate_a}B, " \
            f"{len(data) - payload_start - candidate_a}B trailer)"
    if candidate_b in CLEAN_SIZES:
        return payload_start, candidate_b, \
            f"declared block_len={block_len} overruns the file " \
            f"({block_start + block_len} > {len(data)}); fell back to " \
            f"'payload runs to EOF' (payload {candidate_b}B, no trailer)"
    raise ValueError(
        f"neither candidate payload length is a clean GBA save size: "
        f"declared={candidate_a}, eof-fallback={candidate_b}")


def unreverse_eeprom(payload):
    """Un-reverse SharkPort's 8-byte-block byte order (EEPROM saves only)."""
    out = bytearray(len(payload))
    for i in range(0, len(payload), 8):
        out[i:i + 8] = payload[i:i + 8][::-1]
    return bytes(out)


def build_saveram(payload, kind):
    body = unreverse_eeprom(payload) if kind == "eeprom" else bytes(payload)
    padded = body + b"\xff" * (SAVE_SIZE - len(body))
    return padded + b"\xff" * TAIL


def gamedb_name(rom_bytes):
    import hashlib
    sha1 = hashlib.sha1(rom_bytes).hexdigest().upper()
    if not GAMEDB.exists():
        return None
    with open(GAMEDB, encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if parts and parts[0].upper() == sha1:
                return parts[2]
    return None


def convert(sps_path, rom_path):
    data = Path(sps_path).read_bytes()
    rom_bytes = Path(rom_path).read_bytes()
    title, code = rom_header(rom_bytes)
    kind, tag = detect_save_kind(rom_bytes)
    payload_start, payload_len, note = parse_sps(data, code)
    payload = data[payload_start:payload_start + payload_len]
    saveram = build_saveram(payload, kind)
    assert len(saveram) == TOTAL_SIZE
    name = gamedb_name(rom_bytes)
    return saveram, dict(title=title, code=code, kind=kind, id_tag=tag,
                          payload_start=payload_start, payload_len=payload_len,
                          note=note, gamedb_name=name)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sps")
    ap.add_argument("rom")
    ap.add_argument("--out", help="output .SaveRAM path")
    ap.add_argument("--verify", help="compare produced bytes against this known-good "
                                      ".SaveRAM instead of writing --out")
    args = ap.parse_args()

    saveram, info = convert(args.sps, args.rom)
    print(f"title={info['title']!r} code={info['code']!r} kind={info['kind']} "
          f"(ROM ID string: {info['id_tag']})")
    print(f"payload: offset={info['payload_start']} len={info['payload_len']} -- {info['note']}")
    if info["gamedb_name"]:
        print(f"gamedb name: {info['gamedb_name']!r} "
              f"-> expected file 'GBA/SaveRAM/{info['gamedb_name']}.SaveRAM'")
    else:
        print("gamedb name: NOT FOUND (hash didn't match gamedb_gba.txt)")

    if args.verify:
        expected = Path(args.verify).read_bytes()
        if expected == saveram:
            print(f"VERIFY PASS: matches {args.verify} byte-for-byte "
                  f"({len(saveram)} bytes)")
        else:
            if len(expected) != len(saveram):
                print(f"VERIFY FAIL: length mismatch (got {len(saveram)}, "
                      f"expected {len(expected)})")
            first_diff = next((i for i in range(min(len(expected), len(saveram)))
                                if expected[i] != saveram[i]), None)
            print(f"VERIFY FAIL: first mismatch at offset {first_diff}")
            sys.exit(1)
    elif args.out:
        Path(args.out).write_bytes(saveram)
        print(f"wrote {args.out} ({len(saveram)} bytes)")
    else:
        print("(no --out/--verify given; nothing written)")


if __name__ == "__main__":
    main()
