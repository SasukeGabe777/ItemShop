"""Pokémon world extraction — heroes, enemies, bosses from the user's PMD-style
sheet downloads (2026-07-22 drop in assets/franchises/pokemon/raw/).

Sheets are Spriters-Resource PMD rips (redblueyellow / MufasaKong / Mr. C):
labeled sections (Idle / Movement / Attack / Special Attack / Hurt / Asleep)
with 8 direction rows per section, on flat white or teal backgrounds.

Usage:
  .venv312\\Scripts\\python.exe tools\\prep_pokemon_world.py contacts
      -> labeled contact sheets in the scratch dir; LOOK at them, then fill PICKS
  .venv312\\Scripts\\python.exe tools\\prep_pokemon_world.py build
      -> processed sheets + manifests from the picks below

Island indices below were verified on the contact sheets generated at scale 2
(divide any coordinate read off them by 2 — see AGENT_GUIDE §4 scale trap).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import (
    chroma_key, clean_alpha, contact_sheet, compose_grid, find_islands,
    largest_component, load_rgba, resize_rgba,
)

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets/franchises/pokemon/raw"
PROCESSED = ROOT / "assets/franchises/pokemon/processed"
MANIFESTS = ROOT / "assets/franchises/pokemon/manifests"
SCRATCH = Path(os.environ.get("CLAUDE_JOB_DIR", str(ROOT / "tools"))) / "tmp" / "pkmn_contacts"

# The rips already carry alpha transparency (85%+ of each sheet's RGB reads
# as (0,0,0) only because transparent converts to black). NEVER key black or
# white globally: black is every sprite's outline, and Mewtwo's body IS
# (248,248,248). We key only explicit opaque background colors (teal page bg,
# magnemite's green page + cell fills) and strip the long straight opaque-black
# section frames / divider bands geometrically.
TEAL = (0, 128, 128)
SOURCES: dict[str, dict] = {
    "pikachu": {"path": RAW / "heroes/pikachu.png", "keys": [TEAL], "gap": 0},
    "charmander": {"path": RAW / "heroes/charmander.png", "keys": [TEAL], "gap": 0},
    "mewtwo": {"path": RAW / "customers_enemies_bosses/sprite_mewtwo_boss.png", "keys": [TEAL], "gap": 0},
    "ho_oh": {"path": RAW / "customers_enemies_bosses/sprite_ho_oh_boss.png", "keys": [TEAL], "gap": 0},
    "latios": {"path": RAW / "sprite_latios_boss.png", "keys": [TEAL], "gap": 0},
    "corrupt_rattata": {"path": RAW / "customers_enemies_bosses/sprite_rattata_raticate.png", "keys": [TEAL], "gap": 0},
    "corrupt_zubat": {"path": RAW / "customers_enemies_bosses/sprite_zubat_golbat_crobat.png", "keys": [TEAL], "gap": 0},
    "corrupt_gastly": {"path": RAW / "customers_enemies_bosses/sprite_gastly_haunter_gengar.png", "keys": [TEAL], "gap": 0},
    "corrupt_magnemite": {
        "path": RAW / "customers_enemies_bosses/sprite_magnemite_magneton_magnezone.png",
        "keys": [(0, 255, 0), (0, 127, 151), (135, 119, 87)], "gap": 0,
    },
    "corrupt_beedrill": {"path": RAW / "customers_enemies_bosses/sprite_weedle_kakuna_beedrill.png", "keys": [TEAL], "gap": 0},
}


def strip_straight_black_lines(img: Image.Image, min_run: int = 60) -> Image.Image:
    """Clear horizontal/vertical runs of opaque near-black >= min_run px:
    section frames, divider bands, the sheet border. Sprite outlines never
    run that straight (Gastly's black body maxes out around 40px)."""
    import numpy as np
    a = np.array(img)
    dark = (a[..., :3].max(axis=2) < 64) & (a[..., 3] > 200)
    h, w = dark.shape
    kill = np.zeros_like(dark)
    for y in range(h):
        x = 0
        row = dark[y]
        while x < w:
            if row[x]:
                x2 = x
                while x2 < w and row[x2]:
                    x2 += 1
                if x2 - x >= min_run:
                    kill[y, x:x2] = True
                x = x2
            else:
                x += 1
    for x in range(w):
        y = 0
        col = dark[:, x]
        while y < h:
            if col[y]:
                y2 = y
                while y2 < h and col[y2]:
                    y2 += 1
                if y2 - y >= min_run:
                    kill[y:y2, x] = True
                y = y2
            else:
                y += 1
    a[kill] = 0
    return Image.fromarray(a)


def keyed(name: str) -> Image.Image:
    cfg = SOURCES[name]
    img = load_rgba(cfg["path"])
    for c in cfg["keys"]:
        img = chroma_key(img, c, tol=14)
    return strip_straight_black_lines(img)


def stage_contacts() -> None:
    SCRATCH.mkdir(parents=True, exist_ok=True)
    for name in SOURCES:
        img = keyed(name)
        boxes = find_islands(img, min_area=30, merge_gap=SOURCES[name]["gap"])
        out = SCRATCH / f"contact_{name}.png"
        contact_sheet(img, boxes, out, scale=2)
        print(f"{name}: {len(boxes)} islands -> {out}")


# ---------------------------------------------------------------------------
# GRIDS: per source, crop region + section x-splits. The 'grid' stage clusters
# islands into (section, row, col) and renders a zoomed sheet labeled with
# canonical ids "s{section}r{row}c{col}" so facings can be read per row.
# region=(x0,y0,x1,y1) limits to one evolution band on family sheets.
# ---------------------------------------------------------------------------
GRIDS: dict[str, dict] = {
    # heroes (full sheet; sections: hurt | idle/attack | movement | special)
    "pikachu": {"region": None, "splits": [62, 132, 245]},
    "charmander": {"region": None, "splits": [50, 132, 240]},
    # bosses (full sheet)
    "mewtwo": {"region": None, "splits": [65, 140, 210]},
    "ho_oh": {"region": None, "splits": [160, 355]},
    "latios": {"region": None, "splits": [90, 200, 330]},
    # enemies: first-stage band only (family sheets stack evolutions)
    "corrupt_rattata": {"region": (0, 0, 438, 200), "splits": [62, 130, 240, 330]},
    "corrupt_zubat": {"region": (0, 0, 362, 200), "splits": [62, 148, 235]},
    "corrupt_gastly": {"region": (0, 0, 660, 255), "splits": [78, 185]},
    "corrupt_magnemite": {"region": (0, 0, 470, 295), "splits": [110, 210, 320, 395]},
    "corrupt_beedrill": {"region": (0, 400, 555, 616), "splits": [62, 145, 460]},
}


def _grid_boxes(name: str) -> tuple[Image.Image, dict[str, tuple[int, int, int, int]]]:
    """Key the sheet, find islands inside the configured region, and assign
    canonical ids s{section}r{row}c{col} (sections by x-splits, rows by
    y-band clustering inside each section, cols by x order inside a row)."""
    img = keyed(name)
    cfg = GRIDS[name]
    region = cfg.get("region")
    boxes = find_islands(img, min_area=30, merge_gap=SOURCES[name]["gap"])
    if region:
        x0, y0, x1, y1 = region
        boxes = [b for b in boxes if b[0] >= x0 and b[1] >= y0 and b[2] <= x1 and b[3] <= y1]
    # drop label-text remnants so they can't pollute the direction-row
    # clustering: short islands that are also achromatic (title letters have
    # mean chroma ~0; even gray sprites like magnemite carry red/blue accents)
    import numpy as np
    arr = np.array(img)

    def _is_text(b) -> bool:
        if b[3] - b[1] >= 14:
            return False
        px = arr[b[1]:b[3], b[0]:b[2]]
        vis = px[px[..., 3] > 10]
        if len(vis) == 0:
            return True
        chroma = (vis[..., :3].max(axis=1).astype(int) - vis[..., :3].min(axis=1).astype(int)).mean()
        return chroma < 12

    boxes = [b for b in boxes if not _is_text(b)]
    splits: list[int] = cfg["splits"]
    sections: dict[int, list] = {}
    for b in boxes:
        s = sum(1 for sx in splits if b[0] >= sx)
        sections.setdefault(s, []).append(b)
    named: dict[str, tuple[int, int, int, int]] = {}
    for s, bs in sections.items():
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
                named[f"s{s}r{r}c{c}"] = tuple(b)
    return img, named


def stage_grid() -> None:
    from PIL import ImageDraw
    SCRATCH.mkdir(parents=True, exist_ok=True)
    scale = 2
    for name in GRIDS:
        img, named = _grid_boxes(name)
        base = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        bg = Image.new("RGBA", base.size, (40, 40, 60, 255))
        bg.alpha_composite(base)
        draw = ImageDraw.Draw(bg)
        for nid, (x0, y0, x1, y1) in named.items():
            draw.rectangle([x0 * scale, y0 * scale, x1 * scale - 1, y1 * scale - 1], outline=(255, 0, 0, 255))
            draw.text((x0 * scale + 1, y0 * scale + 1), nid, fill=(255, 255, 0, 255))
        out = SCRATCH / f"grid_{name}.png"
        bg.convert("RGB").save(out)
        print(f"{name}: {len(named)} cells -> {out}")


# ---------------------------------------------------------------------------
# PICKS: anim -> canonical cell ids; prefix "~" = flip horizontally (side
# frames must face RIGHT; PMD rips face left in their W rows, so W picks are
# flipped; pikachu/magnemite have native E rows).
# Direction row conventions verified on the grid_/zoom_ sheets:
#   8-row sheets (pikachu, magnemite): S, SW, W, NW, N, NE, E, SE
#   5-row sheets (charmander, mewtwo, rattata, zubat, gastly, beedrill):
#       S, SW, W, NW, N
#   ho_oh (8 rows): S, N, W, E, then diagonals
#   latios (5 rows): S, N, W, then diagonals
# cell=None -> tight auto cell from the picked islands (enemies measure their
# art for hurtboxes; only heroes get padded fixed cells).
# ---------------------------------------------------------------------------
PICKS: dict[str, dict] = {
    # pikachu rows (mirror-verified): S, N, W, E, SW, SE, NW, NE — native E row
    "pikachu": {
        "cell": (48, 48),
        "anims": {
            "idle_down": ["s1r0c0"], "idle_up": ["s1r1c0"], "idle_side": ["s1r3c0"],
            "walk_down": ["s2r0c0", "s2r0c1", "s2r0c2", "s2r0c1"],
            "walk_up": ["s2r1c0", "s2r1c1", "s2r1c2", "s2r1c1"],
            "walk_side": ["s2r3c0", "s2r3c1", "s2r3c2", "s2r3c1"],
            "attack_1_down": ["s1r0c1", "s1r0c1", "s1r0c0"],
            "attack_1_up": ["s1r1c1", "s1r1c1", "s1r1c0"],
            "attack_1_side": ["s1r3c1", "s1r3c1", "s1r3c0"],
            "special_down": ["s3r0c0", "s3r0c1", "s3r0c0", "s3r0c1"],
            "special_up": ["s3r1c0", "s3r1c1", "s3r1c0", "s3r1c1"],
            "special_side": ["s3r3c0", "s3r3c1", "s3r3c0", "s3r3c1"],
        },
        "fps": {"attack_1_down": 12, "attack_1_up": 12, "attack_1_side": 12,
                "special_down": 10, "special_up": 10, "special_side": 10},
        "loops": {"attack_1_down": False, "attack_1_up": False, "attack_1_side": False,
                  "special_down": False, "special_up": False, "special_side": False},
    },
    # charmander idle/move rows: S, N, W, SW, E (native E at r4);
    # its ATTACK section rows differ: S, SW, W, NW, N; special: S, SW, W, NW
    "charmander": {
        "cell": (48, 48),
        "anims": {
            "idle_down": ["s1r0c1"], "idle_up": ["s1r1c1"], "idle_side": ["s1r4c1"],
            "walk_down": ["s1r0c0", "s1r0c1", "s1r0c2", "s1r0c1"],
            "walk_up": ["s1r1c0", "s1r1c1", "s1r1c2", "s1r1c1"],
            "walk_side": ["s1r4c0", "s1r4c1", "s1r4c2", "s1r4c1"],
            "attack_1_down": ["s2r0c0", "s2r0c1", "s2r0c2", "s2r0c3"],
            "attack_1_up": ["s2r4c0", "s2r4c1", "s2r4c2", "s2r4c3"],
            "attack_1_side": ["~s2r2c0", "~s2r2c1", "~s2r2c2", "~s2r2c3"],
            "special_down": ["s3r0c0", "s3r0c1", "s3r0c0"],
            "special_up": ["s3r3c0", "s3r3c0"],
            "special_side": ["~s3r2c0", "~s3r2c0"],
        },
        "fps": {"attack_1_down": 14, "attack_1_up": 14, "attack_1_side": 14,
                "special_down": 10, "special_up": 10, "special_side": 10},
        "loops": {"attack_1_down": False, "attack_1_up": False, "attack_1_side": False,
                  "special_down": False, "special_up": False, "special_side": False},
    },
    # mewtwo rows: S, N, W, SW, NW — side is flipped W
    "mewtwo": {
        "cell": None, "upscale": 2,
        "anims": {
            "idle_down": ["s1r0c0", "s1r0c1"], "idle_up": ["s1r1c0", "s1r1c1"],
            "idle_side": ["~s1r2c0", "~s1r2c1"],
            "walk_down": ["s2r0c0", "s2r0c1"], "walk_up": ["s2r1c0", "s2r1c1"],
            "walk_side": ["~s2r2c0", "~s2r2c1"],
        },
        "fps": {"idle_down": 2, "idle_up": 2, "idle_side": 2},
    },
    # ho_oh rows: S, N, W, E — native E at r3
    "ho_oh": {
        "cell": None, "upscale": 2,
        "anims": {
            "idle_down": ["s1r0c0", "s1r0c1", "s1r0c2", "s1r0c1"],
            "idle_up": ["s1r1c0", "s1r1c1", "s1r1c2", "s1r1c1"],
            "idle_side": ["s1r3c0", "s1r3c1", "s1r3c2", "s1r3c1"],
            "walk_down": ["s1r0c0", "s1r0c1", "s1r0c2", "s1r0c1"],
            "walk_up": ["s1r1c0", "s1r1c1", "s1r1c2", "s1r1c1"],
            "walk_side": ["s1r3c0", "s1r3c1", "s1r3c2", "s1r3c1"],
        },
        "fps": {"idle_down": 4, "idle_up": 4, "idle_side": 4},
    },
    # latios rows: S, N, W, SW, E-ish — side from flipped W (r2)
    "latios": {
        "cell": None, "upscale": 2,
        "anims": {
            "idle_down": ["s2r0c0", "s2r0c1"], "idle_up": ["s2r1c0", "s2r1c1"],
            "idle_side": ["~s2r2c0", "~s2r2c1"],
            "walk_down": ["s2r0c0", "s2r0c1"], "walk_up": ["s2r1c0", "s2r1c1"],
            "walk_side": ["~s2r2c0", "~s2r2c1"],
        },
        "fps": {"idle_down": 4, "idle_up": 4, "idle_side": 4},
    },
    # rattata rows: S, N, W, SW, NW
    "corrupt_rattata": {
        "cell": None,
        "anims": {
            "idle_down": ["s1r0c0", "s1r0c1"], "idle_up": ["s1r1c0", "s1r1c1"],
            "idle_side": ["~s1r2c0", "~s1r2c1"],
            "walk_down": ["s2r0c0", "s2r0c1", "s2r0c2", "s2r0c1"],
            "walk_up": ["s2r1c0", "s2r1c1", "s2r1c2", "s2r1c1"],
            "walk_side": ["~s2r2c0", "~s2r2c1", "~s2r2c2", "~s2r2c1"],
        },
    },
    # zubat movement rows: S, N, SW, W, NW — W is r3
    "corrupt_zubat": {
        "cell": None,
        "anims": {
            "idle_down": ["s2r0c0", "s2r0c1", "s2r0c2", "s2r0c1"],
            "idle_up": ["s2r1c0", "s2r1c1", "s2r1c2", "s2r1c1"],
            "idle_side": ["~s2r3c0", "~s2r3c1", "~s2r3c2", "~s2r3c1"],
            "walk_down": ["s2r0c0", "s2r0c1", "s2r0c2", "s2r0c1"],
            "walk_up": ["s2r1c0", "s2r1c1", "s2r1c2", "s2r1c1"],
            "walk_side": ["~s2r3c0", "~s2r3c1", "~s2r3c2", "~s2r3c1"],
        },
        "fps": {"idle_down": 5, "idle_up": 5, "idle_side": 5},
    },
    # gastly rows: S, N, W, SW, NW
    "corrupt_gastly": {
        "cell": None,
        "anims": {
            "idle_down": ["s1r0c0", "s1r0c1", "s1r0c2", "s1r0c1"],
            "idle_up": ["s1r1c0", "s1r1c1", "s1r1c2", "s1r1c1"],
            "idle_side": ["~s1r2c0", "~s1r2c1", "~s1r2c2", "~s1r2c1"],
            "walk_down": ["s1r0c0", "s1r0c1", "s1r0c2", "s1r0c1"],
            "walk_up": ["s1r1c0", "s1r1c1", "s1r1c2", "s1r1c1"],
            "walk_side": ["~s1r2c0", "~s1r2c1", "~s1r2c2", "~s1r2c1"],
        },
        "fps": {"idle_down": 4, "idle_up": 4, "idle_side": 4},
    },
    # magnemite rows r1..r8 clockwise: S, SE, E, NE, N, NW, W, SW — native E at r3
    "corrupt_magnemite": {
        "cell": None,
        "anims": {
            "idle_down": ["s0r1c0", "s0r1c1", "s0r1c2", "s0r1c1"],
            "idle_up": ["s0r5c0", "s0r5c1", "s0r5c2", "s0r5c1"],
            "idle_side": ["s0r3c0", "s0r3c1", "s0r3c2", "s0r3c1"],
            "walk_down": ["s0r1c0", "s0r1c1", "s0r1c2", "s0r1c1"],
            "walk_up": ["s0r5c0", "s0r5c1", "s0r5c2", "s0r5c1"],
            "walk_side": ["s0r3c0", "s0r3c1", "s0r3c2", "s0r3c1"],
        },
        "fps": {"idle_down": 4, "idle_up": 4, "idle_side": 4},
    },
    # beedrill rows: S, N, W, SW, NW — side is flipped W (r4 faces left too,
    # verified at 6x on zoom_beedrill_side.png)
    "corrupt_beedrill": {
        "cell": None,
        "anims": {
            "idle_down": ["s1r0c0", "s1r0c1", "s1r0c2", "s1r0c1"],
            "idle_up": ["s1r1c0", "s1r1c1", "s1r1c2", "s1r1c1"],
            "idle_side": ["~s1r2c0", "~s1r2c1", "~s1r2c2", "~s1r2c1"],
            "walk_down": ["s1r0c0", "s1r0c1", "s1r0c2", "s1r0c1"],
            "walk_up": ["s1r1c0", "s1r1c1", "s1r1c2", "s1r1c1"],
            "walk_side": ["~s1r2c0", "~s1r2c1", "~s1r2c2", "~s1r2c1"],
        },
        "fps": {"idle_down": 6, "idle_up": 6, "idle_side": 6},
    },
}


def stage_build() -> None:
    if not PICKS:
        print("PICKS is empty — run 'grid', view the sheets, fill PICKS.")
        return
    for name, spec in PICKS.items():
        img, named = _grid_boxes(name)
        # translate canonical ids to indices for compose_grid
        ids = list(named.keys())
        boxes = [named[i] for i in ids]
        idx = {cid: n for n, cid in enumerate(ids)}
        anims: dict[str, list[int]] = {}
        for anim, cells in spec["anims"].items():
            out: list[int] = []
            for cid in cells:
                flip = cid.startswith("~")
                real = cid[1:] if flip else cid
                n = idx[real]
                out.append(-n - 1 if flip else n)
            anims[anim] = out
        scale = spec.get("upscale", 1)
        if scale != 1:
            img2 = resize_rgba(img, (img.width * scale, img.height * scale))
            boxes = [(x0 * scale, y0 * scale, x1 * scale, y1 * scale) for x0, y0, x1, y1 in boxes]
            img = img2
        cell = spec["cell"]
        if cell is None:
            used = {(-f - 1 if f < 0 else f) for fr in anims.values() for f in fr}
            cw = max(boxes[i][2] - boxes[i][0] for i in used) + 2
            ch = max(boxes[i][3] - boxes[i][1] for i in used) + 2
            cell = (cw, ch)
        compose_grid(
            img, boxes, anims, cell,
            PROCESSED / "sheets" / f"{name}.png",
            MANIFESTS / f"{name}.json",
            f"res://assets/franchises/pokemon/processed/sheets/{name}.png",
            fps=spec.get("fps"), loops=spec.get("loops"),
            anchor=spec.get("anchor", "bottom"),
        )


def stage_specials() -> None:
    """Hero special-attack effect rings: frame folders -> horizontal strips."""
    for who, frames_dir, out_name in (
        ("pikachu", RAW / "heroes/pikachu_special", "pikachu_discharge"),
        ("charmander", RAW / "heroes/charmander_special", "charmander_firespin"),
    ):
        files = sorted(frames_dir.glob("*.png"))
        imgs = [load_rgba(f) for f in files]
        w = max(i.width for i in imgs)
        h = max(i.height for i in imgs)
        strip = Image.new("RGBA", (w * len(imgs), h), (0, 0, 0, 0))
        for n, i in enumerate(imgs):
            strip.alpha_composite(i, (n * w + (w - i.width) // 2, (h - i.height) // 2))
        out = PROCESSED / f"{out_name}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        strip.save(out)
        print(f"{who}: {len(imgs)} frames of {w}x{h} -> {out}")


if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else "contacts"
    {"contacts": stage_contacts, "grid": stage_grid, "build": stage_build,
     "specials": stage_specials}[stage]()
