"""Decode the user's live KH CoM battle recording (out/oam_kh_live) into
isolated Sora frames + a unique-pose contact sheet.

Same isolation as decode_oam_kh_battle.py (battle Sora = palette bank 0,
body-bbox bottom-center anchor, static-tuple HUD exclusion) but pointed at
the live_ dump corpus and restricted to the battle span (the earlier frames
are boot/menu/field). Unique poses are collapsed here directly (one flat
live_ group would make unique_poses_dbz.py's single-row sheet unusable).

Run: .venv312/Scripts/python tools/rom_ref/decode_oam_kh_live.py [start] [end]
"""
import glob, os, re, sys
from collections import Counter

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# decode_oam_kh_battle runs its pipeline at import; crib primitives from the
# DBZ decoder instead (identical GBA OAM layout) and do 4bpp here.
import decode_oam_dbz as dec

OAMDIR = "tools/rom_ref/out/oam_kh_live"
OUT = f"{OAMDIR}/decoded"
BODY_PAL = 0
CELL = 64
FEET_Y = 56
HUD_FRACTION = 0.6


def render_4bpp(objs, vram, pal, w, h, ox, oy):
    canvas = np.zeros((h, w, 4), np.uint8)
    for o in objs:
        tiles_w = o["w"] // 8
        sprite = np.zeros((o["h"], o["w"], 4), np.uint8)
        for ty in range(o["h"] // 8):
            for tx in range(tiles_w):
                idx = dec.decode_tile_4bpp(vram, o["tile"] + ty * tiles_w + tx)
                for yy in range(8):
                    for xx in range(8):
                        n = idx[yy, xx]
                        if n:
                            sprite[ty * 8 + yy, tx * 8 + xx] = pal[o["pal"] * 16 + n]
        if o["hflip"]:
            sprite = sprite[:, ::-1]
        if o["vflip"]:
            sprite = sprite[::-1, :]
        for yy in range(o["h"]):
            py = o["y"] + yy + oy
            if 0 <= py < h:
                for xx in range(o["w"]):
                    px = o["x"] + xx + ox
                    if 0 <= px < w and sprite[yy, xx, 3]:
                        canvas[py, px] = sprite[yy, xx]
    return canvas


def main():
    lo = int(sys.argv[1]) if len(sys.argv) > 1 else 4400
    hi = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9
    os.makedirs(OUT, exist_ok=True)
    frames = []
    for fp in sorted(glob.glob(f"{OAMDIR}/oam_live_*.bin")):
        n = int(os.path.basename(fp)[9:-4])
        if lo <= n <= hi:
            frames.append((n, fp))
    counts = Counter()
    for _, fp in frames:
        for o in dec.parse_oam(open(fp, "rb").read()):
            counts[dec.obj_key(o)] += 1
    hud = {k for k, n in counts.items() if n > len(frames) * HUD_FRACTION}
    print(f"{len(frames)} frames; {len(hud)} HUD tuples excluded")

    poses, order = [], []
    for n, fp in frames:
        tag = f"live_{n:06d}"
        oam = open(fp, "rb").read()
        vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
        pal = dec.load_palette(f"{OAMDIR}/objpal_{tag}.bin")
        live = [o for o in dec.parse_oam(oam)
                if dec.obj_key(o) not in hud and not o["bpp8"]]
        body = [o for o in live if o["pal"] == BODY_PAL]
        if not body:
            continue
        x0 = min(o["x"] for o in body); x1 = max(o["x"] + o["w"] for o in body)
        y1 = max(o["y"] + o["h"] for o in body)
        if x1 - x0 > 96:   # pal-0 junk scattered across the screen: not Sora
            continue
        cell = render_4bpp(body, vram, pal, CELL, CELL,
                           ox=CELL // 2 - (x0 + x1) // 2, oy=FEET_Y - y1)
        Image.fromarray(cell, "RGBA").save(f"{OUT}/sora_{tag}.png")
        for i, (t0, a0, cnt) in enumerate(poses):
            if np.array_equal(cell, a0):
                poses[i] = (t0, a0, cnt + 1)
                order.append(i)
                break
        else:
            order.append(len(poses))
            poses.append((tag, cell, 1))
    print(f"{len(poses)} unique poses over {len(order)} kept frames")
    dec.contact_sheet([(f"{t} x{c}", a) for t, a, c in poses],
                      f"{OUT}/unique_sora_live.png")
    with open(f"{OUT}/pose_order.txt", "w") as f:
        f.write(" ".join(str(i) for i in order))
    print(f"sheet: {OUT}/unique_sora_live.png")


if __name__ == "__main__":
    main()
