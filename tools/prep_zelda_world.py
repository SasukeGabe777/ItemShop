"""Zelda (Minish Cap) world content prep: Link's animated hero sheet with
baked-sword thrust/lunge attacks, the MC enemy roster + the three supplied
bosses (Big Green ChuChu / Big Blue ChuChu / Vaati), Hyrule room backgrounds
cropped from the Lon Lon Ranch + Castle Garden maps (with the ranch boulders
as the wall blocker), menu-sheet item icons, the bomb + explosion sprites for
Link's special, and customer pool statics.

The MC rips come in several background styles: plain navy (corner key), teal
frame-cells (key corner + the cell color), and white-backed sheets — each
recipe below says which. Frame indices were verified on tools/out/z_*_cs.png
contact sheets.

Run: .venv312/Scripts/python tools/prep_zelda_world.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import (chroma_key, clean_alpha, find_islands, largest_component,
                       load_rgba, resize_rgba)

ROOT = Path(__file__).resolve().parent.parent
Z = ROOT / "assets/franchises/zelda"
RES = "res://assets/franchises/zelda"


def key_colors(img: Image.Image, colors: list[tuple[int, int, int]], tol: int = 12) -> Image.Image:
    for c in colors:
        img = chroma_key(img, c, tol=tol)
    return chroma_key(img, (255, 0, 255), tol=40)


def key_corner(img: Image.Image, tol: int = 10) -> Image.Image:
    c = img.getpixel((0, 0))
    if len(c) == 4 and c[3] == 0:
        return img
    return key_colors(img, [(c[0], c[1], c[2])], tol=tol)


def sample(img: Image.Image, xy: tuple[int, int]) -> tuple[int, int, int]:
    c = img.getpixel(xy)
    return (c[0], c[1], c[2])


# --------------------------------------------------------------------------
# Link: bands of the zelda_hero.png sheet, islands per band, picks by
# (band, index[, flip]). Negative index = horizontally flipped, like
# compose_grid, but resolved here because picks span several bands.
LINK_SHEET = "raw/heroes/zelda_hero.png"
LINK_BANDS = {
    "stand": ((0, 0, 260, 70), 30, 2),
    "walk": ((0, 60, 1208, 145), 30, 2),
    "thrust": ((0, 595, 620, 705), 30, 2),
}
## side rows face LEFT on the sheet; store right-facing (CharacterVisual
## flips for left), hence the flips on every _side pick.
LINK_PICKS = {
    "idle_down": [("stand", 0, False)],
    "walk_down": [("walk", 6, False), ("walk", 7, False), ("walk", 8, False), ("walk", 9, False)],
    "idle_up": [("stand", 4, False)],
    "walk_up": [("walk", 27, False), ("walk", 28, False), ("walk", 29, False), ("walk", 30, False)],
    "idle_side": [("stand", 3, True)],
    "walk_side": [("walk", 17, True), ("walk", 18, True), ("walk", 19, True), ("walk", 20, True)],
    # sword thrust (blade baked into the frames)
    "attack_1_down": [("thrust", 29, False), ("thrust", 30, False), ("thrust", 31, False)],
    "attack_1_side": [("thrust", 15, True), ("thrust", 16, True), ("thrust", 17, True)],
    "attack_1_up": [("thrust", 21, False), ("thrust", 22, False), ("thrust", 23, False)],
    # low lunge slide
    "attack_2_down": [("thrust", 45, False), ("thrust", 46, False), ("thrust", 47, False)],
    "attack_2_side": [("thrust", 50, True), ("thrust", 51, True), ("thrust", 52, True)],
    "attack_2_up": [("thrust", 55, False), ("thrust", 56, False), ("thrust", 57, False)],
}


def prep_link() -> None:
    img = key_corner(load_rgba(Z / LINK_SHEET))
    bands: dict[str, list[tuple[int, int, int, int]]] = {}
    for name, (box, min_area, gap) in LINK_BANDS.items():
        crop = img.crop(box)
        boxes = find_islands(crop, min_area=min_area, merge_gap=gap)
        bands[name] = [(b[0] + box[0], b[1] + box[1], b[2] + box[0], b[3] + box[1]) for b in boxes]
        print(f"  link band {name}: {len(boxes)} islands")
    cw, ch = 26, 28
    total = sum(len(v) for v in LINK_PICKS.values())
    cols = 8
    rows = (total + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    anims: dict[str, dict] = {}
    idx = 0
    for anim, picks in LINK_PICKS.items():
        frames: list[int] = []
        for band, i, flip in picks:
            crop = img.crop(bands[band][i])
            if flip:
                crop = crop.transpose(Image.FLIP_LEFT_RIGHT)
            if crop.width > cw or crop.height > ch:
                r = min(cw / crop.width, ch / crop.height)
                crop = crop.resize((max(1, int(crop.width * r)), max(1, int(crop.height * r))), Image.NEAREST)
            cx = (idx % cols) * cw + (cw - crop.width) // 2
            cy = (idx // cols) * ch + (ch - crop.height) - 2
            sheet.alpha_composite(crop, (cx, cy))
            frames.append(idx)
            idx += 1
        fps = 9 if anim.startswith("walk") else (12 if anim.startswith("attack") else 3)
        anims[anim] = {"frames": frames, "fps": fps, "loop": not anim.startswith("attack")}
    (Z / "processed/sheets").mkdir(parents=True, exist_ok=True)
    sheet.save(Z / "processed/sheets/link.png")
    manifest = {
        "asset_id": "link", "sheet": f"{RES}/processed/sheets/link.png",
        "native_scale": 1, "display_scale": 1, "pivot": [cw // 2, ch - 4],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": cols, "rows": rows},
        "animations": anims,
    }
    (Z / "manifests").mkdir(parents=True, exist_ok=True)
    (Z / "manifests/link.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    # portrait: idle_down at 4x
    crop = clean_alpha(img.crop(bands["stand"][0]), lo=1, hi=255)
    crop.resize((crop.width * 4, crop.height * 4), Image.NEAREST).save(Z / "processed/link.png")
    print(f"  link sheet {cols}x{rows} + manifest + portrait")


# --------------------------------------------------------------------------
# Bomb special: placed bomb sprite + the Minish Cap explosion animation.
EXPL_SHEET = "raw/heroes/link_bomb_Explosion.png"
## island indices on z_expl_cs.png (min_area=30, merge_gap=2); the skipped
## numbers are the ripper-credit text islands.
EXPL_FRAMES = [1, 0, 4, 5, 7, 9, 10, 12, 14, 16, 18]


def prep_bomb() -> None:
    img = key_corner(load_rgba(Z / EXPL_SHEET))
    boxes = find_islands(img, min_area=30, merge_gap=2)
    cw, ch = 48, 44
    sheet = Image.new("RGBA", (cw * len(EXPL_FRAMES), ch), (0, 0, 0, 0))
    for n, i in enumerate(EXPL_FRAMES):
        # bbox crops can overlap the ripper-credit text — keep the frame only
        crop = clean_alpha(largest_component(img.crop(boxes[i])), lo=1, hi=255)
        if crop.width > cw or crop.height > ch:
            r = min(cw / crop.width, ch / crop.height)
            crop = crop.resize((max(1, int(crop.width * r)), max(1, int(crop.height * r))), Image.NEAREST)
        sheet.alpha_composite(crop, ((n * cw) + (cw - crop.width) // 2, (ch - crop.height) // 2))
    sheet.save(Z / "processed/sheets/bomb_explosion.png")
    manifest = {
        "asset_id": "bomb_explosion", "sheet": f"{RES}/processed/sheets/bomb_explosion.png",
        "native_scale": 1, "display_scale": 1, "pivot": [cw // 2, ch // 2],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": len(EXPL_FRAMES), "rows": 1},
        "animations": {"explode": {"frames": list(range(len(EXPL_FRAMES))), "fps": 14, "loop": False}},
    }
    (Z / "manifests/bomb_explosion.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    # the placed-bomb world sprite: the gray menu bomb at native size
    items = load_rgba(Z / "raw/items/items.png")
    bomb = clean_alpha(key_corner(items.crop((90, 210, 112, 236))), lo=1, hi=255)
    bomb.save(Z / "processed/bomb.png")
    print(f"  bomb explosion: {len(EXPL_FRAMES)} frames; bomb sprite {bomb.size}")


# --------------------------------------------------------------------------
# Enemies: (sheet, crop or None, key mode, islands params, picks, height cap)
# key modes: "corner" | ("cell", (x, y)) -> corner + sampled cell color +
# white, for the framed-cell rips.
ZE = {
    "keese": ("sprite_keese.png", (0, 0, 170, 45), ("cell", (20, 20)), (20, 0), [2, 3], 24),
    "octorok": ("sprite_octorok.gif", None, "corner", (30, 2), [5, 9], 30),
    "chuchu_green": ("sprite_chuchu.png", None, "corner", (30, 2), [8], 26),
    "chuchu_blue": ("sprite_chuchu.png", None, "corner", (30, 2), [76], 26),
    "rope": ("sprite_rope.gif", (52, 4, 205, 45), "corner", (25, 0), [0, 1], 20),
    "leever": ("sprite_leever.png", (145, 0, 312, 112), ("cell", (150, 5)), (30, 2), [0], 28),
    "ghini": ("sprite_ghini.png", (70, 0, 104, 25), ("colors", [(56, 64, 160), (0, 128, 0)]), (60, 1), [0], 30),
    "keaton": ("sprite_keaton.png", (0, 185, 576, 290), "corner", (40, 1), [0, 1], 34),
    "spiked_beetle": ("sprite_spiked_beetle.png", (0, 0, 101, 120), ("cell", (0, 0)), (30, 1), [0, 1], 26),
    "moblin": ("sprite_spear_moblin.png", None, "corner", (30, 2), [4, 10], 40),
    "stalfos": ("sprite_stalfos.png", (0, 0, 110, 45), ("cell", (5, 5)), (30, 2), [0, 1], 34),
    "darknut": ("sprite_darknut.png", (0, 0, 130, 55), ("colors", [(184, 184, 216), (64, 176, 136)]), (60, 0), [0, 1], 44),
    "vaati": ("boss_3.png", None, "corner", (30, 2), [31], 120),
}


def _key_for(img: Image.Image, mode) -> Image.Image:
    if mode == "corner":
        return key_corner(img)
    kind, arg = mode
    if kind == "colors":
        # explicit color list — the recipe for white-bodied sprites (ghini,
        # darknut) whose bodies a blanket white key would eat
        return key_colors(img, arg)
    return key_colors(img, [sample(img, (0, 0)), sample(img, arg), (255, 255, 255)])


def frames_sheet(uid: str, crops: list[Image.Image], cap: int) -> None:
    """1-2 frame enemy/boss sheet: every direction anim plays the same frames
    (idle single, walk the pair when present)."""
    fixed: list[Image.Image] = []
    for c in crops:
        c = clean_alpha(largest_component(c), lo=1, hi=255)
        if c.height > cap:
            k = cap / c.height
            c = resize_rgba(c, (max(1, round(c.width * k)), cap))
            c = clean_alpha(c, lo=96, hi=160)
        fixed.append(c)
    cw = max(c.width for c in fixed)
    ch = max(c.height for c in fixed)
    sheet = Image.new("RGBA", (cw * len(fixed), ch), (0, 0, 0, 0))
    for n, c in enumerate(fixed):
        sheet.alpha_composite(c, (n * cw + (cw - c.width) // 2, ch - c.height))
    out = Z / f"processed/sheets/{uid}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    walk = list(range(len(fixed)))
    anims = {}
    for name in ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side"]:
        anims[name] = {"frames": walk if name.startswith("walk") else [0],
                       "fps": 4 if name.startswith("walk") else 3, "loop": True}
    manifest = {
        "asset_id": uid, "sheet": f"{RES}/processed/sheets/{uid}.png",
        "native_scale": 1, "display_scale": 1, "pivot": [cw // 2, ch - 2],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": len(fixed), "rows": 1},
        "animations": anims,
    }
    (Z / f"manifests/{uid}.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  {uid}: {len(fixed)} frame(s) {cw}x{ch}")


def prep_enemies() -> None:
    for uid, (fname, cbox, mode, (min_area, gap), picks, cap) in ZE.items():
        img = load_rgba(Z / f"raw/enemies/{fname}")
        if cbox:
            img = img.crop(cbox)
        img = _key_for(img, mode)
        boxes = find_islands(img, min_area=min_area, merge_gap=gap)
        if max(picks) >= len(boxes):
            print(f"  {uid}: ONLY {len(boxes)} islands, picks {picks} out of range")
            continue
        crops = [img.crop(boxes[i]) for i in picks]
        if uid == "vaati":
            # the transfigured form is a 58px frame; 2x it to boss presence
            crops = [c.resize((c.width * 2, c.height * 2), Image.NEAREST) for c in crops]
        frames_sheet(uid, crops, cap)


def prep_bosses() -> None:
    # boss_1/boss_2: the labeled Idle cell, keyed on the cell's own bg color,
    # then 2x'd to boss presence (the rips are ~48px)
    for uid, fname, cell in [
        ("big_green_chuchu", "boss_1.png", (196, 6, 240, 55)),
        ("big_blue_chuchu", "boss_2.png", (196, 6, 243, 60)),
    ]:
        img = load_rgba(Z / f"raw/enemies/{fname}").crop(cell)
        img = key_colors(img, [sample(img, (2, 2)), sample(img, (2, img.height - 3))])
        img = clean_alpha(largest_component(img), lo=1, hi=255)
        img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        frames_sheet(uid, [img], 110)


# --------------------------------------------------------------------------
# Hyrule rooms: 640x384 crops. Lon Lon Ranch carries the start + combat
# rooms and the boulder walls; Castle Garden the treasure + boss rooms.
LONLON = "raw/locations/Game Boy Advance - The Legend of Zelda_ The Minish Cap - Maps - Lon Lon Ranch (1).png"
GARDEN = "raw/locations/Game Boy Advance - The Legend of Zelda_ The Minish Cap - Maps - Hyrule Castle Garden (1).png"
Z_ROOMS = {
    "start_ranch": (LONLON, (80, 470, 720, 854)),
    "combat_orchard": (LONLON, (64, 50, 704, 434)),
    "combat_pens": (LONLON, (64, 180, 704, 564)),
    "combat_fields": (LONLON, (16, 556, 656, 940)),
    "treasure_garden": (GARDEN, (304, 28, 944, 412)),
    "boss_courtyard": (GARDEN, (176, 62, 816, 446)),
}


def prep_rooms() -> None:
    out = ROOT / "assets/locations/zeldadungeon/processed"
    out.mkdir(parents=True, exist_ok=True)
    for rid, (mp, box) in Z_ROOMS.items():
        img = Image.open(Z / mp).convert("RGB")
        img.crop(box).save(out / f"{rid}.png")
        print(f"  room {rid}")
    # wall blocker: a Lon Lon boulder cluster, tiled per obstacle-grid cell
    img = Image.open(Z / LONLON).convert("RGB")
    img.crop((144, 222, 176, 254)).save(out / "rocks.png")
    print("  rocks blocker written")


# --------------------------------------------------------------------------
# Item icons off the menu sheet (hand boxes on z_items*/z_bottles grids)
Z_ITEMS = {
    # existing catalog items
    "master_sword": (70, 190, 90, 210),
    "white_sword": (19, 190, 38, 210),
    "four_sword": (53, 190, 72, 210),
    "wooden_shield": (2, 212, 20, 233),
    "hylian_shield": (20, 212, 38, 234),
    "zelda_boomerang": (119, 188, 138, 211),
    "bomb_bag": (90, 210, 112, 236),
    "heart_container": (417, 199, 447, 227),
    "fairy_charm": (453, 234, 473, 251),
    # new Minish Cap catalog
    "gust_jar": (88, 188, 106, 210),
    "cane_of_pacci": (106, 190, 122, 210),
    "mole_mitts": (40, 212, 56, 234),
    "zelda_lantern": (56, 212, 74, 234),
    "remote_bomb": (74, 212, 92, 235),
    "pegasus_boots": (2, 237, 22, 258),
    "rocs_cape": (22, 237, 40, 258),
    "kinstone": (393, 229, 414, 251),
    "wake_up_mushroom": (372, 253, 393, 276),
    "big_key": (405, 252, 426, 276),
    "element_earth": (320, 232, 338, 251),
    "element_fire": (337, 232, 353, 251),
    "element_water": (354, 233, 373, 251),
    "element_wind": (373, 232, 391, 251),
}
## bottles row: islands left-to-right on the keyed (0,252,200,278) strip
Z_BOTTLE_PICKS = {"fairy_bottle": 1, "blue_potion": 6, "red_potion": 7, "green_potion": 9}
Z_ITEM_KEEP_ALL = {"heart_container", "bomb_bag", "zelda_boomerang"}


def prep_items() -> None:
    raw = load_rgba(Z / "raw/items/items.png")
    out = Z / "processed/items"
    out.mkdir(parents=True, exist_ok=True)

    def save_icon(iid: str, keyed: Image.Image) -> None:
        if iid not in Z_ITEM_KEEP_ALL:
            keyed = largest_component(keyed)
        crop = clean_alpha(keyed, lo=1, hi=255)
        if max(crop.size) > 22:
            k = 22 / max(crop.size)
            crop = resize_rgba(crop, (max(1, round(crop.width * k)), max(1, round(crop.height * k))))
            crop = clean_alpha(crop, lo=96, hi=160)
        crop.save(out / f"{iid}.png")
        print(f"  item {iid}: {crop.size}")

    for iid, box in Z_ITEMS.items():
        save_icon(iid, key_corner(raw.crop(box)))
    strip = key_corner(raw.crop((0, 252, 200, 274)))
    boxes = find_islands(strip, min_area=25, merge_gap=0)
    print(f"  bottles: {len(boxes)} islands")
    for iid, i in Z_BOTTLE_PICKS.items():
        save_icon(iid, strip.crop(boxes[i]))


# --------------------------------------------------------------------------
# Customer pool statics
def prep_customers() -> None:
    out = Z / "processed/customers"
    out.mkdir(parents=True, exist_ok=True)
    C = Z / "raw/customers"

    def save_static(slug: str, img: Image.Image, cap: int = 32) -> None:
        img = clean_alpha(largest_component(img), lo=1, hi=255)
        if img.height > cap:
            k = cap / img.height
            img = resize_rgba(img, (max(1, round(img.width * k)), cap))
            img = clean_alpha(img, lo=96, hi=160)
        img.save(out / f"{slug}.png")
        print(f"  customer {slug}: {img.size}")

    def islands(img: Image.Image, min_area=30, gap=2):
        return find_islands(img, min_area=min_area, merge_gap=gap)

    # Princess Zelda: her own animated rip ("both greens are transparency")
    pz = load_rgba(C / "sprite_princess_zelda.png")
    pz = key_colors(pz, [(7, 60, 41), (16, 128, 88)])
    crop = pz.crop((8, 38, 64, 100))
    save_static("princess_zelda", crop)
    # King Daltus row (corner-keyed islands)
    kd = key_corner(load_rgba(C / "sprite_king_daltus.gif"))
    kb = islands(kd)
    save_static("king_daltus", kd.crop(kb[3]))
    # Royal guards: castle blue + field gold
    rg = key_corner(load_rgba(C / "sprite_royal_guards.png"))
    rb = islands(rg)
    save_static("royal_guard", rg.crop(rb[1]))
    save_static("field_guard", rg.crop(rb[8]))
    # the Oracles (green + teal cell backgrounds; all three on the top row)
    oc = load_rgba(C / "sprite_din_nayru_farore_oracles.png")
    oc = key_colors(oc, [(0, 128, 0), (64, 176, 136)])
    ob = islands(oc, min_area=150)
    for slug, i in [("din", 0), ("nayru", 3), ("farore", 6)]:
        save_static(slug, oc.crop(ob[i]))
    # a Cucco
    cu = key_corner(load_rgba(C / "sprite_cuccos.png"))
    cb = islands(cu)
    save_static("cucco", cu.crop(cb[2]), cap=24)
    # Hyrule kids
    kids = key_corner(load_rgba(C / "sprite_hyrule_town_residents_3.png"))
    kbx = islands(kids)
    for slug, i in [("kid_boy_gold", 1), ("kid_boy_blue", 13), ("kid_girl_gold", 28), ("kid_girl_auburn", 32)]:
        save_static(slug, kids.crop(kbx[i]), cap=26)


def update_pool() -> None:
    path = ROOT / "data/customer_visuals.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    pool = [e for e in data["pool"] if e.get("world") != "zelda"]
    for slug, name in [
        ("princess_zelda", "Princess Zelda"), ("king_daltus", "King Daltus"),
        ("royal_guard", "Royal Guard"), ("field_guard", "Field Guard"),
        ("din", "Din"), ("nayru", "Nayru"), ("farore", "Farore"),
        ("cucco", "Cucco"), ("kid_boy_gold", "Tam"), ("kid_boy_blue", "Kip"),
        ("kid_girl_gold", "Romy"), ("kid_girl_auburn", "Ella"),
    ]:
        pool.append({"slug": slug, "name": name, "world": "zelda",
                     "static": f"{RES}/processed/customers/{slug}.png", "manifest": ""})
    data["pool"] = pool
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"  customer pool: {len(pool)} entries")


if __name__ == "__main__":
    print("link..."); prep_link()
    print("bomb..."); prep_bomb()
    print("enemies..."); prep_enemies()
    print("bosses..."); prep_bosses()
    print("rooms..."); prep_rooms()
    print("items..."); prep_items()
    print("customers..."); prep_customers(); update_pool()
    print("done")
