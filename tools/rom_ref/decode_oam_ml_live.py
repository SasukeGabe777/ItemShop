"""Decode the user's live M&L Superstar Saga recording (out/oam_ml_live)
into isolated per-bro frames + unique-pose contact sheets.

Both bros are on screen at once: Mario = palette bank 0, Luigi = palette
bank 1 (verified on field + battle OAM probes). Each is isolated separately
per frame with the same recipe as decode_oam_kh_live.py: static-tuple HUD
exclusion, per-pal bbox anchor at bottom-center, frames whose pal cluster
spreads >96px are skipped as junk.

Run: .venv312/Scripts/python tools/rom_ref/decode_oam_ml_live.py [start] [end]
"""
import glob, os, sys
from collections import Counter

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import decode_oam_dbz as dec
from decode_oam_kh_live import render_4bpp

OAMDIR = "tools/rom_ref/out/oam_ml_live"
OUT = f"{OAMDIR}/decoded"
BROS = {"mario": 0, "luigi": 1}
CELL = 64
FEET_Y = 56
HUD_FRACTION = 0.6


def main():
    lo = int(sys.argv[1]) if len(sys.argv) > 1 else 0
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

    poses = {b: [] for b in BROS}
    for n, fp in frames:
        tag = f"live_{n:06d}"
        oam = open(fp, "rb").read()
        vram = None
        pal = None
        live = [o for o in dec.parse_oam(oam)
                if dec.obj_key(o) not in hud and not o["bpp8"]]
        for bro, bpal in BROS.items():
            body = [o for o in live if o["pal"] == bpal]
            if not body:
                continue
            x0 = min(o["x"] for o in body); x1 = max(o["x"] + o["w"] for o in body)
            y1 = max(o["y"] + o["h"] for o in body)
            if x1 - x0 > 96:
                continue
            if vram is None:
                vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
                pal = dec.load_palette(f"{OAMDIR}/objpal_{tag}.bin")
            cell = render_4bpp(body, vram, pal, CELL, CELL,
                               ox=CELL // 2 - (x0 + x1) // 2, oy=FEET_Y - y1)
            Image.fromarray(cell, "RGBA").save(f"{OUT}/{bro}_{tag}.png")
            plist = poses[bro]
            for i, (t0, a0, cnt) in enumerate(plist):
                if np.array_equal(cell, a0):
                    plist[i] = (t0, a0, cnt + 1)
                    break
            else:
                plist.append((tag, cell, 1))
    for bro, plist in poses.items():
        print(f"{bro}: {len(plist)} unique poses")
        dec.contact_sheet([(f"{t} x{c}", a) for t, a, c in plist],
                          f"{OUT}/unique_{bro}_live.png")


if __name__ == "__main__":
    main()
