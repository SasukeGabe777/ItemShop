"""One-shot preprocessing of the supplied Spriters-Resource sheets into
game-ready processed sheets, manifests, portraits, props and item icons.

Island indices below were picked by visual inspection of annotated contact
sheets (see tools/slice_lib.py helpers). Re-running is deterministic as long
as the detection parameters stay identical.

Run: python tools/prep_supplied_assets.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import chroma_key, compose_grid, find_islands, load_rgba, resize_rgba, save_island

ROOT = Path(__file__).resolve().parent.parent
KH = ROOT / "assets/franchises/kingdom_hearts"
FF = ROOT / "assets/franchises/final_fantasy"
CROSS = ROOT / "assets/franchises/crossover"
MARIO = ROOT / "assets/franchises/mario"
LOC = ROOT / "assets/locations"
SHARED = ROOT / "assets/shared/placeholders"


def tint_purple(img: Image.Image) -> Image.Image:
    """Bridge-corruption tint for the Fat Bandit boss variant."""
    a = np.array(img).astype(np.float32)
    r, g, b = a[..., 0].copy(), a[..., 1].copy(), a[..., 2].copy()
    a[..., 0] = np.clip(r * 0.62 + 30, 0, 255)
    a[..., 1] = np.clip(g * 0.45 + 8, 0, 255)
    a[..., 2] = np.clip(b * 0.85 + 55, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def prep_sora() -> None:
    img = chroma_key(load_rgba(KH / "raw/sora.png"), (255, 255, 255), tol=4)
    boxes = find_islands(img, min_area=150, merge_gap=2)
    picks = {
        "idle_down": [149],
        "walk_down": [137, 149, 157, 149],
        "idle_up": [140],
        "walk_up": [141, 140, 142, 140],
        "idle_side": [-151],           # 150 faces left; store right-facing
        "walk_side": [-151, -157],     # 150, 156 flipped
    }
    compose_grid(img, boxes, picks, (34, 44),
                 KH / "processed/sheets/sora.png", KH / "manifests/sora.json",
                 "res://assets/franchises/kingdom_hearts/processed/sheets/sora.png",
                 fps={"walk_down": 6, "walk_up": 6, "walk_side": 6})
    save_island(img, boxes[162], KH / "processed/sora.png")  # dialogue portrait


def prep_shadow() -> None:
    img = chroma_key(load_rgba(KH / "raw/shadow_enemy.png"), (200, 191, 231), tol=12)
    boxes = find_islands(img, min_area=40, merge_gap=1)
    picks = {
        "idle_down": [0, 1, 2],
        "walk_down": [37, 38, 39, 40],
        "walk_up": [45, 46, 47, 48],
        "idle_side": [-54],
        "walk_side": [-54, -55, -56, -57],  # 53-56 face left
        "attack_1": [63, 64, 65],
    }
    compose_grid(img, boxes, picks, (40, 40),
                 KH / "processed/sheets/shadow_heartless.png", KH / "manifests/shadow_heartless.json",
                 "res://assets/franchises/kingdom_hearts/processed/sheets/shadow_heartless.png",
                 fps={"idle_down": 4})


def prep_large_body() -> None:
    img = chroma_key(load_rgba(KH / "raw/fatbandit.png"), (200, 191, 231), tol=12)
    boxes = find_islands(img, min_area=40, merge_gap=1)
    picks = {
        "idle_down": [1],
        "walk_down": [1, 2, 3, 4, 5, 6],
        "idle_side": [-9],
        "walk_side": [-9, -10, -11, -12],  # row 2 faces left
        "idle_up": [15],
        "walk_up": [14, 15],
        "attack_1": [16, 17, 18],
        "hurt": [23],
    }
    # regular Large Body enemy
    compose_grid(img, boxes, picks, (110, 108),
                 KH / "processed/sheets/large_body.png", KH / "manifests/large_body.json",
                 "res://assets/franchises/kingdom_hearts/processed/sheets/large_body.png",
                 fps={"walk_down": 6, "walk_side": 6})
    # corrupted boss variant: same frames, bridge-static tint
    corrupt = tint_purple(img)
    compose_grid(corrupt, boxes, picks, (110, 108),
                 KH / "processed/sheets/corrupted_fat_bandit.png", KH / "manifests/corrupted_fat_bandit.json",
                 "res://assets/franchises/kingdom_hearts/processed/sheets/corrupted_fat_bandit.png",
                 fps={"walk_down": 6, "walk_side": 6})


def prep_patch() -> None:
    img = chroma_key(load_rgba(ROOT / "assets/patch/Game Boy Advance - Kingdom Hearts_ Chain of Memories - Non-Playable Characters - Moogle (1).png"), (0, 117, 0), tol=40)
    boxes = find_islands(img, min_area=30, merge_gap=0)
    picks = {
        "idle_down": [0, 1],
        "walk_down": [0, 1, 2, 3],
        "idle_side": [12],
        "walk_side": [12, 13, 14, 15],
        "idle_up": [20],
        "walk_up": [20, 21, 22, 23],
    }
    compose_grid(img, boxes, picks, (28, 36),
                 SHARED.parent / "patch/sheets/patch.png", SHARED.parent / "patch/manifests/patch.json",
                 "res://assets/shared/patch/sheets/patch.png",
                 fps={"idle_down": 5}, anchor="center")
    save_island(img, boxes[33], SHARED / "patch.png")  # big moogle art = portrait


def prep_cloud() -> None:
    img = load_rgba(FF / "raw/ff_cloud.png")
    boxes = find_islands(img, min_area=40, merge_gap=0)
    picks = {
        "idle_down": [0],
        "walk_down": [83, 84, 85, 86],
        "idle_side": [-37],
        "walk_side": [-37, -38],   # 36, 37 face left
        "walk_up": [73, 74],
        "attack_1": [32, 33],
    }
    compose_grid(img, boxes, picks, (28, 34),
                 FF / "processed/sheets/cloud.png", FF / "manifests/cloud.json",
                 "res://assets/franchises/final_fantasy/processed/sheets/cloud.png")
    # portrait: idle frame at 4x
    crop = img.crop(tuple(boxes[0]))
    crop = crop.resize((crop.width * 4, crop.height * 4), Image.NEAREST)
    (FF / "processed").mkdir(parents=True, exist_ok=True)
    crop.save(FF / "processed/cloud.png")


def prep_hero_portrait() -> None:
    sheet = load_rgba(ROOT / "assets/hero/raw/hero_faraway_overworld.png")
    crop = sheet.crop((32, 0, 64, 32)).resize((96, 96), Image.NEAREST)
    SHARED.mkdir(parents=True, exist_ok=True)
    crop.save(SHARED / "hero.png")


def prep_traverse_props() -> None:
    img = chroma_key(load_rgba(LOC / "Game Boy Advance - Kingdom Hearts_ Chain of Memories - Backgrounds - Traverse Town.png"), (255, 255, 255), tol=3)
    boxes = [b for b in find_islands(img, min_area=200, merge_gap=1) if b[1] > 650 and (b[2] - b[0]) < 300]
    out = LOC / "processed"
    named = {
        "save_point": 0, "chest": 1, "chest_open": 2, "ladder": 3,
        "door": 13, "floor_cobble": 16, "rug": 17, "crate_lantern": 19,
        "barrel": 20, "lamp_lit": 21, "lamp_dark": 22, "chest_gold": 23,
        "crates": 24,
    }
    for name, idx in named.items():
        box = list(boxes[idx])
        if name == "floor_cobble":
            # inset past the swatch's soft edge so it tiles without seams
            box = [box[0] + 4, box[1] + 4, box[2] - 4, box[3] - 4]
        save_island(img, tuple(box), out / f"{name}.png")
    print(f"  wrote {len(named)} traverse props -> {out}")


def prep_item_icons() -> None:
    # Keyblades (KH CoM, ripped by Oshio)
    kb = load_rgba(ROOT / "assets/items/Game Boy Advance - Kingdom Hearts_ Chain of Memories - Miscellaneous - Keyblades.png")
    kboxes = [b for b in find_islands(kb, min_area=80, merge_gap=1) if b[1] < 130]
    kb_items = {
        ("kingdom_hearts", "kingdom_key"): 0,
        ("crossover", "courage_keyblade"): 11,
        ("kingdom_hearts", "keychain"): 16,
        ("zelda", "small_key"): 16,
    }
    for (world, name), idx in kb_items.items():
        save_island(kb, kboxes[idx], ROOT / f"assets/franchises/{world}/processed/items/{name}.png")
    # Mario & Luigi items (ripped by A.J. Nitro) — the sheet's generic RPG
    # icons (jars, gems, beans, nuts, eggs) also stand in for other worlds'
    # consumables until franchise-specific art arrives.
    ml = chroma_key(load_rgba(ROOT / "assets/items/Game Boy Advance - Mario & Luigi_ Superstar Saga - Miscellaneous - Items.png"), (156, 219, 255), tol=8)
    mboxes = find_islands(ml, min_area=60, merge_gap=1)
    ml_items = {
        ("mario", "super_mushroom"): 6,
        ("mario", "one_up_mushroom"): 37,
        ("mario", "fire_flower"): 39,
        ("mario", "starman"): 110,
        ("mario", "mario_hammer"): 140,
        ("mario", "yoshi_egg"): 160,
        ("kingdom_hearts", "kh_potion"): 68,
        ("kingdom_hearts", "kh_ether"): 80,
        ("kingdom_hearts", "kh_elixir"): 87,
        ("kingdom_hearts", "bright_shard"): 113,
        ("final_fantasy", "ff_potion"): 70,
        ("final_fantasy", "hi_potion"): 83,
        ("final_fantasy", "crystal_shard_ff"): 124,
        ("zelda", "rupee"): 123,
        ("zelda", "deku_nut"): 173,
        ("zelda", "triforce_fragment"): 102,
        ("dragon_ball", "senzu_bean"): 133,
        ("pokemon", "rare_candy"): 108,
        ("pokemon", "lucky_egg"): 147,
        ("mario", "power_wrist"): 91,
    }
    for (world, name), idx in ml_items.items():
        save_island(ml, mboxes[idx], ROOT / f"assets/franchises/{world}/processed/items/{name}.png")
    print(f"  wrote {len(kb_items) + len(ml_items)} item icons")


def prep_menu_ui() -> None:
    """Slice the supplied menu/buttons asset sheet into named UI pieces."""
    img = chroma_key(load_rgba(ROOT / "assets/shared/ui/menusbuttonsassets.png"), (0, 0, 0), tol=6)
    boxes = find_islands(img, min_area=100, merge_gap=2)
    out = ROOT / "assets/shared/ui/processed"
    named = {
        "bar_small": 0, "panel_square": 2, "panel_ornate_big": 3,
        "bar_white": 7, "bar_blue": 4,
        "progress_bar": 6, "divider_sparkle": 31,
        "cursor_hand": 32, "star_gold": 37, "star_blue": 38, "star_gray": 39,
        "panel_wide": 27,
    }
    for name, idx in named.items():
        save_island(img, boxes[idx], out / f"{name}.png")
    # UI-scale variants (premultiplied resize: no dark edge halos)
    for name, target in [("bar_white", ("h", 24)), ("bar_blue", ("h", 24)), ("cursor_hand", ("w", 24))]:
        p = out / f"{name}.png"
        im = Image.open(p).convert("RGBA")
        if target[0] == "h":
            size = (max(1, round(im.width * target[1] / im.height)), target[1])
        else:
            size = (target[1], max(1, round(im.height * target[1] / im.width)))
        resize_rgba(im, size).save(p)
    print(f"  wrote {len(named)} menu UI pieces -> {out}")


if __name__ == "__main__":
    print("sora..."); prep_sora()
    print("shadow..."); prep_shadow()
    print("large body / fat bandit..."); prep_large_body()
    print("patch (moogle)..."); prep_patch()
    print("cloud..."); prep_cloud()
    print("hero portrait..."); prep_hero_portrait()
    print("traverse props..."); prep_traverse_props()
    print("item icons..."); prep_item_icons()
    print("menu ui..."); prep_menu_ui()
    print("done")
