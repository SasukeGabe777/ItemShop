"""Zelda pass 2, from playtest feedback: visible sword swings (the sword-only
overlay frames from Link_sword_animation.png composited onto the thrust body
frames), whole bomb sprites (the old crops started mid-bomb), and animated
bosses — the ChuChus get their Idle + 4-frame Jumping hop from the rip's
labeled rows, Vaati gets his two winged flap frames.

Sword islands verified on tmp sword_islands.png (4x): 8 = blade RIGHT (green
Smith's-sword hilt on the left), 17 = blade DOWN (hilt top), 9 = blade UP
(hilt bottom). ChuChu rows verified on boss1_blobs/boss2_full: Idle is the
lone top cell, Jumping is the 4-cell row in y 118..180.

Run: .venv312/Scripts/python tools/fix_zelda_pass2.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import (chroma_key, clean_alpha, find_islands, largest_component,
                       load_rgba, resize_rgba)
from prep_zelda_world import (LINK_BANDS, LINK_PICKS, LINK_SHEET, key_colors,
                              key_corner, sample)

ROOT = Path(__file__).resolve().parent.parent
Z = ROOT / "assets/franchises/zelda"
RES = "res://assets/franchises/zelda"

SWORD_SHEET = "raw/heroes/Link_sword_animation.png"
SWORD_IDS = {"right": 8, "down": 17, "up": 9}

# cell grew 26x28 -> 48x48 so the blade can extend past the body
CW, CH = 48, 48
FEET_Y = 40  # body baseline inside the cell

## sword paste positions (top-left) per direction, on the extended frames.
## Link is left-handed in MC: down thrust sits right of center, up thrust left.
SWORD_POS = {
    "down": (29, 34),
    "right": (34, 26),
    "up": (16, 4),
}


def _swords() -> dict[str, Image.Image]:
    img = key_corner(load_rgba(Z / SWORD_SHEET).crop((0, 0, 228, 148)))
    boxes = find_islands(img, min_area=8, merge_gap=1)
    out: dict[str, Image.Image] = {}
    for name, i in SWORD_IDS.items():
        out[name] = clean_alpha(img.crop(boxes[i]), lo=1, hi=255)
        print(f"  sword {name}: {out[name].size}")
    return out


def fix_link() -> None:
    img = key_corner(load_rgba(Z / LINK_SHEET))
    bands: dict[str, list[tuple[int, int, int, int]]] = {}
    for name, (box, min_area, gap) in LINK_BANDS.items():
        crop = img.crop(box)
        boxes = find_islands(crop, min_area=min_area, merge_gap=gap)
        bands[name] = [(b[0] + box[0], b[1] + box[1], b[2] + box[0], b[3] + box[1]) for b in boxes]
    swords = _swords()
    total = sum(len(v) for v in LINK_PICKS.values())
    cols = 8
    rows = (total + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * CW, rows * CH), (0, 0, 0, 0))
    anims: dict[str, dict] = {}
    idx = 0
    for anim, picks in LINK_PICKS.items():
        frames: list[int] = []
        sword_dir = ""
        if anim.startswith("attack"):
            sword_dir = {"down": "down", "side": "right", "up": "up"}[anim.rsplit("_", 1)[1]]
        for n, (band, i, flip) in enumerate(picks):
            crop = img.crop(bands[band][i])
            if flip:
                crop = crop.transpose(Image.FLIP_LEFT_RIGHT)
            cx = (idx % cols) * CW + (CW - crop.width) // 2
            cy = (idx // cols) * CH + FEET_Y - crop.height
            sheet.alpha_composite(crop, (cx, cy))
            # blade on the extended frames: 1+ for the thrust, all for the lunge
            if sword_dir and (n >= 1 or anim.startswith("attack_2")):
                sx, sy = SWORD_POS[sword_dir]
                sheet.alpha_composite(swords[sword_dir],
                    ((idx % cols) * CW + sx, (idx // cols) * CH + sy))
            frames.append(idx)
            idx += 1
        fps = 9 if anim.startswith("walk") else (12 if anim.startswith("attack") else 3)
        anims[anim] = {"frames": frames, "fps": fps, "loop": not anim.startswith("attack")}
    sheet.save(Z / "processed/sheets/link.png")
    manifest = {
        "asset_id": "link", "sheet": f"{RES}/processed/sheets/link.png",
        "native_scale": 1, "display_scale": 1, "pivot": [CW // 2, FEET_Y - 2],
        "grid": {"frame_width": CW, "frame_height": CH, "columns": cols, "rows": rows},
        "animations": anims,
    }
    (Z / "manifests/link.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  link sheet rebuilt {cols}x{rows} @ {CW}x{CH}")


# --------------------------------------------------------------------------
# Bombs: the menu sheet has the whole pair side by side — blue regular bomb
# (Link's placed special + Bomb Bag icon) and the silver remote bomb with the
# red detonator cap. The old crops started mid-sprite.
BOMB_BLUE = (66, 212, 88, 235)
BOMB_GRAY = (85, 212, 106, 235)


def fix_bombs() -> None:
    raw = load_rgba(Z / "raw/items/items.png")
    out = Z / "processed/items"

    def cut(box) -> Image.Image:
        return clean_alpha(largest_component(key_corner(raw.crop(box))), lo=1, hi=255)

    def icon(iid: str, img: Image.Image) -> None:
        if max(img.size) > 22:
            k = 22 / max(img.size)
            img = resize_rgba(img, (max(1, round(img.width * k)), max(1, round(img.height * k))))
            img = clean_alpha(img, lo=96, hi=160)
        img.save(out / f"{iid}.png")
        print(f"  item {iid}: {img.size}")

    blue = cut(BOMB_BLUE)
    gray = cut(BOMB_GRAY)
    blue.save(Z / "processed/bomb.png")
    print(f"  placed bomb sprite: {blue.size}")
    icon("bomb_bag", blue)
    icon("remote_bomb", gray)


# --------------------------------------------------------------------------
# Bosses: Idle + the 4 Jumping hop frames, bottom-aligned, 2x upscale.
def _boss_frames(fname: str, cell_bg: tuple[int, int, int]) -> list[Image.Image]:
    img = load_rgba(Z / f"raw/enemies/{fname}")
    keyed = key_colors(img, [(255, 255, 255), cell_bg])
    boxes = [b for b in find_islands(keyed, min_area=250, merge_gap=1)
             if (b[2] - b[0]) >= 25 and (b[3] - b[1]) >= 25]
    idle = [b for b in boxes if b[1] < 65 and 40 <= (b[2] - b[0]) <= 60]
    jump = sorted([b for b in boxes if 118 <= b[1] <= 140], key=lambda b: b[0])
    assert len(idle) == 1 and len(jump) == 4, f"{fname}: idle {idle} jump {jump}"
    frames = []
    for b in [idle[0]] + jump:
        c = clean_alpha(largest_component(keyed.crop(b)), lo=1, hi=255)
        frames.append(c.resize((c.width * 2, c.height * 2), Image.NEAREST))
    return frames


def _multi_sheet(uid: str, frames: list[Image.Image], idle_frames: list[int],
        walk_frames: list[int], walk_fps: int) -> None:
    cw = max(c.width for c in frames)
    ch = max(c.height for c in frames)
    sheet = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for n, c in enumerate(frames):
        sheet.alpha_composite(c, (n * cw + (cw - c.width) // 2, ch - c.height))
    sheet.save(Z / f"processed/sheets/{uid}.png")
    anims = {}
    for name in ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side"]:
        walk = name.startswith("walk")
        anims[name] = {"frames": walk_frames if walk else idle_frames,
                       "fps": walk_fps if walk else 3, "loop": True}
    manifest = {
        "asset_id": uid, "sheet": f"{RES}/processed/sheets/{uid}.png",
        "native_scale": 1, "display_scale": 1, "pivot": [cw // 2, ch - 2],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": len(frames), "rows": 1},
        "animations": anims,
    }
    (Z / f"manifests/{uid}.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  {uid}: {len(frames)} frames {cw}x{ch}")


def fix_bosses() -> None:
    _multi_sheet("big_green_chuchu", _boss_frames("boss_1.png", (0, 172, 255)), [0], [1, 2, 3, 4], 6)
    _multi_sheet("big_blue_chuchu", _boss_frames("boss_2.png", (64, 176, 136)), [0], [1, 2, 3, 4], 6)
    # vaati: the two transfigured winged frames flap (islands 24 + 31 on the
    # corner-keyed sheet, both 62x57)
    img = load_rgba(Z / "raw/enemies/boss_3.png")
    keyed = key_corner(img)
    boxes = find_islands(keyed, min_area=30, merge_gap=2)
    frames = []
    for i in [24, 31]:
        c = clean_alpha(largest_component(keyed.crop(boxes[i])), lo=1, hi=255)
        frames.append(c.resize((c.width * 2, c.height * 2), Image.NEAREST))
    _multi_sheet("vaati", frames, [0, 1], [0, 1], 3)


if __name__ == "__main__":
    print("link + sword overlays:")
    fix_link()
    print("bombs:")
    fix_bombs()
    print("bosses:")
    fix_bosses()
    print("done")
