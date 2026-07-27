"""Wire the OMORI overworld avatar rips in assets/hero/raw/coop/ into clean, uniform
town/shop walking avatars for online co-op character select.

Each source sheet is a labelled charset: 3 walk-frame columns x 4 rows
(south/west/east/north = down/left/right/up), with the row's name written to the
right of the frames. Source cell pitch differs per sheet, so rather than trust a
grid we RE-PACK: for each of the 12 frames we find its content bounding box and
paste it feet-centred into a uniform 32x32 cell. Output is a 96x128 sheet plus a
manifest per character.

Re-runnable; never edits the raw sheets. Backgrounds are already transparent.

Run: .venv312\\Scripts\\python.exe tools\\prep_coop_avatars.py
"""
import json
import os
from PIL import Image
import numpy as np

RAW = "assets/hero/raw/coop"
OUT_SHEETS = "assets/hero/processed/coop"
OUT_MANIFESTS = "assets/hero/manifests"

CELL = 32
INNER = 30          # max content size inside a cell (1px margin each side)
FEET_Y = 31         # content bottom sits here within the 32px cell
ALPHA_HIT = 40

# id -> (filename, display name). The OMORI cast the user dropped in.
CHARACTERS = [
    ("sunny",      "sunny.png",      "Sunny"),
    ("aubrey",     "aubrey.png",     "Aubrey"),
    ("basil",      "basil.png",      "Basil"),
    ("kel",        "kel.png",        "Kel"),
    ("mari",       "mari.png",       "Mari"),
    ("angel",      "angel.png",      "Angel"),
    ("charlie",    "charlie.png",    "Charlie"),
    ("kim",        "kim.png",        "Kim"),
    ("maverick",   "maverick.png",   "Maverick"),
    ("spaceboy",   "spaceboy.png",   "Capt. Spaceboy"),
    ("sweetheart", "sweetheart.png", "Sweetheart"),
    ("vance",      "vance.png",      "Vance"),
]


def _runs(mask):
    out = []
    start = None
    for i, v in enumerate(mask):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(mask)))
    return out


def _bbox(alpha_sub):
    """Tight content bbox within a subregion, or None if empty."""
    ys = np.where(alpha_sub.any(axis=1))[0]
    xs = np.where(alpha_sub.any(axis=0))[0]
    if len(ys) == 0 or len(xs) == 0:
        return None
    return int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1


def repack(path: str) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    op = arr[:, :, 3] > ALPHA_HIT

    # four row bands (down/left/right/up) from full-width occupancy
    row_bands = [r for r in _runs(op.any(axis=1)) if r[1] - r[0] >= 10][:4]

    # The 3 walk-frame columns are the first three column clusters; the wide
    # cluster after them is the row-label text. Using the real clusters as the
    # frame slots (not equal thirds) keeps tightly-packed sheets from splitting
    # a frame across two slots.
    col_clusters = _runs(op.any(axis=0))
    if len(col_clusters) >= 3:
        slots = col_clusters[:3]
    else:  # frames touch — fall back to equal thirds of the pre-label region
        label_x = col_clusters[-1][0] if col_clusters else im.width
        slots = [(int(i * label_x / 3.0), int((i + 1) * label_x / 3.0)) for i in range(3)]

    out = Image.new("RGBA", (CELL * 3, CELL * 4), (0, 0, 0, 0))
    for row, (ry0, ry1) in enumerate(row_bands):
        for col, (sx0, sx1) in enumerate(slots):
            sub = op[ry0:ry1, sx0:sx1]
            bb = _bbox(sub)
            if bb is None:
                continue
            fx0, fy0, fx1, fy1 = bb
            frame = im.crop((sx0 + fx0, ry0 + fy0, sx0 + fx1, ry0 + fy1))
            # scale down only if the content is bigger than the inner box
            fw, fh = frame.size
            scale = min(1.0, INNER / max(fw, fh))
            if scale < 1.0:
                frame = frame.resize((max(1, int(round(fw * scale))),
                                      max(1, int(round(fh * scale)))), Image.NEAREST)
            fw, fh = frame.size
            dx = col * CELL + (CELL - fw) // 2
            dy = row * CELL + FEET_Y - fh
            out.alpha_composite(frame, (dx, max(0, dy)))
    return out


def manifest(aid: str) -> dict:
    return {
        "asset_id": "coop_%s" % aid,
        "character_id": aid,
        "source_game": "OMORI",
        "source_site": "The Spriters Resource",
        "sheet": "res://assets/hero/processed/coop/%s.png" % aid,
        "native_scale": 1,
        "display_scale": 1,
        "grid": {"frame_width": CELL, "frame_height": CELL, "columns": 3, "rows": 4},
        "pivot": [16, FEET_Y - 1],
        "layout_note": "Re-packed uniform 3x4 walk block (tools/prep_coop_avatars.py). "
                       "Rows: down, left, right, up. Side stored right-facing; engine flips for left.",
        "animations": {
            "idle_down": {"frames": [1], "fps": 3, "loop": True},
            "walk_down": {"frames": [0, 1, 2, 1], "fps": 7, "loop": True},
            "idle_side": {"frames": [7], "fps": 3, "loop": True},
            "walk_side": {"frames": [6, 7, 8, 7], "fps": 7, "loop": True},
            "idle_up": {"frames": [10], "fps": 3, "loop": True},
            "walk_up": {"frames": [9, 10, 11, 10], "fps": 7, "loop": True},
        },
        "side_flips_for_left": True,
    }


def main() -> None:
    os.makedirs(OUT_SHEETS, exist_ok=True)
    for aid, fname, _name in CHARACTERS:
        sheet = repack(os.path.join(RAW, fname))
        sheet.save(os.path.join(OUT_SHEETS, "%s.png" % aid))
        with open(os.path.join(OUT_MANIFESTS, "coop_%s.json" % aid), "w", newline="\n") as f:
            json.dump(manifest(aid), f, indent=2)
        opaque = int((np.array(sheet)[:, :, 3] > 0).sum())
        print("%-10s -> %s.png  (%d opaque px)" % (aid, aid, opaque))


if __name__ == "__main__":
    main()
