"""Mario + Luigi rebuild from the user's labeled sheet (2026-07-22 drop,
assets/franchises/mario/raw/heroes/mario_luigi_new.png) — playtest verdict on
the old capture-derived sheets: "completely broken".

Sheet layout (user-authored, transparent bg + black section boxes + labels):
two character columns (Mario left, Luigi right), sections per column:
  Idle & Movement (5 direction rows x 8 walk frames), melee_side, melee_up,
  melee_down, special_side, special_down, special_up.

Usage:  grid  -> labeled cells to LOOK at;   build -> sheets + manifests.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import compose_grid, find_islands, load_rgba
from prep_pokemon_world import strip_straight_black_lines

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "assets/franchises/mario/raw/heroes/mario_luigi_new.png"
PROCESSED = ROOT / "assets/franchises/mario/processed"
MANIFESTS = ROOT / "assets/franchises/mario/manifests"
SCRATCH = Path(os.environ.get("CLAUDE_JOB_DIR", str(ROOT / "tools"))) / "tmp" / "ml_contacts"

# character x-split; sections assigned by island top-edge y within a column
X_SPLIT = 370


def _cells() -> tuple[Image.Image, dict[str, tuple[int, int, int, int]]]:
    img = strip_straight_black_lines(load_rgba(SHEET))
    boxes = find_islands(img, min_area=40, merge_gap=1)
    # drop label text: achromatic islands
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
    named: dict[str, tuple[int, int, int, int]] = {}
    for who, lo, hi in (("m", 0, X_SPLIT), ("l", X_SPLIT, 10000)):
        bs = [b for b in boxes if lo <= b[0] < hi]
        bs.sort(key=lambda b: b[1])
        rows: list[list] = []
        for b in bs:
            for row in rows:
                ry0 = min(x[1] for x in row); ry1 = max(x[3] for x in row)
                if b[1] < ry1 and b[3] > ry0:
                    row.append(b)
                    break
            else:
                rows.append([b])
        for r, row in enumerate(rows):
            row.sort(key=lambda b: b[0])
            for c, b in enumerate(row):
                named[f"{who}r{r}c{c}"] = tuple(b)
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
    out = SCRATCH / "grid_mario_luigi.png"
    bg.convert("RGB").save(out)
    print(len(named), "cells ->", out)


# Picks verified on grid_mario_luigi.png + mario_dirs.png + mario_actions.png:
# movement rows r0..r4 = S, SW, W, NW, N (side = flipped W); melee/special
# side rows face LEFT (flip). r5=melee_side, r6=melee_up, r7=melee_down,
# r8=special_side, r9=special_down, r10=special_up. "~" prefix = flip.
# dodge rows (r11, added by the user 2026-07-22 round 2): Mario = 8-frame
# 360° twirl (direction-agnostic -> plain "roll"); Luigi = 4-frame scramble
# facing RIGHT -> "roll_side" (up/down fall back through the roll chain)
def _char_picks(p: str, melee_down_seq: list, special_down_seq: list) -> dict:
    dodge = ({"roll": [f"mr11c{c}" for c in range(8)]} if p == "m"
             else {"roll_side": [f"lr11c{c}" for c in range(4)]})
    # playtest: Luigi's side cycle is authored right-to-left on the sheet —
    # played forward it moonwalks; reverse the frame order (Mario's is fine)
    side_cols = list(range(8)) if p == "m" else list(range(7, -1, -1))
    return {
        "cell": (56, 56),
        "anims": dodge | {
            "idle_down": [f"{p}r0c0"], "idle_up": [f"{p}r4c0"], "idle_side": [f"~{p}r2c0"],
            "walk_down": [f"{p}r0c{c}" for c in range(8)],
            "walk_up": [f"{p}r4c{c}" for c in range(8)],
            "walk_side": [f"~{p}r2c{c}" for c in side_cols],
            "attack_1_side": [f"~{p}r5c2", f"~{p}r5c4", f"~{p}r5c5"],
            "attack_1_up": [f"{p}r6c2", f"{p}r6c3", f"{p}r6c4"],
            "attack_1_down": [f"{p}r7c{c}" for c in melee_down_seq],
            "special_side": [f"~{p}r8c{c}" for c in range(5)],
            "special_down": [f"{p}r9c{c}" for c in special_down_seq],
            "special_up": [f"{p}r10c{c}" for c in range(5)],
        },
        "fps": {"walk_down": 12, "walk_up": 12, "walk_side": 12,
                "attack_1_down": 14, "attack_1_up": 14, "attack_1_side": 14,
                "special_down": 12, "special_up": 12, "special_side": 12,
                "roll": 24, "roll_side": 18},
        "loops": {"attack_1_down": False, "attack_1_up": False, "attack_1_side": False,
                  "special_down": False, "special_up": False, "special_side": False,
                  "roll": False, "roll_side": False},
    }


PICKS: dict[str, dict] = {
    "mario": _char_picks("m", [1, 3, 5], [0, 1, 2, 3]),
    "luigi": _char_picks("l", [1, 3, 5], [0, 1, 2, 3]),
}


def stage_build() -> None:
    if not PICKS:
        print("PICKS empty — run grid, look, fill.")
        return
    img, named = _cells()
    for name, spec in PICKS.items():
        ids = list(named.keys())
        boxes = [named[i] for i in ids]
        idx = {cid: n for n, cid in enumerate(ids)}
        anims = {}
        for anim, cells in spec["anims"].items():
            out = []
            for cid in cells:
                flip = cid.startswith("~")
                real = cid[1:] if flip else cid
                n = idx[real]
                out.append(-n - 1 if flip else n)
            anims[anim] = out
        compose_grid(
            img, boxes, anims, spec["cell"],
            PROCESSED / "sheets" / f"{name}.png",
            MANIFESTS / f"{name}.json",
            f"res://assets/franchises/mario/processed/sheets/{name}.png",
            fps=spec.get("fps"), loops=spec.get("loops"),
        )


if __name__ == "__main__":
    {"grid": stage_grid, "build": stage_build}[sys.argv[1] if len(sys.argv) > 1 else "grid"]()
