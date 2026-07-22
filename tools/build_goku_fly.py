"""Rebuild Goku's appended frames: eyes-open idle + flight, idempotently.

Two playtest fixes live here:
  * Goku's default idle used an eyes-closed blink frame (he looked asleep). We
    graft a clean eyes-open front idle from the raw rip and make idle_down mostly
    open with an occasional blink.
  * flight was mirrored the wrong way (flew backwards). The engine's convention
    is base-frames-face-RIGHT (flip_h when moving left), so the left-facing raw
    fly frames are mirrored here.

Idempotent: frames 0..48 are copied cell-by-cell from the current sheet, every
later cell is cleared, then idle+fly are re-appended. Re-running never
duplicates or drifts. fly dodge is wired via data/heroes.json (dodge.kind=fly).

Run: .venv312\\Scripts\\python.exe tools/build_goku_fly.py
"""
import json
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
RAW_FLY = ROOT / "assets/franchises/dragon_ball/raw/Heroes/goku-fly.png"
RAW_SHEET = ROOT / "assets/franchises/dragon_ball/raw/Heroes/sprite_goku.png"
SHEET = ROOT / "assets/franchises/dragon_ball/processed/sheets/goku.png"
MANIFEST = ROOT / "assets/franchises/dragon_ball/manifests/goku.json"

CELL = 48
COLS = 8
BASE_COUNT = 49            # real frames 0..48 (idle/walk/attack/special)
FLY_BOTTOM = 36            # lift the horizontal flight pose off the feet line
FEET_Y = 40                # feet line in a cell (matches manifest pivot)

FLY_PICKS = {
    "down": [(0, 0), (0, 1), (0, 2), (0, 3)],
    "side": [(1, 0), (1, 1), (1, 2), (1, 3)],   # face left in the raw -> mirror
    "up":   [(3, 0), (3, 1), (3, 2), (3, 3)],
}


def _runs(occ):
    segs, i, n = [], 0, len(occ)
    while i < n:
        if occ[i]:
            j = i
            while j < n and occ[j]:
                j += 1
            segs.append((i, j - 1)); i = j
        else:
            i += 1
    return segs


def _fly_boxes():
    im = Image.open(RAW_FLY).convert("RGBA")
    a = np.array(im); mask = a[:, :, 3] > 16
    boxes = {}
    for r, (y0, y1) in enumerate(_runs(mask.any(1))):
        band = mask[y0:y1 + 1, :]
        for c, (x0, x1) in enumerate(_runs(band.any(0))):
            sub = mask[y0:y1 + 1, x0:x1 + 1]
            ys = np.where(sub.any(1))[0]
            boxes[(r, c)] = (x0, y0 + int(ys.min()), x1, y0 + int(ys.max()))
    return im, boxes


def _cell(crop, bottom):
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.alpha_composite(crop, ((CELL - crop.width) // 2, bottom - crop.height))
    return cell


def _idle_open_frame():
    """Extract the clean eyes-open front idle (raw cell 0) and feet-align it."""
    raw = Image.open(RAW_SHEET).convert("RGBA")
    crop = raw.crop((0, 32, 32, 64)).convert("RGBA")
    ca = np.array(crop)
    # the sprite cell's chroma (mint ~71,255,187) differs from the sheet corner
    # — sample it from this cell's own corner so the key actually catches it
    bg = ca[0, 0, :3]
    keyed = np.abs(ca[:, :, :3].astype(int) - bg).sum(2) <= 90
    ca[keyed] = [0, 0, 0, 0]
    frame = Image.fromarray(ca)
    fa = np.array(frame); ys, xs = np.where(fa[:, :, 3] > 16)
    tight = frame.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    return _cell(tight, FEET_Y)


def main():
    src = Image.open(SHEET).convert("RGBA")
    # clean base: copy frames 0..48, blank everything after
    base = Image.new("RGBA", (COLS * CELL, 7 * CELL), (0, 0, 0, 0))
    for i in range(BASE_COUNT):
        sx, sy = (i % COLS) * CELL, (i // COLS) * CELL
        base.alpha_composite(src.crop((sx, sy, sx + CELL, sy + CELL)),
                             ((i % COLS) * CELL, (i // COLS) * CELL))

    plan = [("idle_open", _idle_open_frame())]
    fly_im, boxes = _fly_boxes()
    fly_anims = {"down": [], "side": [], "up": []}
    for d in ("down", "side", "up"):
        for rc in FLY_PICKS[d]:
            crop = fly_im.crop(boxes[rc])
            if d == "side":
                crop = crop.transpose(Image.FLIP_LEFT_RIGHT)   # face right
            plan.append((("fly_%s" % d), _cell(crop, FLY_BOTTOM)))

    need = BASE_COUNT + len(plan)
    rows = max(7, (need + COLS - 1) // COLS)
    out = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    out.alpha_composite(base, (0, 0))
    idx = BASE_COUNT
    idle_open_idx = None
    for tag, cell in plan:
        out.alpha_composite(cell, ((idx % COLS) * CELL, (idx // COLS) * CELL))
        if tag == "idle_open":
            idle_open_idx = idx
        else:
            fly_anims[tag.split("_")[1]].append(idx)
        idx += 1
    out.save(SHEET)

    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    m["grid"]["rows"] = rows
    # eyes-open idle with an occasional blink (old closed frame 0)
    m["animations"]["idle_down"] = {
        "frames": [idle_open_idx] * 9 + [0], "fps": 5, "loop": True}
    for d in ("down", "side", "up"):
        m["animations"]["fly_%s" % d] = {"frames": fly_anims[d], "fps": 10, "loop": True}
    MANIFEST.write_text(json.dumps(m, indent=1) + "\n", encoding="utf-8")
    print("sheet -> %s rows=%d; idle_open=%d fly=%s" % (out.size, rows, idle_open_idx, fly_anims))


if __name__ == "__main__":
    main()
