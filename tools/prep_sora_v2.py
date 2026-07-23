"""Sora rebuild from the user's labeled sheet (2026-07-22 round 3,
assets/franchises/kingdom_hearts/raw/heroes/sora_updated.png) — playtest:
"completely messed up other than his dodge roll which is perfect".

Sheet sections (user-authored labels): melee_forward/back/NW/side/SW (5
frames each), sora_special (thrown spinning keyblade — Strike Raid
projectile art, not body poses), idle front, and a movement box with
run front / SW / back / NW / side idles + 8-frame runs.

The dodge roll is PRESERVED: cells 33-38 of the old processed sheet are
copied pixel-identical into the rebuilt sheet before it is overwritten.
The best spinning-blade frame is exported as strike_raid_blade.png (the
projectile sprite heroes.json already points at).

Usage:  grid -> labeled cells;  build -> sheet + manifest + blade sprite.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import compose_grid, find_islands, load_rgba
from prep_pokemon_world import strip_straight_black_lines

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "assets/franchises/kingdom_hearts/raw/heroes/sora_updated.png"
OUT_SHEET = ROOT / "assets/franchises/kingdom_hearts/processed/sheets/sora.png"
MANIFEST = ROOT / "assets/franchises/kingdom_hearts/manifests/sora.json"
BLADE = ROOT / "assets/franchises/kingdom_hearts/processed/strike_raid_blade.png"
SCRATCH = Path(os.environ.get("CLAUDE_JOB_DIR", str(ROOT / "tools"))) / "tmp" / "sora"

CELL = (64, 84)
OLD_ROLL_FRAMES = [33, 34, 35, 36, 37, 38]  # "perfect" per playtest — keep


def _cells() -> tuple[Image.Image, dict[str, tuple[int, int, int, int]]]:
    img = strip_straight_black_lines(load_rgba(SHEET))
    boxes = find_islands(img, min_area=40, merge_gap=1)
    import numpy as np
    arr = np.array(img)

    def is_text(b):
        px = arr[b[1]:b[3], b[0]:b[2]]
        vis = px[px[..., 3] > 10]
        if len(vis) == 0:
            return True
        chroma = (vis[..., :3].max(axis=1).astype(int) - vis[..., :3].min(axis=1).astype(int)).mean()
        return chroma < 12

    boxes = [b for b in boxes if not is_text(b)]
    boxes.sort(key=lambda b: b[1])
    rows: list[list] = []
    for b in boxes:
        for row in rows:
            ry0 = min(x[1] for x in row); ry1 = max(x[3] for x in row)
            if b[1] < ry1 and b[3] > ry0:
                row.append(b)
                break
        else:
            rows.append([b])
    named: dict[str, tuple[int, int, int, int]] = {}
    for r, row in enumerate(rows):
        row.sort(key=lambda b: b[0])
        for c, b in enumerate(row):
            named[f"r{r}c{c}"] = tuple(b)
    # run-front frame 0 and the SW_facing idle touch vertically and merge
    # into one island (r3c5) — split it at the section boundary
    if "r3c5" in named:
        x0, y0, x1, y1 = named["r3c5"]
        if y1 - y0 > 60:
            named["r3c5top"] = (x0, y0, x1, y0 + 38)
            named["r3c5bot"] = (x0, y0 + 40, x1, y1)
    return img, named


def stage_grid() -> None:
    SCRATCH.mkdir(parents=True, exist_ok=True)
    img, named = _cells()
    scale = 2
    base = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    bg = Image.new("RGBA", base.size, (40, 40, 60, 255))
    bg.alpha_composite(base)
    d = ImageDraw.Draw(bg)
    for nid, (x0, y0, x1, y1) in named.items():
        d.rectangle([x0 * scale, y0 * scale, x1 * scale - 1, y1 * scale - 1], outline=(255, 0, 0, 255))
        d.text((x0 * scale + 1, y0 * scale + 1), nid, fill=(255, 255, 0, 255))
    out = SCRATCH / "grid_sora.png"
    bg.convert("RGB").save(out)
    print(len(named), "cells ->", out)


# Picks assigned by native-coordinate section mapping (see cell dump):
# melee rows face LEFT-family directions (side/SW/NW all left -> flip);
# movement box: run_front r3c5top..r3c12, SW_run r4 odd band, back_run r4
# lower band, NW_run r6, side_run r8 (faces LEFT -> flip).
PICKS: dict = {
    "anims": {
        "idle_down": ["r2c5"], "idle_up": ["r4c5"], "idle_side": ["~r7c0"],
        "walk_down": ["r3c5top", "r3c6", "r3c7", "r3c8", "r3c9", "r3c10", "r3c11", "r3c12"],
        "walk_up": ["r4c6", "r4c8", "r4c10", "r4c12", "r4c13", "r4c15", "r4c17", "r4c19"],
        "walk_side": ["~r8c0", "~r8c1", "~r8c2", "~r8c3", "~r8c4", "~r8c5", "~r8c6", "~r8c7"],
        "attack_1_down": ["r0c0", "r0c1", "r0c2", "r0c3", "r0c4"],
        "attack_1_up": ["r1c0", "r1c1", "r1c2", "r1c3", "r1c4"],
        "attack_1_side": ["~r3c0", "~r3c1", "~r3c2", "~r3c3", "~r3c4"],
        "attack_2_side": ["~r4c0", "~r4c1", "~r4c2", "~r4c3", "~r4c4"],
        "attack_2_up": ["~r2c0", "~r2c1", "~r2c2", "~r2c3", "~r2c4"],
        "special_down": ["r0c0", "r0c1"],
        "special_up": ["r1c0", "r1c1"],
        "special_side": ["~r3c0", "~r3c1"],
    },
    "fps": {"walk_down": 14, "walk_up": 14, "walk_side": 14,
            "attack_1_down": 16, "attack_1_up": 16, "attack_1_side": 16,
            "attack_2_side": 16, "attack_2_up": 16,
            "special_down": 10, "special_up": 10, "special_side": 10},
    "loops": {"attack_1_down": False, "attack_1_up": False, "attack_1_side": False,
              "attack_2_side": False, "attack_2_up": False,
              "special_down": False, "special_up": False, "special_side": False},
}
BLADE_CELL = "r0c6"


def stage_build() -> None:
    if not PICKS:
        print("PICKS empty — run grid, look, fill.")
        return
    # 1. preserve the old roll frames before the sheet is overwritten.
    # The OLD sheet uses its own grid (64x64, 8 cols) — read it from the old
    # manifest, NOT from CELL (using the new 84px height here once produced
    # garbage crops).
    old = Image.open(OUT_SHEET).convert("RGBA")
    old_manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    ow = old_manifest["grid"]["frame_width"]
    oh = old_manifest["grid"]["frame_height"]
    old_cols = old_manifest["grid"]["columns"]
    cw, ch = CELL
    roll_crops = []
    for f in OLD_ROLL_FRAMES:
        x = (f % old_cols) * ow
        y = (f // old_cols) * oh
        crop = old.crop((x, y, x + ow, y + oh))
        cell = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        # keep the roll pixels identical, feet-aligned in the taller new cell
        cell.alpha_composite(crop, ((cw - ow) // 2, ch - oh - 2))
        roll_crops.append(cell)
    # 2. compose the new sheet from the picks
    img, named = _cells()
    ids = list(named.keys())
    boxes = [named[i] for i in ids]
    idx = {cid: n for n, cid in enumerate(ids)}
    anims = {}
    for anim, cells in PICKS["anims"].items():
        out = []
        for cid in cells:
            flip = cid.startswith("~")
            real = cid[1:] if flip else cid
            n = idx[real]
            out.append(-n - 1 if flip else n)
        anims[anim] = out
    compose_grid(
        img, boxes, anims, CELL, OUT_SHEET, MANIFEST,
        "res://assets/franchises/kingdom_hearts/processed/sheets/sora.png",
        fps=PICKS.get("fps"), loops=PICKS.get("loops"),
    )
    # 3. append the preserved roll frames as new cells + manifest anim
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    grid = manifest["grid"]
    cols, rows = grid["columns"], grid["rows"]
    sheet = Image.open(OUT_SHEET).convert("RGBA")
    new_rows = (len(roll_crops) + cols - 1) // cols
    canvas = Image.new("RGBA", (cols * cw, (rows + new_rows) * ch), (0, 0, 0, 0))
    canvas.alpha_composite(sheet, (0, 0))
    indices = []
    fidx = rows * cols
    for crop in roll_crops:
        canvas.alpha_composite(crop, ((fidx % cols) * cw, (fidx // cols) * ch))
        indices.append(fidx)
        fidx += 1
    manifest["animations"]["roll_side"] = {"frames": indices, "fps": 12, "loop": False}
    grid["rows"] = rows + new_rows
    canvas.save(OUT_SHEET)
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(manifest, indent=1) + "\n")
    print(f"  roll preserved as frames {indices}")
    # 4. Strike Raid projectile: the full 11-frame spinning-keyblade strip
    # (playtest round 5: a single static frame read as "not working")
    spin_cells = [f"r0c{c}" for c in range(5, 16)]
    boxes2 = [named[c] for c in spin_cells]
    cw2 = max(b[2] - b[0] for b in boxes2)
    ch2 = max(b[3] - b[1] for b in boxes2)
    spin = Image.new("RGBA", (cw2 * len(boxes2), ch2), (0, 0, 0, 0))
    for n, b in enumerate(boxes2):
        crop = img.crop(b)
        spin.alpha_composite(crop, (n * cw2 + (cw2 - crop.width) // 2, (ch2 - crop.height) // 2))
    spin.save(BLADE.parent / "strike_raid_spin.png")
    print(f"  spin strip {len(boxes2)}x1 cells of {cw2}x{ch2} -> strike_raid_spin.png")
    if BLADE_CELL:
        blade = img.crop(named[BLADE_CELL])
        blade.save(BLADE)
        print(f"  blade sprite {blade.size} -> {BLADE}")


if __name__ == "__main__":
    {"grid": stage_grid, "build": stage_build}[sys.argv[1] if len(sys.argv) > 1 else "grid"]()
