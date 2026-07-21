"""Reconstruct GBA text-mode background layers from dumped VRAM + palette + regs.

For each site dumped by capture_barriers_*.lua, renders every enabled BG layer
as its FULL tilemap (256/512 px per side, exact 8px tile boundaries -- no
screen cropping, no scroll needed: scroll registers are write-only on GBA and
unnecessary when you render the whole map). Layer PNGs make barrier art
(hedges, fences, cliffs, crates) directly croppable at tile boundaries.

Palette-index 0 pixels are transparent, so overlay layers isolate their
objects; layer 3 is usually the opaque floor.
"""
import glob, os, re, struct
import numpy as np
from PIL import Image

BGDIR = "tools/rom_ref/out/bg"
OUT = "tools/rom_ref/out/bg/decoded"
os.makedirs(OUT, exist_ok=True)

SIZE = {0: (256, 256), 1: (512, 256), 2: (256, 512), 3: (512, 512)}

def load_palette(path):
    raw = open(path, "rb").read()
    cols = struct.unpack("<256H", raw[:512])
    pal = np.zeros((256, 4), np.uint8)
    for i, c in enumerate(cols):
        r = (c & 0x1F); g = (c >> 5) & 0x1F; b = (c >> 10) & 0x1F
        pal[i] = (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2, 255)
    return pal

def decode_tile_4bpp(vram, base, tilenum):
    off = base + tilenum * 32
    data = vram[off:off + 32]
    t = np.zeros((8, 8), np.uint8)
    for row in range(8):
        for k in range(4):
            byte = data[row * 4 + k]
            t[row, k * 2] = byte & 0x0F
            t[row, k * 2 + 1] = byte >> 4
    return t

def decode_tile_8bpp(vram, base, tilenum):
    off = base + tilenum * 64
    data = vram[off:off + 64]
    return np.frombuffer(data, np.uint8).reshape(8, 8).copy()

def render_bg(vram, pal, cnt, eightbpp):
    charbase = ((cnt >> 2) & 3) * 0x4000
    screenbase = ((cnt >> 8) & 31) * 0x800
    w, h = SIZE[(cnt >> 14) & 3]
    canvas = np.zeros((h, w, 4), np.uint8)
    for sy in range(h // 256):
        for sx in range(w // 256):
            sbb = screenbase + (sy * (w // 256) + sx) * 0x800
            for ty in range(32):
                for tx in range(32):
                    entry = struct.unpack_from("<H", vram, sbb + (ty * 32 + tx) * 2)[0]
                    tile = entry & 0x3FF
                    hflip = (entry >> 10) & 1
                    vflip = (entry >> 11) & 1
                    palbank = (entry >> 12) & 0xF
                    if eightbpp:
                        idx = decode_tile_8bpp(vram, charbase, tile)
                        block = pal[idx]
                        block[idx == 0] = 0
                    else:
                        idx = decode_tile_4bpp(vram, charbase, tile)
                        block = pal[palbank * 16 + idx]
                        block[idx == 0] = 0
                    if hflip: block = block[:, ::-1]
                    if vflip: block = block[::-1, :]
                    y0 = sy * 256 + ty * 8
                    x0 = sx * 256 + tx * 8
                    canvas[y0:y0 + 8, x0:x0 + 8] = block
    return canvas

for regfile in sorted(glob.glob(f"{BGDIR}/regs_*.txt")):
    tag = os.path.basename(regfile)[5:-4]
    regs = {}
    for line in open(regfile):
        k, v = line.split()
        regs[k] = int(v, 16)
    vram = open(f"{BGDIR}/bgvram_{tag}.bin", "rb").read()
    pal = load_palette(f"{BGDIR}/bgpal_{tag}.bin")
    dispcnt = regs["DISPCNT"]
    mode = dispcnt & 7
    for n in range(4):
        if not (dispcnt >> (8 + n)) & 1:
            continue
        if mode != 0 and n >= 2:
            continue  # affine BGs (mode 1/2) unhandled; barrier art is text BGs
        cnt = regs[f"BG{n}CNT"]
        img = render_bg(vram, pal, cnt, (cnt >> 7) & 1)
        Image.fromarray(img, "RGBA").save(f"{OUT}/bg{n}_{tag}.png")
        print(f"{tag}: BG{n} rendered ({img.shape[1]}x{img.shape[0]}, "
              f"{'8bpp' if (cnt >> 7) & 1 else '4bpp'})")
