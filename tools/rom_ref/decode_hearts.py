"""Decode the heart HUD (top-left HP row) from dumped OAM+OBJ-VRAM+OBJ-palette
frames. Hearts are palette-0, 8x8 HUD objects -- decode_oam.py's HUD-exclusion
filter is exactly what strips these out for the hero-body crops, so this is a
separate small one-off reusing the same low-level OAM/VRAM decode math (kept
standalone rather than importing decode_oam.py, which runs its whole hero
pipeline as an unguarded module-level script).

Renders every pal-0 8x8 object at its native OAM (x,y) onto a HUD-sized
canvas, then slices the row into per-heart 8x8 tiles left-to-right so each
heart's fill state (full/half/empty, whatever this game actually uses) can be
saved as its own icon.
"""
import glob, os, struct, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import numpy as np
from PIL import Image

OAMDIR = "tools/rom_ref/out/oam"
OUT = "tools/rom_ref/out/oam/hearts"
os.makedirs(OUT, exist_ok=True)


def load_palette(path):
    raw = open(path, "rb").read()
    cols = struct.unpack("<256H", raw)
    pal = np.zeros((256, 4), np.uint8)
    for i, c in enumerate(cols):
        r = (c & 0x1F); g = (c >> 5) & 0x1F; b = (c >> 10) & 0x1F
        pal[i] = (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2, 255)
    return pal


def parse_oam(oam):
    for i in range(128):
        a0, a1, a2 = struct.unpack_from("<HHH", oam, i * 8)
        affine = (a0 >> 8) & 1
        if not affine and ((a0 >> 9) & 1):
            continue
        if (a0 >> 13) & 1:
            continue
        y = a0 & 0xFF
        if y >= 160: y -= 256
        x = a1 & 0x1FF
        if x >= 400: x -= 512
        shape = (a0 >> 14) & 3
        size = (a1 >> 14) & 3
        sizes = {0: {0: (8, 8), 1: (16, 16), 2: (32, 32), 3: (64, 64)},
                 1: {0: (16, 8), 1: (32, 8), 2: (32, 16), 3: (64, 32)},
                 2: {0: (8, 16), 1: (8, 32), 2: (16, 32), 3: (32, 64)}}
        w, h = sizes[shape][size]
        yield {"x": x, "y": y, "w": w, "h": h,
               "hflip": (a1 >> 12) & 1 if not affine else 0,
               "vflip": (a1 >> 13) & 1 if not affine else 0,
               "tile": a2 & 0x3FF, "pal": (a2 >> 12) & 0xF}


def decode_tile_4bpp(vram, tilenum):
    off = (tilenum & 0x3FF) * 32
    data = vram[off:off + 32]
    t = np.zeros((8, 8), np.uint8)
    for row in range(8):
        for k in range(4):
            byte = data[row * 4 + k]
            t[row, k * 2] = byte & 0x0F
            t[row, k * 2 + 1] = byte >> 4
    return t


def render_hearts(tag):
    oam = open(f"{OAMDIR}/oam_{tag}.bin", "rb").read()
    vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
    pal = load_palette(f"{OAMDIR}/objpal_{tag}.bin")
    hearts = [o for o in parse_oam(oam) if o["pal"] == 0 and o["w"] == 8 and o["h"] == 8 and o["y"] < 24]
    if not hearts:
        return None, []
    hearts.sort(key=lambda o: o["x"])
    x0 = min(o["x"] for o in hearts)
    x1 = max(o["x"] + o["w"] for o in hearts)
    y0 = min(o["y"] for o in hearts)
    canvas = np.zeros((8, x1 - x0, 4), np.uint8)
    for o in hearts:
        idx = decode_tile_4bpp(vram, o["tile"])
        block = pal[o["pal"] * 16 + idx]
        block[idx == 0] = 0
        if o["hflip"]: block = block[:, ::-1]
        if o["vflip"]: block = block[::-1, :]
        canvas[0:8, o["x"] - x0:o["x"] - x0 + 8] = block
    return canvas, hearts


if __name__ == "__main__":
    tags = sys.argv[1:] or ["idn_00"]
    for tag in tags:
        canvas, hearts = render_hearts(tag)
        if canvas is None:
            print(tag, "-- no pal-0 8x8 HUD hearts found")
            continue
        Image.fromarray(canvas, "RGBA").save(f"{OUT}/heartsrow_{tag}.png")
        print(tag, f"{len(hearts)} heart tiles, row width {canvas.shape[1]}px, tiles:",
              [(o['x'], o['tile']) for o in hearts])
