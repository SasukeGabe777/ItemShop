"""DBZ dungeon enemy + boss art from the spriters-resource LoG II rips
(assets/franchises/dragon_ball/raw/enemies/sprite_*.png, downloaded by the
user via sprite_resource_downloader).

Sheet anatomy (verified on keyed crops): a checkerboard of background squares
— mint (52,188,136) + bright mint (71,255,187), with dark navy (40,40,64)
squares on some sheets — one pose per checker square (32px for small enemies,
64px for the dinosaurs and Perfect Cell), sprites sometimes bleeding a pixel
or two into neighbouring squares. Isolation: global key of the three
background colours, then a fixed-grid cut with a small margin and
largest-component cleanup per cell.

Roster reality (this game has no saibamen or Frieza soldiers — those are
Legacy of Goku 1): rr_robot=Eggbot, cell_junior=Cell Jr, dbz_dinosaur=T-Rex,
saibaman->dbz_wolf (Wolf), frieza_soldier->sabertooth_tiger, and the boss
great_ape_vegeta (LoG 1, no art source) -> perfect_cell, whose arena is
already the dungeon's boss room. Data updates happen in
wire_dbz_enemy_data.py to keep this file art-only.

Run: .venv312/Scripts/python tools/prep_dbz_enemies.py [--analyze]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import largest_component

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets/franchises/dragon_ball/raw/enemies"
SHEETS = ROOT / "assets/franchises/dragon_ball/processed/sheets"
MANIFESTS = ROOT / "assets/franchises/dragon_ball/manifests"
PREVIEW = ROOT / "tools/rom_ref/out/oam_dbz/decoded/builder_preview"

BG = [np.array(c) for c in ([52, 188, 136], [71, 255, 187], [42, 150, 108], [40, 40, 64])]

# per enemy: source sheet, checker square, and anim picks as lists of
# (row, col, mirror) grid cells of the canonical palette variant — chosen off
# the labeled grid_<name>.png sheets. Side-facing rows in these rips face
# LEFT (mirror=1 makes manifest side anims face right, engine flips for
# left). walk cycles play A-B-C-B via the builder.
ENEMIES = {
    "cell_junior": {"src": "cell_jr", "sq": 32, "anims": {
        "idle_down": [(1, 0, 0)],
        "walk_down": [(1, 1, 0), (1, 2, 0), (1, 3, 0)],
        "idle_side": [(2, 0, 1)],
        "walk_side": [(2, 1, 1), (2, 2, 1), (2, 3, 1)],
    }},
    "rr_robot": {"src": "eggbot", "sq": 32, "anims": {
        "idle_down": [(0, 0, 0)],
        "walk_down": [(0, 1, 0), (0, 2, 0), (0, 3, 0)],
        "idle_side": [(1, 0, 1)],
        "walk_side": [(1, 1, 1), (1, 2, 1), (1, 3, 1)],
        "idle_up": [(3, 3, 0)],
        "walk_up": [(3, 4, 0), (3, 5, 0), (3, 6, 0)],
    }},
    "dbz_wolf": {"src": "wolf", "sq": 32, "anims": {
        "idle_down": [(0, 0, 0)],
        "walk_down": [(0, 1, 0), (0, 2, 0), (0, 3, 0)],
        "idle_side": [(1, 0, 1)],
        "walk_side": [(1, 1, 1), (1, 2, 1), (1, 3, 1)],
        "idle_up": [(3, 10, 0)],
        "walk_up": [(3, 10, 0), (3, 11, 0), (3, 12, 0)],
    }},
    "sabertooth_tiger": {"src": "sabertooth_tiger", "sq": 32, "anims": {
        "idle_down": [(0, 0, 0)],
        "walk_down": [(0, 1, 0), (0, 2, 0), (0, 3, 0)],
        "idle_side": [(1, 0, 1)],
        "walk_side": [(1, 1, 1), (1, 2, 1), (1, 3, 1)],
        "idle_up": [(3, 0, 0)],
        "walk_up": [(3, 1, 0), (3, 2, 0), (3, 4, 0)],
    }},
    "dbz_dinosaur": {"src": "t_rex", "sq": 64, "anims": {
        "idle_down": [(0, 0, 0)],
        "walk_down": [(0, 1, 0), (0, 2, 0), (0, 3, 0)],
        "idle_side": [(1, 0, 1)],
        "walk_side": [(1, 1, 1), (1, 2, 1), (1, 3, 1)],
        "idle_up": [(3, 4, 0)],
        "walk_up": [(3, 4, 0), (3, 5, 0), (3, 6, 0)],
    }},
    "perfect_cell": {"src": "cell_perfect", "sq": 64, "anims": {
        "idle_down": [(0, 0, 0)],
        "walk_down": [(0, 1, 0), (0, 2, 0), (0, 3, 0)],
        "idle_up": [(1, 0, 0)],
        "walk_up": [(1, 1, 0), (1, 2, 0), (1, 1, 0)],
        "idle_side": [(3, 0, 1)],
        "walk_side": [(3, 2, 1), (3, 3, 1), (3, 2, 1)],
    }},
}


def load_grid(name: str, sq: int):
    a = np.array(Image.open(RAW / f"sprite_{name}.png").convert("RGBA"))
    r = a[..., 0].astype(int); g = a[..., 1].astype(int); b = a[..., 2].astype(int)
    # backgrounds are the teal/mint family (g dominant AND blue over red —
    # excludes Perfect Cell's yellow-green body, where r > b) plus dark navy
    bg = (g > r + 60) & (b > r) & (b < g) & (g > 90)
    bg |= (np.abs(a[..., :3].astype(int) - BG[-1]).sum(axis=2) < 45)
    chk = np.zeros(a.shape[:2], bool)
    for c in BG[:2]:
        chk |= (np.abs(a[..., :3].astype(int) - c).sum(axis=2) < 45)
    rows = np.where(chk.any(axis=1))[0]
    cols = np.where(chk.any(axis=0))[0]
    y0, x0 = int(rows.min()), int(cols.min())
    a = a.copy()
    a[bg] = 0
    return a, y0, x0


def cell_img(a, y0, x0, sq, r, c, margin=6):
    y = y0 + r * sq
    x = x0 + c * sq
    crop = a[max(0, y - margin):y + sq + margin, max(0, x - margin):x + sq + margin]
    im = largest_component(Image.fromarray(crop))
    box = im.getbbox()
    return im.crop(box) if box else None


def analyze() -> None:
    from PIL import ImageDraw
    for name, sq in [("cell_jr", 32), ("eggbot", 32), ("wolf", 32),
                     ("sabertooth_tiger", 32), ("t_rex", 64), ("cell_perfect", 64)]:
        a, y0, x0 = load_grid(name, sq)
        H = (a.shape[0] - y0) // sq
        W = (a.shape[1] - x0) // sq
        scale = 2 if sq == 32 else 1
        out = Image.new("RGB", ((W * (sq + 14)) * scale, (H * (sq + 14)) * scale), (44, 44, 60))
        d = ImageDraw.Draw(out)
        for r in range(H):
            for c in range(W):
                im = cell_img(a, y0, x0, sq, r, c)
                if im is None or im.width * im.height < 60:
                    continue
                px = c * (sq + 14) * scale
                py = r * (sq + 14) * scale
                big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
                out.paste(big, (px + 2, py + 12), big)
                d.text((px + 2, py + 1), f"{r},{c}", fill=(255, 255, 0))
        out.save(PREVIEW / f"grid_{name}.png")
        print(f"grid_{name}.png: {H} rows x {W} cols (sq={sq})")


def collect(eid: str, spec: dict):
    """-> ordered {(r,c,mirror): Image} for every referenced cell."""
    from PIL import ImageOps
    a, y0, x0 = load_grid(spec["src"], spec["sq"])
    cells = {}
    for frames in spec["anims"].values():
        for key in frames:
            if key in cells:
                continue
            r, c, mirror = key
            im = cell_img(a, y0, x0, spec["sq"], r, c)
            if im is None or im.width * im.height < 60:
                raise SystemExit(f"{eid}: empty cell {r},{c}")
            cells[key] = ImageOps.mirror(im) if mirror else im
    return cells


def verify() -> None:
    import numpy as np_
    sys.path.insert(0, str(ROOT / "tools/rom_ref"))
    import decode_oam_dbz as dec
    imgs = []
    for eid, spec in ENEMIES.items():
        cells = collect(eid, spec)
        for name, frames in spec["anims"].items():
            for key in frames:
                arr = np_.array(cells[key].convert("RGBA"))
                imgs.append((f"{eid[:8]}:{name[:7]}:{key[0]},{key[1]}", arr))
    dec.contact_sheet(imgs, str(PREVIEW / "enemy_picks.png"))
    print(f"verification: {PREVIEW / 'enemy_picks.png'} ({len(imgs)} frames)")


def build() -> None:
    for eid, spec in ENEMIES.items():
        cells = collect(eid, spec)
        w = max(im.width for im in cells.values()) + 4
        h = max(im.height for im in cells.values()) + 4
        order = list(cells)
        sheet = Image.new("RGBA", (len(order) * w, h), (0, 0, 0, 0))
        for i, key in enumerate(order):
            im = cells[key]
            sheet.paste(im, (i * w + (w - im.width) // 2, h - 2 - im.height), im)
        SHEETS.mkdir(parents=True, exist_ok=True)
        sheet.save(SHEETS / f"{eid}.png")
        anims = {}
        for name, frames in spec["anims"].items():
            idxs = [order.index(k) for k in frames]
            if name.startswith("walk") and len(idxs) == 3:
                idxs = [idxs[0], idxs[1], idxs[2], idxs[1]]  # A-B-C-B gait
            anims[name] = {"frames": idxs, "fps": 6 if name.startswith("walk") else 3,
                           "loop": True}
        manifest = {
            "asset_id": eid,
            "sheet": f"res://assets/franchises/dragon_ball/processed/sheets/{eid}.png",
            "native_scale": 1,
            "display_scale": 1,
            "pivot": [w // 2, h - 2],
            "grid": {"frame_width": w, "frame_height": h,
                     "columns": len(order), "rows": 1},
            "animations": anims,
        }
        (MANIFESTS / f"{eid}.json").write_text(
            json.dumps(manifest, indent=1, ensure_ascii=False) + "\n",
            encoding="utf-8", newline="\n")
        print(f"{eid}: {len(order)} cells {w}x{h} -> sheets/{eid}.png")


def main() -> None:
    if "--analyze" in sys.argv:
        analyze()
    elif "--verify" in sys.argv:
        verify()
    else:
        build()


if __name__ == "__main__":
    main()
