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
from slice_lib import chroma_key, clean_alpha, compose_grid, find_islands, flood_bg, keep_components, largest_component, load_rgba, resize_rgba, save_island, shave_sparse_edges

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
        "panel_wide": 27, "hud_bar": 0,
    }
    for name, idx in named.items():
        save_island(img, boxes[idx], out / f"{name}.png")

    # Game-scale variants: drop merged-in specks, premultiplied resize (no
    # dark halos), binarize alpha (semi rows read as gray dashes on white),
    # then sweep any specks the binarize detached (baked shadow crumbs).
    def refine(name: str, axis: str, target: int, shave: str = "rows") -> None:
        p = out / f"{name}.png"
        im = clean_alpha(largest_component(Image.open(p).convert("RGBA")), lo=1, hi=255)
        if axis == "h":
            size = (max(1, round(im.width * target / im.height)), target)
        else:
            size = (target, max(1, round(im.height * target / im.width)))
        im = clean_alpha(resize_rgba(im, size), lo=128, hi=128)
        im = clean_alpha(largest_component(im), lo=1, hi=255)
        if shave != "none":
            # baked drop shadows leave sparse near-black crumbs along the
            # borders (they touch the outline, so largest_component keeps
            # them). Columns only where sparse edge columns aren't art
            # (bars' pointed caps and the cursor's fingertip are sparse).
            im = shave_sparse_edges(im, cols=(shave == "both"))
        im.save(p)

    refine("bar_white", "h", 24)
    refine("bar_blue", "h", 24)
    refine("hud_bar", "h", 36)
    refine("cursor_hand", "w", 24, shave="none")
    # Pre-scale the modal panel to its in-game width: the nine-patch must
    # only ever stretch UP — nearest-filter DOWN-scaling decimates the ornate
    # border into a tattered edge.
    refine("panel_wide", "w", 380, shave="both")
    print(f"  wrote {len(named)} menu UI pieces -> {out}")


def prep_lobby_locations() -> None:
    """Building sprites for the lobby's five doors, cut clean from the
    supplied sheets (user-picked buildings; see currentsessionimages/*sprite
    for the reference picks). Flood-fill from the borders removes grass/sky
    without eating same-colored art inside the outlines."""
    out = LOC / "processed/lobby"
    out.mkdir(parents=True, exist_ok=True)

    def finish(im: Image.Image, name: str, max_dim: int, min_area: int = 0, largest: bool = False) -> None:
        im = largest_component(im) if largest else keep_components(im, min_area)
        im = clean_alpha(im, lo=1, hi=255)
        if max(im.size) != max_dim:
            k = max_dim / max(im.size)
            size = (max(1, round(im.width * k)), max(1, round(im.height * k)))
            if k > 1 and abs(k - round(k)) < 1e-6:
                im = im.resize(size, Image.NEAREST)  # crisp integer upscale
            else:
                im = resize_rgba(im, size)
                im = clean_alpha(im, lo=128, hi=128)
                im = clean_alpha(keep_components(im, 8), lo=1, hi=255)
        im.save(out / f"{name}.png")
        print(f"  {name}: {im.size}")

    # Item shop: floating-island shop, KH CoM level images (white bg)
    kh = load_rgba(LOC / "raw/kh_level_images.png")
    boxes = find_islands(chroma_key(kh, (255, 255, 255), tol=6), min_area=400, merge_gap=2)
    island = chroma_key(kh.crop(tuple(boxes[6])), (255, 255, 255), tol=6)
    finish(island, "itemshop", 110, min_area=6)

    # Market: Kecleon shop, PMD Treasure Town — flood off grass/trees/path.
    # Tree greens have near-zero blue; the tent's own greens are blue-rich,
    # which is what keeps the flood out of the Kecleon head.
    pmd = load_rgba(LOC / "raw/pmd_treasure_town.png")
    def pmd_bg(rgb: np.ndarray) -> np.ndarray:
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        grass = (g > 130) & (r > 130) & (b < 140) & (g >= r - 40)
        tree = (g >= 70) & (b < 50) & (g > r + 10)
        tan = (r > 180) & (g > 140) & (b < 160) & (r > g) & (g > b)
        rock = (np.abs(r - g) < 30) & (np.abs(g - b) < 40) & (r > 120) & (r < 220)
        return grass | tree | tan | rock
    finish(flood_bg(pmd.crop((277, 68, 396, 225)), pmd_bg), "market", 110, min_area=40)

    # Workshop: Peach's Castle (M&L: Superstar Saga) — flood off mint + greens
    castle = load_rgba(LOC / "raw/peach_castle.png")
    def castle_bg(rgb: np.ndarray) -> np.ndarray:
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        mint = (g > 190) & (b > 160) & (r < 200) & (g > r)
        green = (g > 110) & (g > r + 20) & (g > b + 20)
        # bush highlight outlines: neutral white/gray — the castle's own
        # walls are cream (blue well below red), so they stay
        white = (r > 190) & (g > 190) & (b > 185) & (np.abs(r.astype(int) - b) < 15)
        return mint | green | white
    finish(flood_bg(castle.crop((0, 1330, 245, 1495)), castle_bg), "workshop", 118, min_area=250)

    # Adventurers' Guild: yellow figurine (Minish Cap figurines, lavender bg)
    minish = load_rgba(LOC / "raw/minish_figurines.png")
    def lavender_bg(rgb: np.ndarray) -> np.ndarray:
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        return (np.abs(r - g) < 12) & (b > r + 30) & (r > 140) & (r < 210)
    finish(flood_bg(minish.crop((150, 855, 290, 990)), lavender_bg), "guild", 104, largest=True)

    # Home: bed (Minish Cap interior, by Peitos) — solid dark-red bg
    home = load_rgba(LOC / "raw/minish_home_interior.png")
    finish(chroma_key(home.crop((6, 169, 40, 219)), (126, 0, 0), tol=30), "home", 100, largest=True)


## Top-30 popular FF characters used as the shop-customer visual pool.
FF_CUSTOMERS = [
    "tifa", "aerith", "sephiroth", "barret", "vincent", "yuffie", "zack",
    "squall", "rinoa", "seifer", "terra", "celes", "locke", "kefka",
    "tidus", "yuna", "auron", "rikku", "lulu", "wakka",
    "zidane", "vivi", "garnet", "kuja", "lightning", "noctis",
    "kain", "rydia", "bartz", "gilgamesh",
]


def frame_score(im: Image.Image) -> float:
    """Colorful, well-covered, non-ghost character frames score high; the
    source sheets are full of white silhouettes, labels, flags, huts and
    effect blobs. Character sprites in these rips carry dark outlines, so a
    strong outline is weighted in; flat props and flames get pushed down."""
    a = np.asarray(im).astype(np.float32)
    vis = a[..., 3] > 10
    cov = float(vis.mean())
    if not (0.2 <= cov <= 0.95):
        return -1.0
    rgb = a[vis][:, :3]
    if len(rgb) == 0:
        return -1.0
    whiteish = float(((rgb > 225).all(axis=1)).mean())
    darkish = float((rgb.max(axis=1) < 60).mean())
    mx = rgb.max(axis=1)
    sat = float(((mx - rgb.min(axis=1)) / np.maximum(mx, 1.0)).mean())
    ncolors = len(np.unique((rgb.astype(np.uint8)) // 16, axis=0))
    # outline: visible pixels bordering transparency that are dark
    alpha = a[..., 3] > 10
    inner = alpha.copy()
    inner[1:, :] &= alpha[:-1, :]
    inner[:-1, :] &= alpha[1:, :]
    inner[:, 1:] &= alpha[:, :-1]
    inner[:, :-1] &= alpha[:, 1:]
    edge = alpha & ~inner
    edge_px = a[edge][:, :3]
    outline = float((edge_px.max(axis=1) < 110).mean()) if len(edge_px) else 0.0
    return (ncolors * 0.8 + sat * 120.0 + cov * 20.0 + outline * 80.0
            - whiteish * 150.0 - darkish * 15.0)


def write_customer_pool() -> None:
    """data/customer_visuals.json = every extracted customer frame across
    all franchises."""
    import json as _json

    pool: list[str] = []
    for png in sorted((ROOT / "assets/franchises").glob("*/processed/customers/*.png")):
        rel = png.relative_to(ROOT).as_posix()
        pool.append("res://" + rel)
    doc = {"schema": "crossroads.customer_visuals.v1", "pool": pool}
    (ROOT / "data/customer_visuals.json").write_text(_json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    print(f"  customer pool: {len(pool)} entries")


def prep_ff_customers() -> None:
    """One validated idle frame per character from the FFRK compilation
    sheets. The sheets are messy pose dumps; the top-left 16x24 cell is
    usually a clean front-facing stand, so take it when it passes a quality
    check and otherwise scan islands for the first stand-sized frame that
    does."""
    out = FF / "processed/customers"
    out.mkdir(parents=True, exist_ok=True)

    picked: list[str] = []
    for name in FF_CUSTOMERS:
        raw = FF / f"raw/ff_{name}.png"
        if not raw.exists():
            print(f"  {name}: MISSING raw sheet, skipped")
            continue
        img = load_rgba(raw)
        candidates = [img.crop((1, 1, 17, 25))]
        for box in find_islands(img, min_area=40, merge_gap=0)[:80]:
            w, h = box[2] - box[0], box[3] - box[1]
            if 12 <= w <= 20 and 18 <= h <= 28:
                candidates.append(img.crop(tuple(box)))
        best = max(candidates, key=frame_score)
        if frame_score(best) < 10.0:
            print(f"  {name}: no clean frame found, skipped")
            continue
        clean_alpha(best, lo=1, hi=255).save(out / f"{name}.png")
        picked.append(name)
    print(f"  wrote {len(picked)} FF customer frames")


## 10-15 user-picked customers per franchise (sheets in raw/customers/).
FRANCHISE_CUSTOMERS = {
    "dragon_ball": ("sprite_%s.png", [
        "goku", "vegeta", "piccolo", "krillin", "gohan_casual", "future_trunks",
        "tien_shinhan", "yamcha", "hercule_mr_satan", "bulma_s_familly",
        "goku_super_saiyan", "vegeta_super_saiyan"]),
    "naruto": ("naruto_%s.png", [
        "kakashi", "sakura", "sasuke_black_outfit",
        "shikamaru_ino_choji", "neji_lee_tenten", "kiba_akamaru_shino_hinata",
        "zabuza_haku", "orochimaru_kabuto_misumi_itachi", "konohamaru_ebisu",
        "iruka_asuma_guy", "hidden_leaf_ninja"]),
    "mario": ("mario_%s.png", [
        "goomba", "koopa_troopas", "boo", "bob_omb", "dry_bones",
        "hammer_bro", "blooper", "bowser_usa",
        "lady_lima", "beanbean_kingdom_residents", "cheep_cheep_puffer_cheep"]),
    "pokemon": ("pokemon_%s.png", [
        "snorlax", "ditto", "mew", "mewtwo", "dratini_dragonair_dragonite",
        "absol", "aerodactyl", "aipom", "banette", "blissey", "bellossom",
        "castform", "articuno_zapdos_moltres"]),
    "kingdom_hearts": ("kh_%s_gba.png", [
        "donald_duck", "goofy", "mickey_mouse", "kairi", "hades",
        "ariel", "peter_pan", "alice", "hercules",
        "wakka", "tidus", "selphie"]),
}


def prep_franchise_customers() -> None:
    """Best standing frame per picked character from the newly supplied
    franchise customer sheets. Backgrounds vary (solid pastels, the DBZ
    two-tone green checker); key the corner color(s), collect stand-sized
    islands and keep the best-scoring frame."""
    from collections import Counter

    for world, (pattern, names) in FRANCHISE_CUSTOMERS.items():
        src_dir = ROOT / f"assets/franchises/{world}/raw/customers"
        out = ROOT / f"assets/franchises/{world}/processed/customers"
        out.mkdir(parents=True, exist_ok=True)
        done = 0
        for name in names:
            path = src_dir / (pattern % name)
            if not path.exists():
                print(f"  {world}/{name}: MISSING {path.name}")
                continue
            img = load_rgba(path)
            a = np.array(img)
            # backgrounds vary (pastel fills, colored borders, the DBZ
            # two-tone checker): key the corner color plus any color that
            # covers >12% of the sheet — backgrounds dominate these rips
            opaque = a[a[..., 3] > 0][:, :3]
            keyed: list[tuple[int, int, int]] = []
            corners = [tuple(a[0, 0]), tuple(a[0, -1]), tuple(a[-1, 0]), tuple(a[-1, -1])]
            corner = Counter(corners).most_common(1)[0][0]
            if corner[3] > 0:
                keyed.append((int(corner[0]), int(corner[1]), int(corner[2])))
            if len(opaque):
                for col, cnt in Counter(map(tuple, opaque)).most_common(4):
                    if cnt / len(opaque) > 0.12 and not any(
                            max(abs(col[i] - k[i]) for i in range(3)) <= 12 for k in keyed):
                        keyed.append((int(col[0]), int(col[1]), int(col[2])))
            for k in keyed:
                img = chroma_key(img, k, tol=12)
            best = None
            best_s = 8.0
            for box in find_islands(img, min_area=80, merge_gap=1)[:260]:
                w, h = box[2] - box[0], box[3] - box[1]
                if not (14 <= w <= 52 and 20 <= h <= 66 and h >= w * 0.75):
                    continue
                cand = img.crop(tuple(box))
                s = frame_score(cand)
                if s > best_s:
                    best_s = s
                    best = cand
            if best is None:
                print(f"  {world}/{name}: no clean frame found, skipped")
                continue
            best = clean_alpha(best, lo=1, hi=255)
            if best.height > 44:  # keep customers around hero scale
                k = 40.0 / best.height
                best = resize_rgba(best, (max(1, round(best.width * k)), 40))
                best = clean_alpha(largest_component(clean_alpha(best, lo=128, hi=128)), lo=1, hi=255)
            slug = name.replace("3rd_", "third_")
            best.save(out / f"{slug}.png")
            done += 1
        print(f"  {world}: {done}/{len(names)} customers")


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
    print("lobby locations..."); prep_lobby_locations()
    print("ff customers..."); prep_ff_customers()
    print("franchise customers..."); prep_franchise_customers()
    write_customer_pool()
    print("done")
