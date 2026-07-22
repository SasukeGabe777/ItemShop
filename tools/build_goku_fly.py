"""Append Goku's flight frames to his existing sprite sheet + manifest.

Source: assets/franchises/dragon_ball/raw/Heroes/goku-fly.png (a 4x8 transparent
sheet, user-supplied). We take three clean 4-frame runs — down (face to camera),
side (left profile; the engine mirrors it for right), up (back of head) — and
append them after the existing frames (0..48) in processed/sheets/goku.png,
extending the grid by one row. Existing frame indices are untouched, so all
current anims keep working; we only add fly_down/fly_side/fly_up.

Run: .venv312\\Scripts\\python.exe tools/build_goku_fly.py
Re-runnable: it rebuilds the sheet from the current processed sheet + raw fly art.
"""
import json
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets/franchises/dragon_ball/raw/Heroes/goku-fly.png"
SHEET = ROOT / "assets/franchises/dragon_ball/processed/sheets/goku.png"
MANIFEST = ROOT / "assets/franchises/dragon_ball/manifests/goku.json"

CELL = 48
PIVOT_Y = 40          # feet line in a cell
FLY_BOTTOM = 36       # lift the horizontal flight pose a little off the feet line

# (row, col) picks from the raw sheet, per direction, in animation order
PICKS = {
    "down": [(0, 0), (0, 1), (0, 2), (0, 3)],
    "side": [(1, 0), (1, 1), (1, 2), (1, 3)],
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


def _segment(im):
    """Return {(row,col): (x0,y0,x1,y1)} tight bboxes for every frame."""
    a = np.array(im); mask = a[:, :, 3] > 16
    boxes = {}
    for r, (y0, y1) in enumerate(_runs(mask.any(1))):
        band = mask[y0:y1 + 1, :]
        for c, (x0, x1) in enumerate(_runs(band.any(0))):
            sub = mask[y0:y1 + 1, x0:x1 + 1]
            ys = np.where(sub.any(1))[0]
            boxes[(r, c)] = (x0, y0 + int(ys.min()), x1, y0 + int(ys.max()))
    return boxes


def _place(crop):
    """Center a fly crop horizontally in a 48x48 cell, bottom near FLY_BOTTOM."""
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = (CELL - crop.width) // 2
    py = FLY_BOTTOM - crop.height
    cell.alpha_composite(crop, (max(0, px), max(0, py)))
    return cell


def main():
    raw = Image.open(RAW).convert("RGBA")
    boxes = _segment(raw)
    sheet = Image.open(SHEET).convert("RGBA")
    cols = sheet.width // CELL
    rows_old = sheet.height // CELL
    assert cols == 8, f"expected 8 cols, got {cols}"

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    used = max(max(a["frames"]) for a in manifest["animations"].values())
    start = used + 1  # first free frame index

    order = [("down", d) for d in [None]]  # placeholder to keep flat order below
    flat = []  # (dir, (r,c))
    for d in ("down", "side", "up"):
        for rc in PICKS[d]:
            flat.append((d, rc))

    need = start + len(flat)
    rows_new = (need + cols - 1) // cols
    rows_new = max(rows_new, rows_old)
    out = Image.new("RGBA", (cols * CELL, rows_new * CELL), (0, 0, 0, 0))
    out.alpha_composite(sheet, (0, 0))  # keep frames 0..used byte-identical

    anims = {"down": [], "side": [], "up": []}
    idx = start
    for d, rc in flat:
        crop = raw.crop(boxes[rc])
        col = idx % cols; row = idx // cols
        out.alpha_composite(_place(crop), (col * CELL, row * CELL))
        anims[d].append(idx)
        idx += 1

    out.save(SHEET)

    manifest["grid"]["rows"] = rows_new
    for d in ("down", "side", "up"):
        manifest["animations"][f"fly_{d}"] = {"frames": anims[d], "fps": 10, "loop": True}
    MANIFEST.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")

    print(f"sheet {sheet.size} -> {out.size} ({rows_old}->{rows_new} rows)")
    print(f"fly frames start at {start}: {anims}")


if __name__ == "__main__":
    main()
