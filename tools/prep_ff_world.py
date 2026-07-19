"""Final Fantasy world content prep: Cloud's animated hero sheet, the FF6
monster roster + the three rotation bosses, painted room backgrounds cropped
from the supplied FF6 maps, and item icons from the weapons sheet.

The FF6 rips are parts+assembled sheets on a solid background: keying ONLY
the corner color (never the shared _key_sheet, whose >12% rule eats these
sprites' body colors) and taking the largest connected component yields the
assembled sprite on every sheet used here — verified via tools/out previews.

Run: .venv312/Scripts/python tools/prep_ff_world.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import chroma_key, clean_alpha, compose_grid, find_islands, largest_component, load_rgba, resize_rgba

ROOT = Path(__file__).resolve().parent.parent
FF = ROOT / "assets/franchises/final_fantasy"
RES = "res://assets/franchises/final_fantasy"


def key_corner(img: Image.Image, tol: int = 10) -> Image.Image:
    c = img.getpixel((0, 0))
    if len(c) == 4 and c[3] == 0:
        return img
    img = chroma_key(img, (c[0], c[1], c[2]), tol=tol)
    return chroma_key(img, (255, 0, 255), tol=40)


def prep_cloud() -> None:
    """FFRK Cloud compilation: island picks verified on tools/out/ff_cloud_zoom.png.
    The previous manifest's side frames pointed at a 10x12 speck (island 37 in
    the old numbering) — Cloud shrank to a dot when walking sideways."""
    img = load_rgba(FF / "raw/ff_cloud.png")
    boxes = find_islands(img, min_area=40, merge_gap=0)
    picks = {
        "idle_down": [0],
        "walk_down": [83, 84, 85, 86],
        "idle_up": [59],
        "walk_up": [36, 47],
        "idle_side": [-39],          # 38 faces left; store right-facing
        "walk_side": [-39, -43],     # 38, 42 flipped
        "attack_1": [-29, -15],      # crouch draw -> lunge (28, 14 flipped)
        "attack_2": [-15, -45],      # lunge -> leaping slash (14, 44 flipped)
    }
    compose_grid(img, boxes, picks, (20, 26),
                 FF / "processed/sheets/cloud.png", FF / "manifests/cloud.json",
                 f"{RES}/processed/sheets/cloud.png",
                 fps={"walk_down": 8, "walk_up": 7, "walk_side": 7,
                      "attack_1": 12, "attack_2": 12},
                 loops={"attack_1": False, "attack_2": False})
    crop = clean_alpha(img.crop(tuple(boxes[0])), lo=1, hi=255)
    crop = crop.resize((crop.width * 4, crop.height * 4), Image.NEAREST)
    crop.save(FF / "processed/cloud.png")
    print("  cloud portrait refreshed")


## enemy id -> (raw sheet, display height cap)
FF_ENEMIES = {
    "ghost": ("ff_ghost", 44),
    "giant_rat": ("ff_giant_rat", 36),
    "guard_hound": ("ff_guard_hound", 44),
    "magitek_armor": ("ff_magitek_armor", 64),
    "malboro": ("ff_malboro", 60),
    "ahriman": ("ff_ahriman_iii", 56),
    "imperial_shadow": ("ff_imperial_shadow", 52),
    "soldier_3rd": ("ff_soldier_3rd_class", 48),
    "tonberry": ("ff_master_tonberry", 40),
    "flan": ("ff_flan_master_black_flan_white_mousse", 40),
    "sand_worm": ("ff_sand_worm", 56),
    "behemoth": ("ff_behemoth", 72),
    # the three-run boss rotation (user-picked from the supplied rips)
    "red_dragon": ("ff_red_dragon_vi", 120),
    "kaiser_dragon": ("ff_kaiser_dragon", 130),
    "goddess": ("ff_goddess", 140),
}


def static_sheet(img: Image.Image, uid: str) -> None:
    """One assembled battle sprite reused for every direction (the FF6 rips
    are single-pose): guard_armor-style manifest."""
    w, h = img.size
    out_png = FF / f"processed/sheets/{uid}.png"
    out_png.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_png)
    anims = {}
    for name in ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side"]:
        anims[name] = {"frames": [0], "fps": 3, "loop": True}
    manifest = {
        "asset_id": uid, "sheet": f"{RES}/processed/sheets/{uid}.png",
        "native_scale": 1, "display_scale": 1, "pivot": [w // 2, h - 2],
        "grid": {"frame_width": w, "frame_height": h, "columns": 1, "rows": 1},
        "animations": anims,
    }
    (FF / f"manifests/{uid}.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def prep_enemies() -> None:
    for uid, (raw, cap) in FF_ENEMIES.items():
        p = FF / f"raw/{raw}.png"
        if not p.exists():
            print(f"  {uid}: MISSING {raw}")
            continue
        img = clean_alpha(largest_component(key_corner(load_rgba(p))), lo=1, hi=255)
        if img.height > cap:
            k = cap / img.height
            img = resize_rgba(img, (max(1, round(img.width * k)), cap))
            img = clean_alpha(img, lo=128, hi=128)
            img = clean_alpha(largest_component(img), lo=1, hi=255)
        static_sheet(img, uid)
        print(f"  {uid}: {img.size}")


## 640x384 painted room crops (the 20x12-cell room grid). Esperville carries
## a day town (top) and night town (bottom); Jidoor's street block is 512
## wide, upscaled 1.25x to fit the room.
FF_ROOM_CROPS = {
    "start_village": ("Esperville", (140, 380, 780, 764), 1.0),
    "combat_grove": ("Esperville", (200, 90, 840, 474), 1.0),
    "combat_glade": ("Esperville", (30, 540, 670, 924), 1.0),
    "combat_street": ("Jidoor", (0, 296, 512, 603), 1.25),
    "treasure_manor": ("Jidoor", (0, 0, 512, 307), 1.25),
    # boss arena: a distinct village quarter, dusk-darkened in post (the map's
    # real night layer is mostly void at room scale)
    "boss_night": ("Esperville", (260, 350, 900, 734), 1.0),
}


def prep_rooms() -> None:
    out = ROOT / "assets/locations/ffdungeon/processed"
    out.mkdir(parents=True, exist_ok=True)
    for rid, (map_name, box, scale) in FF_ROOM_CROPS.items():
        img = Image.open(FF / f"raw/locations/Game Boy Advance - Final Fantasy VI Advance - Maps - {map_name}.png").convert("RGB")
        crop = img.crop(box)
        if scale != 1.0:
            crop = crop.resize((640, 384), Image.NEAREST)
        if rid == "boss_night":
            crop = Image.eval(crop, lambda v: int(v * 0.45))
            # keep a cold blue cast so it reads as night, not mud
            r, g, b = crop.split()
            b = b.point(lambda v: min(255, int(v * 1.45)))
            crop = Image.merge("RGB", (r, g, b))
        crop.save(out / f"{rid}.png")
        print(f"  room {rid}: {crop.size}")
    # blocker: a tree clump from Esperville's border woods (nine-patched)
    img = Image.open(FF / "raw/locations/Game Boy Advance - Final Fantasy VI Advance - Maps - Esperville.png").convert("RGB")
    img.crop((378, 64, 442, 160)).save(out / "trees.png")
    print("  trees blocker written")


## item icons off the FF6 weapons sheet (hand boxes, verified via preview)
FF_ITEM_BOXES = {
    "mythril_sword": (64, 478, 89, 496),    # crossed-swords menu icon
    "genji_glove": (154, 456, 182, 496),    # the golden gauntlet
    "ff_ribbon": (100, 478, 126, 496),      # red cape (stands in for Ribbon)
}
## icons whose art is several disconnected components (crossed blades) —
## largest_component would keep one blade and drop the rest
FF_ITEM_KEEP_ALL = {"mythril_sword"}


def prep_items() -> None:
    raw = load_rgba(FF / "raw/items/Game Boy Advance - Final Fantasy VI Advance - Miscellaneous - Weapons (1).png")
    out = FF / "processed/items"
    out.mkdir(parents=True, exist_ok=True)
    for iid, box in FF_ITEM_BOXES.items():
        keyed = key_corner(raw.crop(box))
        if iid not in FF_ITEM_KEEP_ALL:
            keyed = largest_component(keyed)
        crop = clean_alpha(keyed, lo=1, hi=255)
        if max(crop.size) > 22:
            k = 22 / max(crop.size)
            crop = resize_rgba(crop, (max(1, round(crop.width * k)), max(1, round(crop.height * k))))
            crop = clean_alpha(crop, lo=96, hi=160)
        crop.save(out / f"{iid}.png")
        print(f"  item {iid}: {crop.size}")


if __name__ == "__main__":
    print("cloud..."); prep_cloud()
    print("enemies + bosses..."); prep_enemies()
    print("rooms..."); prep_rooms()
    print("items..."); prep_items()
    print("done")
