"""Wire Mario & Luigi animations from the user's live M&L recording
(out/oam_ml_live, decoded per-bro by decode_oam_ml_live.py).

Mario: patches REAL hammer + Firebrand attacks into his existing
captured-walk sheet (the old rip attack cells are replaced in place).
Luigi: full sheet rebuild from live frames — his old sheet was rip-scale
art; mixing it with field-scale live attacks would repeat the Sora
scale-pop bug, so walks/idles/hammer all come from the recording.

All picks verified on luigi_w1/w2, luigi_hammer_strip2, mario_hammer_strip
contact sheets. Left-facing sources are mirrored (side anims face right).

Run: .venv312/Scripts/python tools/build_ml_attacks_live.py [--analyze]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
LIVE = ROOT / "tools/rom_ref/out/oam_ml_live/decoded"
PREVIEW = LIVE / "build_preview.png"

CELL = 48
COLS = 8
PIVOT = [24, 40]

# ---- Mario: attack patch (existing sheet keeps cells 0-26 = idles+walks) --
MARIO_SHEET = ROOT / "assets/franchises/mario/processed/sheets/mario.png"
MARIO_MANIFEST = ROOT / "assets/franchises/mario/manifests/mario.json"
MARIO_FIRST = 27
MARIO_ANIMS = [
    # front-facing overhead hammer slam
    ("attack_1_down", [("mario_live_002113", 0), ("mario_live_002121", 0), ("mario_live_002141", 0)], 10, False),
    # side hammer swing (source faces left)
    ("attack_1_side", [("mario_live_002176", 1), ("mario_live_002178", 1), ("mario_live_002194", 1)], 10, False),
    # Firebrand flame punch (windup + flame-ring jab, source faces left)
    ("attack_2_side", [("mario_live_002251", 1), ("mario_live_002436", 1), ("mario_live_002436", 1)], 10, False),
]
MARIO_DROP = ["attack_2_down"]

# ---- Luigi: full live rebuild ---------------------------------------------
LUIGI_SHEET = ROOT / "assets/franchises/mario/processed/sheets/luigi.png"
LUIGI_MANIFEST = ROOT / "assets/franchises/mario/manifests/luigi.json"
LUIGI_ANIMS = [
    ("idle_down", [("luigi_live_005305", 0)], 3, True),
    ("idle_side", [("luigi_live_000126", 1)], 3, True),
    ("idle_up", [("luigi_live_001050", 0)], 3, True),
    # front pendulum: stride A -> stand -> stride B -> stand
    ("walk_down", [("luigi_live_005384", 0), ("luigi_live_005305", 0),
                   ("luigi_live_005560", 0), ("luigi_live_005305", 0)], 10, True),
    ("walk_side", [("luigi_live_000870", 1), ("luigi_live_000873", 1),
                   ("luigi_live_000878", 1), ("luigi_live_000881", 1)], 10, True),
    ("walk_up", [("luigi_live_000920", 0), ("luigi_live_000926", 0),
                 ("luigi_live_000929", 0), ("luigi_live_000937", 0)], 10, True),
    # overhead smash (raise -> vertical -> smash forward), source faces left
    ("attack_1_side", [("luigi_live_001061", 1), ("luigi_live_001063", 1),
                       ("luigi_live_001066", 1)], 10, False),
    # second hammer style: level swing out (windup -> out -> extended)
    ("attack_2_side", [("luigi_live_001663", 1), ("luigi_live_001674", 1),
                       ("luigi_live_001682", 1)], 10, False),
]


def load_cell(name: str, mirror: int) -> Image.Image:
    """Live decode cells are 64x64 feet-at-(32,56); recrop to the mario-sheet
    convention 48x48 feet-at-(24,40)."""
    im = Image.open(LIVE / f"{name}.png").convert("RGBA")
    if mirror:
        im = ImageOps.mirror(im)
    return im.crop((32 - PIVOT[0], 56 - PIVOT[1], 32 - PIVOT[0] + CELL,
                    56 - PIVOT[1] + CELL))


def patch_mario() -> None:
    doc = json.loads(MARIO_MANIFEST.read_text(encoding="utf-8"))
    cols = doc["grid"]["columns"]
    fw, fh = doc["grid"]["frame_width"], doc["grid"]["frame_height"]
    assert (fw, fh) == (CELL, CELL)
    cells = []
    for _, frames, _, _ in MARIO_ANIMS:
        for fm in frames:
            if fm not in cells:
                cells.append(fm)
    total = MARIO_FIRST + len(cells)
    rows = (total + cols - 1) // cols
    sheet = Image.open(MARIO_SHEET).convert("RGBA")
    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    out.paste(sheet.crop((0, 0, cols * fw, min(sheet.height, rows * fh))), (0, 0))
    for idx in range(MARIO_FIRST, rows * cols):
        r, c = divmod(idx, cols)
        out.paste(Image.new("RGBA", (fw, fh), (0, 0, 0, 0)), (c * fw, r * fh))
    cell_of = {}
    for i, (name, mirror) in enumerate(cells):
        idx = MARIO_FIRST + i
        r, c = divmod(idx, cols)
        out.paste(load_cell(name, mirror), (c * fw, r * fh))
        cell_of[(name, mirror)] = idx
    out.save(MARIO_SHEET)
    anims = doc["animations"]
    for n in MARIO_DROP:
        anims.pop(n, None)
    for name, frames, fps, loop in MARIO_ANIMS:
        anims[name] = {"frames": [cell_of[fm] for fm in frames], "fps": fps, "loop": loop}
    doc["grid"]["rows"] = rows
    MARIO_MANIFEST.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n",
                              encoding="utf-8", newline="\n")
    print(f"mario: {len(cells)} live attack cells at {MARIO_FIRST}+, rows={rows}")


def build_luigi() -> None:
    cells = []
    for _, frames, _, _ in LUIGI_ANIMS:
        for fm in frames:
            if fm not in cells:
                cells.append(fm)
    rows = (len(cells) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    cell_of = {}
    for i, (name, mirror) in enumerate(cells):
        r, c = divmod(i, COLS)
        sheet.alpha_composite(load_cell(name, mirror), (c * CELL, r * CELL))
        cell_of[(name, mirror)] = i
    sheet.save(LUIGI_SHEET)
    manifest = {
        "asset_id": "luigi",
        "sheet": "res://assets/franchises/mario/processed/sheets/luigi.png",
        "native_scale": 1,
        "display_scale": 1,
        "pivot": PIVOT,
        "grid": {"frame_width": CELL, "frame_height": CELL,
                 "columns": COLS, "rows": rows},
        "animations": {name: {"frames": [cell_of[fm] for fm in frames],
                              "fps": fps, "loop": loop}
                       for name, frames, fps, loop in LUIGI_ANIMS},
    }
    LUIGI_MANIFEST.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n",
                              encoding="utf-8", newline="\n")
    print(f"luigi: full live rebuild, {len(cells)} cells, rows={rows}")


def analyze() -> None:
    import numpy as np
    sys.path.insert(0, str(ROOT / "tools/rom_ref"))
    import decode_oam_dbz as dec
    imgs = []
    for name, frames, _, _ in MARIO_ANIMS + LUIGI_ANIMS:
        for fname, mirror in frames:
            imgs.append((f"{name[:9]}:{fname.split('_')[-1]}",
                         np.array(load_cell(fname, mirror))))
    dec.contact_sheet(imgs, str(PREVIEW))
    print(f"preview: {PREVIEW}")


if __name__ == "__main__":
    if "--analyze" in sys.argv:
        analyze()
    else:
        patch_mario()
        build_luigi()
