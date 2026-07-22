"""Mario & Luigi rebuilt ENTIRELY from the user's live M&L session at native
64x64 decode cells — replaces build_ml_attacks_live.py, whose 64->48px
recrop clipped hammer poses (the failed pass the user bounced).

Source: out/oam_ml_live/decoded. The castle-roam span (frames ~1300-3200)
had the bros swapping party lead, so the pal-1 "luigi_" channel carries
clean contiguous walk cycles for BOTH characters at one scale: green Luigi
first (avoid the red-tinted lava-room duplicates at 1627-1650), then red
Mario after the swap (with a hammer swing + leap smash). Mario's front
hammer slam and Firebrand punch come from his pal-0 "mario_" channel.
Picks verified on luigi_roam.png + build preview.

Sheets are 64x64 cells, pivot (32,56) — nothing is recropped, so wide
hammer arcs keep their heads. Walk cycles play A-B-C-B.

Run: .venv312/Scripts/python tools/build_ml_live64.py [--analyze]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
LIVE = ROOT / "tools/rom_ref/out/oam_ml_live/decoded"
PREVIEW = LIVE / "build64_preview.png"

CELL = 64
COLS = 8
PIVOT = [32, 56]

# (anim, [(file, mirror)], fps, loop)
HEROES = {
    "mario": [
        ("idle_down", [("luigi_live_002216", 0)], 3, True),
        ("walk_down", [("luigi_live_002257", 0), ("luigi_live_002278", 0), ("luigi_live_002283", 0)], 10, True),
        ("idle_side", [("luigi_live_002483", 0)], 3, True),
        ("walk_side", [("luigi_live_002474", 0), ("luigi_live_002486", 0), ("luigi_live_002496", 0)], 10, True),
        ("idle_up", [("luigi_live_002826", 0)], 3, True),
        ("walk_up", [("luigi_live_002528", 0), ("luigi_live_002532", 0), ("luigi_live_002528", 0)], 10, True),
        # front-facing overhead hammer slam (pal-0 channel)
        ("attack_1_down", [("mario_live_002113", 0), ("mario_live_002121", 0), ("mario_live_002141", 0)], 10, False),
        # side hammer swing (faces left in source)
        ("attack_1_side", [("luigi_live_002420", 1), ("luigi_live_002424", 1), ("luigi_live_002430", 1)], 10, False),
        # Firebrand flame punch (pal-0 channel, faces left)
        ("attack_2_side", [("mario_live_002251", 1), ("mario_live_002436", 1), ("mario_live_002436", 1)], 10, False),
    ],
    "luigi": [
        ("idle_down", [("luigi_live_001301", 0)], 3, True),
        ("walk_down", [("luigi_live_001308", 0), ("luigi_live_001305", 0), ("luigi_live_001316", 0)], 10, True),
        ("idle_side", [("luigi_live_001468", 1)], 3, True),
        ("walk_side", [("luigi_live_001470", 1), ("luigi_live_001473", 1), ("luigi_live_001476", 1)], 10, True),
        ("idle_up", [("luigi_live_001512", 0)], 3, True),
        ("walk_up", [("luigi_live_001591", 0), ("luigi_live_001600", 0), ("luigi_live_001611", 0)], 10, True),
        # overhead hammer smash (faces left in source)
        ("attack_1_side", [("luigi_live_001661", 1), ("luigi_live_001663", 1), ("luigi_live_001674", 1)], 10, False),
    ],
}


def load_cell(name: str, mirror: int) -> Image.Image:
    im = Image.open(LIVE / f"{name}.png").convert("RGBA")
    assert im.size == (CELL, CELL), f"{name} is {im.size}"
    return ImageOps.mirror(im) if mirror else im


def analyze() -> None:
    import numpy as np
    sys.path.insert(0, str(ROOT / "tools/rom_ref"))
    import decode_oam_dbz as dec
    imgs = []
    for hid, anims in HEROES.items():
        for name, frames, _, _ in anims:
            for fname, mirror in frames:
                imgs.append((f"{hid[0]}:{name[:9]}:{fname.split('_')[-1]}",
                             np.array(load_cell(fname, mirror))))
    dec.contact_sheet(imgs, str(PREVIEW))
    print(f"preview: {PREVIEW}")


def build() -> None:
    for hid, anims in HEROES.items():
        cells = []
        for _, frames, _, _ in anims:
            for fm in frames:
                if fm not in cells:
                    cells.append(fm)
        rows = (len(cells) + COLS - 1) // COLS
        sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
        cell_of = {}
        for i, fm in enumerate(cells):
            r, c = divmod(i, COLS)
            sheet.alpha_composite(load_cell(*fm), (c * CELL, r * CELL))
            cell_of[fm] = i
        out = ROOT / f"assets/franchises/mario/processed/sheets/{hid}.png"
        sheet.save(out)
        manifest = {
            "asset_id": hid,
            "sheet": f"res://assets/franchises/mario/processed/sheets/{hid}.png",
            "native_scale": 1,
            "display_scale": 1,
            "pivot": PIVOT,
            "grid": {"frame_width": CELL, "frame_height": CELL,
                     "columns": COLS, "rows": rows},
            "animations": {},
        }
        for name, frames, fps, loop in anims:
            idxs = [cell_of[fm] for fm in frames]
            if name.startswith("walk") and len(idxs) == 3:
                idxs = [idxs[0], idxs[1], idxs[2], idxs[1]]
            manifest["animations"][name] = {"frames": idxs, "fps": fps, "loop": loop}
        (ROOT / f"assets/franchises/mario/manifests/{hid}.json").write_text(
            json.dumps(manifest, indent=1, ensure_ascii=False) + "\n",
            encoding="utf-8", newline="\n")
        print(f"{hid}: {len(cells)} cells, rows={rows}")


if __name__ == "__main__":
    if "--analyze" in sys.argv:
        analyze()
    else:
        build()
