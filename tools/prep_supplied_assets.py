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
    # named shop customers need their own character (never a stand-in)
    "cloud", "cid_vii", "mog",
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


def _mirror_symmetry(im: Image.Image) -> float:
    """0..1: how horizontally symmetric the sprite is. Front- and back-facing
    stands score high, side profiles and action poses score low."""
    a = np.asarray(im)
    al = a[..., 3] > 10
    fl = al[:, ::-1]
    union = (al | fl).sum()
    if union == 0:
        return 0.0
    iou = float((al & fl).sum()) / float(union)
    both = al & fl
    col = 0.0
    if both.any():
        rgb = a[..., :3].astype(np.int16)
        diff = np.abs(rgb - rgb[:, ::-1]).max(axis=2)
        col = float((diff[both] <= 48).mean())
    return 0.55 * iou + 0.45 * col


def _face_detail(im: Image.Image) -> float:
    """0..1: color variety in the upper half. Faces (eyes/skin/hair edges)
    are busy; the back of a head is a flat hair blob."""
    a = np.asarray(im)
    top = a[: max(1, int(a.shape[0] * 0.45))]
    vis = top[top[..., 3] > 10][:, :3]
    if len(vis) < 10:
        return 0.0
    ncol = len(np.unique(vis // 24, axis=0))
    return min(1.0, ncol / 10.0)


def front_score(im: Image.Image) -> float:
    """frame_score biased hard toward front-facing standing frames: the pool
    sprite IS the customer's face in the shop and the negotiation portrait."""
    s = frame_score(im)
    if s < 0:
        return s
    return s + 110.0 * _mirror_symmetry(im) + 45.0 * _face_detail(im)


def _key_sheet(img: Image.Image, extra_keys: list | None = None) -> Image.Image:
    """Key a rip's background: the dominant corner color plus any color
    covering >12% of the sheet (checker backgrounds have two), plus caller
    extras (e.g. grid-line colors)."""
    from collections import Counter

    a = np.array(img)
    opaque = a[a[..., 3] > 0][:, :3]
    keyed: list[tuple[int, int, int]] = [tuple(int(v) for v in k) for k in (extra_keys or [])]
    corners = [tuple(a[0, 0]), tuple(a[0, -1]), tuple(a[-1, 0]), tuple(a[-1, -1])]
    corner = Counter(corners).most_common(1)[0][0]
    if corner[3] > 0:
        keyed.append((int(corner[0]), int(corner[1]), int(corner[2])))
    if len(opaque):
        for col, cnt in Counter(map(tuple, opaque)).most_common(4):
            col = tuple(int(c) for c in col)
            if cnt / len(opaque) > 0.12 and not any(
                    max(abs(col[i] - k[i]) for i in range(3)) <= 12 for k in keyed):
                keyed.append(col)
    for k in keyed:
        img = chroma_key(img, k, tol=12)
    return img


def _sheet_rows(img: Image.Image, n_rows: int = 4) -> list:
    """Sprite rows on a LoG2-style strip: the rows sit in one tall alpha
    block (they touch, so gaps can't split them); title/credit text forms
    separate short bands. Take the tallest band and cut it into n_rows
    equal rows."""
    a = np.array(img)
    rows = (a[..., 3] > 10).any(axis=1)
    bands: list[tuple[int, int]] = []
    y, height = 0, img.height
    while y < height:
        while y < height and not rows[y]:
            y += 1
        if y >= height:
            break
        y0 = y
        while y < height and rows[y]:
            y += 1
        bands.append((y0, y))
    if not bands:
        return []
    y0, y1 = max(bands, key=lambda b: b[1] - b[0])
    if (y1 - y0) < n_rows * 16:
        return []
    step = (y1 - y0) / n_rows
    return [(int(y0 + i * step), int(y0 + (i + 1) * step)) for i in range(n_rows)]


## Sheets with clean multi-direction walk rows become fully animated
## customers. log2 = Legacy-of-Goku-2 strips: 4 sprite rows top-to-bottom =
## facing down, side, side, up; frame 0 of a row stands, the walk follows.
WALK_ANIM_WORLDS = {
    "dragon_ball": {
        "pattern": "sprite_%s.png",
        "names": ["goku", "vegeta", "piccolo", "krillin", "gohan_casual",
                  "future_trunks", "tien_shinhan", "yamcha", "hercule_mr_satan",
                  "goku_super_saiyan", "vegeta_super_saiyan"],
        "side_row": 1, "up_row": 3, "side_faces_left": True,
    },
}


def prep_customer_walk_anims() -> None:
    """Directional walk animations for pool customers whose rips carry full
    walk rows. Writes processed/sheets/pool_<name>.png + manifests/pool_<name>.json
    and overwrites the static frame with the front-facing stand."""
    for world, cfg in WALK_ANIM_WORLDS.items():
        src_dir = ROOT / f"assets/franchises/{world}/raw/customers"
        done = 0
        for name in cfg["names"]:
            path = src_dir / (cfg["pattern"] % name)
            if not path.exists():
                print(f"  {world}/{name}: MISSING {path.name}")
                continue
            img = _key_sheet(load_rgba(path))
            bands = _sheet_rows(img)
            if len(bands) < 4:
                print(f"  {world}/{name}: only {len(bands)} sprite rows, skipped")
                continue

            def row_frames(i: int) -> list:
                y0, y1 = bands[i]
                min_h = int((y1 - y0) * 0.55)
                return [f for f in _band_frames(img, (0, y0, img.width, y1))
                        if f.height >= min_h and f.width >= 12]

            down = row_frames(0)
            side = row_frames(cfg["side_row"])
            up = row_frames(cfg["up_row"])
            if len(down) < 5 or len(side) < 5 or len(up) < 5:
                print(f"  {world}/{name}: thin rows (%d/%d/%d), skipped" % (len(down), len(side), len(up)))
                continue
            if cfg["side_faces_left"]:
                side = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in side]

            # frames after the walk cycle are actions (punches lunge wider
            # than strides) — keep near-stand-width frames only
            def cycle(frames: list) -> list:
                base = frames[1].width
                out = [f for f in frames[1:7] if f.width <= base * 1.3]
                return out[:4] if len(out) >= 2 else frames[1:4]

            down = [down[0]] + cycle(down)
            side = [side[0]] + cycle(side)
            up = [up[0]] + cycle(up)
            # one shared scale so the cycle doesn't wobble between frames
            all_fr = down + side + up
            max_h = max(f.height for f in all_fr)
            if max_h > 44:
                k = 40.0 / max_h
                all_fr = [resize_rgba(f, (max(1, round(f.width * k)), max(1, round(f.height * k)))) for f in all_fr]
                down = all_fr[:len(down)]
                side = all_fr[len(down):len(down) + len(side)]
                up = all_fr[len(down) + len(side):]
            anims = {
                "idle_down": [down[0]], "walk_down": down[1:],
                "idle_side": [side[0]], "walk_side": side[1:],
                "idle_up": [up[0]], "walk_up": up[1:],
            }
            cell = (max(f.width for f in all_fr) + 4, max(f.height for f in all_fr) + 2)
            _compose_anims(anims, cell,
                           ROOT / f"assets/franchises/{world}/processed/sheets/pool_{name}.png",
                           ROOT / f"assets/franchises/{world}/manifests/pool_{name}.json",
                           f"res://assets/franchises/{world}/processed/sheets/pool_{name}.png",
                           fps={"walk_down": 8, "walk_side": 8, "walk_up": 8})
            # the front-facing stand doubles as the static frame + portrait
            out = ROOT / f"assets/franchises/{world}/processed/customers"
            out.mkdir(parents=True, exist_ok=True)
            down[0].save(out / f"{name}.png")
            done += 1
        print(f"  {world}: {done} animated customers")


## ---------------------------------------------------------------------------
## Generic walk-row understanding for RPG-style rips (M&L Superstar Saga etc.):
## find horizontal rows of similar-sized frames, split side-by-side animation
## blocks apart, and classify each row's facing from symmetry + face detail.
## Only rows that pass the classifier become animations; everything else on
## the sheet (battle poses, effects, props) is ignored.

AUTO_WALK_CUSTOMERS = {
    "mario": {
        "pattern": "mario_%s.png",
        "names": ["bowser_usa", "princess_peach", "mario_overworld",
                  "luigi_overworld", "toad", "koopa_troopas", "goomba"],
    },
}

## Manual row overrides after checking tools/out/walk_review.png +
## tools/out/segs_<name>.png: {(world, name): {"down": seg_id, "side": seg_id,
## "up": seg_id (-1 drops the direction), "side_faces_left": bool}}.
AUTO_WALK_FIXES: dict[tuple[str, str], dict] = {
    ("mario", "bowser_usa"): {"down": 1, "side": 3, "up": -1},
    ("mario", "princess_peach"): {"side": 4, "up": 2},
    ("mario", "mario_overworld"): {"down": 0, "side": 2, "up": 9},
    ("mario", "luigi_overworld"): {"down": 0, "side": 3, "up": 6},
    ("mario", "toad"): {"side": 2, "up": 4},
    ("mario", "koopa_troopas"): {"down": 0, "side": 1, "up": 2},
}


def _row_segments(img: Image.Image) -> list:
    """Candidate animation rows: islands clustered by vertical overlap, then
    split on wide x-gaps (sheets pack several blocks side by side). Returns
    [{frames, ys, xs}] sorted top-to-bottom, left-to-right."""
    boxes = [b for b in find_islands(img, min_area=80, merge_gap=1)
             if 10 <= b[2] - b[0] <= 90 and 16 <= b[3] - b[1] <= 90]
    boxes.sort(key=lambda b: ((b[1] + b[3]) / 2, b[0]))
    clusters: list[list] = []
    for b in boxes:
        yc = (b[1] + b[3]) / 2
        placed = False
        for cl in clusters:
            cy = sum((c[1] + c[3]) / 2 for c in cl) / len(cl)
            ch = sum(c[3] - c[1] for c in cl) / len(cl)
            if abs(yc - cy) < ch * 0.45:
                cl.append(b)
                placed = True
                break
        if not placed:
            clusters.append([b])
    segments: list[dict] = []
    for cl in clusters:
        cl.sort(key=lambda b: b[0])
        widths = sorted(b[2] - b[0] for b in cl)
        med_w = widths[len(widths) // 2]
        seg: list = [cl[0]]
        for prev, b in zip(cl, cl[1:]):
            if b[0] - prev[2] > med_w * 1.6:
                segments.append({"boxes": seg})
                seg = []
            seg.append(b)
        segments.append({"boxes": seg})
    out: list[dict] = []
    for s in segments:
        bs = s["boxes"]
        if len(bs) < 4:
            continue
        hs = sorted(b[3] - b[1] for b in bs)
        ws = sorted(b[2] - b[0] for b in bs)
        med_h, med_w = hs[len(hs) // 2], ws[len(ws) // 2]
        bs = [b for b in bs
              if 0.72 <= (b[3] - b[1]) / med_h <= 1.28 and 0.55 <= (b[2] - b[0]) / med_w <= 1.5]
        if len(bs) < 4:
            continue
        out.append({"boxes": bs, "y": bs[0][1], "x": bs[0][0]})
    out.sort(key=lambda s: (s["y"], s["x"]))
    return out


def _frame_faces_left(f: Image.Image) -> bool | None:
    """One side frame's facing: the face (bright skin/eye pixels in the upper
    half) sits on the side the character looks toward. None = can't tell."""
    a = np.asarray(f).astype(np.float32)
    top = a[: max(1, int(a.shape[0] * 0.5))]
    vis = top[..., 3] > 10
    bright = vis & (top[..., :3].max(axis=2) > 150) & \
        ((top[..., :3].max(axis=2) - top[..., :3].min(axis=2)) < 110)
    _, xs = np.nonzero(bright)
    if len(xs) < 6:
        return None
    return bool(xs.mean() < f.width / 2.0)


def _facing_left(frames: list) -> bool:
    votes = 0
    for f in frames[:6]:
        v = _frame_faces_left(f)
        if v is not None:
            votes += 1 if v else -1
    return votes > 0


def _filter_side_frames(frames: list) -> list:
    """Side rows on these sheets often pack left- AND right-facing cycles in
    one band; keep only the majority facing so the animation doesn't flip
    mid-stride."""
    majority = _facing_left(frames)
    kept = [f for f in frames if _frame_faces_left(f) in (majority, None)]
    return kept if len(kept) >= 3 else frames


def detect_walk_rows(img: Image.Image) -> dict:
    """{'down': frames, 'side': frames, 'up': frames, 'side_faces_left': bool,
    'segments': all} — empty dict when the sheet has no readable walk rows."""
    segments = _row_segments(img)
    if len(segments) < 2:
        return {}
    scored = []
    for i, seg in enumerate(segments[:14]):  # walk cycles live near the top
        frames = [clean_alpha(img.crop(tuple(b)), lo=1, hi=255) for b in seg["boxes"]]
        sym = sum(_mirror_symmetry(f) for f in frames[:6]) / min(6, len(frames))
        fd = sum(_face_detail(f) for f in frames[:6]) / min(6, len(frames))
        scored.append({"id": i, "frames": frames, "sym": sym, "fd": fd})
    down = max(scored, key=lambda s: s["sym"] * 0.8 + s["fd"] * 1.4)
    rest = [s for s in scored if s["id"] != down["id"]]
    if not rest:
        return {}
    up = max(rest, key=lambda s: s["sym"] * 1.2 - s["fd"] * 1.4)
    rest2 = [s for s in rest if s["id"] != up["id"]]
    side = min(rest2, key=lambda s: s["sym"]) if rest2 else None
    out = {"down": down["frames"], "segments": scored}
    if down["sym"] < 0.55 or down["fd"] < 0.3:
        return {}
    if side is not None and side["sym"] < down["sym"] - 0.08:
        out["side"] = side["frames"]
        out["side_faces_left"] = _facing_left(side["frames"])
    if up["id"] != down["id"] and up["sym"] > 0.55 and up["fd"] < down["fd"]:
        out["up"] = up["frames"]
    return out


def prep_auto_walk_anims() -> None:
    """Walk manifests for AUTO_WALK_CUSTOMERS via detect_walk_rows. A sheet
    that only yields a readable down row still upgrades the static frame to
    the verified front-facing stand; side/up rows are added when found."""
    for world, cfg in AUTO_WALK_CUSTOMERS.items():
        src_dir = ROOT / f"assets/franchises/{world}/raw/customers"
        done = 0
        for name in cfg["names"]:
            path = src_dir / (cfg["pattern"] % name)
            if not path.exists():
                print(f"  {world}/{name}: MISSING")
                continue
            img = _key_sheet(load_rgba(path))
            rows = detect_walk_rows(img)
            fix = AUTO_WALK_FIXES.get((world, name), {})
            if fix and rows.get("segments"):
                segs = {s["id"]: s["frames"] for s in rows["segments"]}
                for key in ("down", "side", "up"):
                    if key in fix and fix[key] in segs:
                        rows[key] = segs[fix[key]]
                    elif key in fix and fix[key] < 0:
                        rows.pop(key, None)
                if "side_faces_left" in fix:
                    rows["side_faces_left"] = fix["side_faces_left"]
            if not rows.get("down"):
                print(f"  {world}/{name}: no readable walk rows, left static")
                continue
            slug = CUSTOMER_FIXES.get((world, name), {}).get("rename",
                                                             name.replace("3rd_", "third_"))

            def cycle(frames: list) -> list:
                if len(frames) < 3:
                    return frames
                base = sorted(f.width for f in frames)[len(frames) // 2]
                walk = [f for f in frames[1:9] if f.width <= base * 1.3]
                return walk[:6] if len(walk) >= 2 else frames[1:5]

            anims = {"idle_down": [rows["down"][0]], "walk_down": cycle(rows["down"])}
            if rows.get("side"):
                side = _filter_side_frames(rows["side"])
                if _facing_left(side):
                    side = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in side]
                anims["idle_side"] = [side[0]]
                anims["walk_side"] = cycle(side)
            if rows.get("up"):
                anims["idle_up"] = [rows["up"][0]]
                anims["walk_up"] = cycle(rows["up"])
            all_fr = [f for v in anims.values() for f in v]
            max_h = max(f.height for f in all_fr)
            if max_h > 46:
                k = 42.0 / max_h
                resized = {a: [resize_rgba(f, (max(1, round(f.width * k)), max(1, round(f.height * k))))
                               for f in v] for a, v in anims.items()}
                anims = resized
                all_fr = [f for v in anims.values() for f in v]
            cell = (max(f.width for f in all_fr) + 4, max(f.height for f in all_fr) + 2)
            _compose_anims(anims, cell,
                           ROOT / f"assets/franchises/{world}/processed/sheets/pool_{slug}.png",
                           ROOT / f"assets/franchises/{world}/manifests/pool_{slug}.json",
                           f"res://assets/franchises/{world}/processed/sheets/pool_{slug}.png",
                           fps={"walk_down": 8, "walk_side": 8, "walk_up": 8})
            out = ROOT / f"assets/franchises/{world}/processed/customers"
            out.mkdir(parents=True, exist_ok=True)
            anims["idle_down"][0].save(out / f"{slug}.png")
            done += 1
        print(f"  {world}: {done} auto-animated customers")


## Display names for pool slugs the automatic title-casing gets wrong
## (multi-character sheets keep the file name; the frame we extract from
## them is verified visually against this name).
POOL_DISPLAY_NAMES = {
    "gohan_casual": "Gohan",
    "goku_super_saiyan": "Super Saiyan Goku",
    "vegeta_super_saiyan": "Super Saiyan Vegeta",
    "hercule_mr_satan": "Mr. Satan",
    "future_trunks": "Trunks",
    "tien_shinhan": "Tien",
    "bob_omb": "Bob-omb",
    "bowser_usa": "Bowser",
    "koopa_troopas": "Koopa Troopa",
    "hammer_bro": "Hammer Bro",
    "cheep_cheep_puffer_cheep": "Cheep Cheep",
    "beanbean_kingdom_residents": "Beanbean Resident",
    "lady_lima": "Lady Lima",
    "dry_bones": "Dry Bones",
    "sasuke_black_outfit": "Sasuke",
    "hidden_leaf_ninja": "Leaf Ninja",
    "mickey_mouse": "Mickey",
    "donald_duck": "Donald",
    "cid_vii": "Cid",
    "moogle": "Moogle",
    "bulma": "Bulma",
    "zabuza": "Zabuza",
}


def write_customer_pool() -> None:
    """data/customer_visuals.json v2: every extracted pool customer with its
    display name, static frame and (when animated) walk manifest."""
    import json as _json

    entries: list[dict] = []
    for png in sorted((ROOT / "assets/franchises").glob("*/processed/customers/*.png")):
        slug = png.stem
        world = png.relative_to(ROOT / "assets/franchises").parts[0]
        manifest = ROOT / f"assets/franchises/{world}/manifests/pool_{slug}.json"
        entries.append({
            "slug": slug,
            "name": POOL_DISPLAY_NAMES.get(slug, slug.replace("_", " ").title()),
            "world": world,
            "static": "res://" + png.relative_to(ROOT).as_posix(),
            "manifest": ("res://" + manifest.relative_to(ROOT).as_posix()) if manifest.exists() else "",
        })
    doc = {"schema": "crossroads.customer_visuals.v2", "pool": entries}
    (ROOT / "data/customer_visuals.json").write_text(_json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    animated = sum(1 for e in entries if e["manifest"])
    print(f"  customer pool: {len(entries)} entries ({animated} animated)")


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
        best = max(candidates, key=front_score)
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
        "lady_lima", "beanbean_kingdom_residents", "cheep_cheep_puffer_cheep",
        "princess_peach", "mario_overworld", "luigi_overworld", "toad"]),
    "pokemon": ("pokemon_%s.png", [
        "snorlax", "ditto", "mew", "mewtwo", "dratini_dragonair_dragonite",
        "absol", "aerodactyl", "aipom", "banette", "blissey", "bellossom",
        "castform", "articuno_zapdos_moltres"]),
    "kingdom_hearts": ("kh_%s_gba.png", [
        "donald_duck", "goofy", "mickey_mouse", "kairi", "hades",
        "ariel", "peter_pan", "alice", "hercules",
        "wakka", "tidus", "selphie", "moogle"]),
}


## Additional characters pulled out of multi-character sheets that already
## contribute someone else to the pool: (world, sheet file, slug, crop box).
## Boxes are read off tools/cand_sheet.py-style renders of the keyed sheet.
EXTRA_CUSTOMER_CROPS: list[tuple[str, str, str, tuple]] = [
    ("dragon_ball", "raw/customers/sprite_bulma_s_familly.png", "bulma", (18, 26, 38, 62)),
    ("naruto", "raw/customers/naruto_zabuza_haku.png", "zabuza", (0, 0, 40, 39)),
]


def prep_extra_customer_crops() -> None:
    """Extra pool characters from sheets whose filename character already got
    extracted under a different slug (e.g. haku from the zabuza sheet)."""
    for world, rel, slug, box in EXTRA_CUSTOMER_CROPS:
        path = ROOT / f"assets/franchises/{world}" / rel
        if not path.exists():
            print(f"  {world}/{slug}: MISSING {rel}")
            continue
        img = _key_sheet(load_rgba(path))
        best = None
        if box is not None:
            # crops carry their own background cell colors (multi-block
            # checker sheets defeat the whole-sheet key) — key again locally
            best = largest_component(_key_sheet(load_rgba(path).crop(tuple(box))))
        else:
            best_s = 8.0
            for cand_box in find_islands(img, min_area=80, merge_gap=1)[:260]:
                w, h = cand_box[2] - cand_box[0], cand_box[3] - cand_box[1]
                if not (14 <= w <= 52 and 20 <= h <= 66 and h >= w * 0.75):
                    continue
                cand = img.crop(tuple(cand_box))
                s = front_score(cand)
                if s > best_s:
                    best_s = s
                    best = cand
        if best is None:
            print(f"  {world}/{slug}: no clean frame found, skipped")
            continue
        best = clean_alpha(best, lo=1, hi=255)
        if best.height > 44:
            k = 40.0 / best.height
            best = resize_rgba(best, (max(1, round(best.width * k)), 40))
            best = clean_alpha(largest_component(clean_alpha(best, lo=128, hi=128)), lo=1, hi=255)
        out = ROOT / f"assets/franchises/{world}/processed/customers"
        out.mkdir(parents=True, exist_ok=True)
        best.save(out / f"{slug}.png")
        print(f"  {world}/{slug}: extra crop written")


## Manual corrections after visually checking tools/out/pool_sheet.png:
## "box" = explicit crop from the keyed raw sheet when the scorer misfires,
## "rename" = output slug when the winning frame from a multi-character
## sheet is a different character than the file name suggests.
CUSTOMER_FIXES: dict[tuple[str, str], dict] = {
    ("kingdom_hearts", "goofy"): {"box": (171, 0, 203, 64)},
    ("kingdom_hearts", "hades"): {"box": (2, 2, 46, 95)},
    ("kingdom_hearts", "hercules"): {"box": (7, 286, 48, 353)},
    ("kingdom_hearts", "tidus"): {"box": (0, 0, 19, 55)},
    ("kingdom_hearts", "wakka"): {"box": (81, 1, 119, 53)},
    ("mario", "boo"): {"box": (4, 983, 32, 1005)},
    ("mario", "dry_bones"): {"box": (8, 302, 26, 328)},
    ("mario", "koopa_troopas"): {"box": (8, 77, 31, 109), "rename": "koopa_troopa"},
    ("mario", "lady_lima"): {"box": (281, 50, 302, 83)},
    ("mario", "mario_overworld"): {"rename": "mario"},
    ("mario", "luigi_overworld"): {"rename": "luigi"},
    ("naruto", "kiba_akamaru_shino_hinata"): {"rename": "kiba"},
    ("naruto", "konohamaru_ebisu"): {"rename": "ebisu"},
    ("naruto", "neji_lee_tenten"): {"rename": "tenten"},
    ("naruto", "shikamaru_ino_choji"): {"rename": "choji"},
    ("naruto", "zabuza_haku"): {"rename": "haku"},
    ("naruto", "orochimaru_kabuto_misumi_itachi"): {"rename": "kabuto"},
    ("pokemon", "absol"): {"rename": "pichu"},
    ("pokemon", "articuno_zapdos_moltres"): {"rename": "zapdos"},
    ("pokemon", "blissey"): {"rename": "girafarig"},
    ("pokemon", "dratini_dragonair_dragonite"): {"rename": "dragonite"},
}


def prep_franchise_customers() -> None:
    """Best front-facing standing frame per picked character from the
    supplied franchise customer sheets. Backgrounds vary (solid pastels, the
    DBZ two-tone green checker); key them out, collect stand-sized islands
    and keep the best front-facing frame."""
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
            img = _key_sheet(load_rgba(path))
            fix = CUSTOMER_FIXES.get((world, name), {})
            best = None
            if "box" in fix:
                best = img.crop(tuple(fix["box"]))
            else:
                best_s = 8.0
                for box in find_islands(img, min_area=80, merge_gap=1)[:260]:
                    w, h = box[2] - box[0], box[3] - box[1]
                    if not (14 <= w <= 52 and 20 <= h <= 66 and h >= w * 0.75):
                        continue
                    cand = img.crop(tuple(box))
                    s = front_score(cand)
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
            slug = fix.get("rename", name.replace("3rd_", "third_"))
            best.save(out / f"{slug}.png")
            done += 1
        print(f"  {world}: {done}/{len(names)} customers")


def _band_frames(img: Image.Image, rect: tuple, min_w: int = 14) -> list:
    """Frames from one animation row: split on empty columns; runs of frames
    that touch are split into equal parts based on the band's median width."""
    band = img.crop(rect)
    a = np.array(band)
    cols = (a[..., 3] > 10).any(axis=0)
    segs: list[tuple[int, int]] = []
    x, w = 0, band.width
    while x < w:
        while x < w and not cols[x]:
            x += 1
        if x >= w:
            break
        x0 = x
        while x < w and cols[x]:
            x += 1
        if x - x0 >= min_w:
            segs.append((x0, x))
    if not segs:
        return []
    widths = sorted(x1 - x0 for x0, x1 in segs)
    median = widths[len(widths) // 2]
    frames: list = []
    for x0, x1 in segs:
        n = max(1, round((x1 - x0) / median))
        step = (x1 - x0) / n
        for i in range(n):
            sub = band.crop((int(x0 + i * step), 0, int(x0 + (i + 1) * step), band.height))
            # band rects can bleed slivers of neighboring rows; drop the
            # specks but keep detached keyblade pieces in attack frames
            sub = clean_alpha(keep_components(sub, 40), lo=1, hi=255)
            if sub.width > 2 and sub.height > 2:
                frames.append(sub)
    return frames


def _compose_anims(anims: dict, cell: tuple, out_png, out_manifest, sheet_res_path: str,
                   fps: dict | None = None, loops: dict | None = None) -> None:
    """compose_grid for pre-cut PIL frames instead of island indices."""
    import json as _json
    fps = fps or {}
    loops = loops or {}
    total = sum(len(v) for v in anims.values())
    cols = max(1, min(8, total))
    rows = (total + cols - 1) // cols
    cw, ch = cell
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    manifest_anims: dict = {}
    idx = 0
    for anim, frames in anims.items():
        indices = []
        for fr in frames:
            if fr.width > cw or fr.height > ch:
                r = min(cw / fr.width, ch / fr.height)
                fr = fr.resize((max(1, int(fr.width * r)), max(1, int(fr.height * r))), Image.NEAREST)
            cx = (idx % cols) * cw + (cw - fr.width) // 2
            cy = (idx // cols) * ch + (ch - fr.height) - 2
            sheet.alpha_composite(fr, (cx, cy))
            indices.append(idx)
            idx += 1
        manifest_anims[anim] = {
            "frames": indices,
            "fps": fps.get(anim, 9 if anim.startswith("walk") else 3),
            "loop": loops.get(anim, not anim.startswith("attack")),
        }
    Path(out_png).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_png)
    manifest = {
        "asset_id": Path(out_png).stem, "sheet": sheet_res_path,
        "native_scale": 1, "display_scale": 1, "pivot": [cw // 2, ch - 4],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": cols, "rows": rows},
        "animations": manifest_anims,
    }
    Path(out_manifest).parent.mkdir(parents=True, exist_ok=True)
    Path(out_manifest).write_text(_json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  wrote {out_png} ({total} frames) + manifest")


def prep_sora_field() -> None:
    """Full 8-direction walk cycles + 3-hit attack combo from the supplied
    KH1 Sora compilation (ripped by Nemu). Rows face LEFT on the sheet; we
    store right-facing frames (CharacterVisual flips for left)."""
    img = chroma_key(load_rgba(KH / "raw/heroes/sora.png"), (255, 255, 255), tol=6)

    def flip_all(frames: list) -> list:
        return [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]

    walk_down = _band_frames(img, (0, 148, 350, 210))
    walk_up = _band_frames(img, (0, 300, 350, 364))
    walk_down_side = flip_all(_band_frames(img, (0, 52, 350, 105)))
    walk_up_side = flip_all(_band_frames(img, (0, 408, 350, 466)))
    walk_side = flip_all(_band_frames(img, (0, 575, 400, 630)))
    swing1 = flip_all(_band_frames(img, (0, 1750, 460, 1815)))
    swing2 = flip_all(_band_frames(img, (0, 1905, 560, 1955)))
    swing3 = flip_all(_band_frames(img, (0, 1985, 560, 2045)))

    def pick(frames: list, idxs: list) -> list:
        return [frames[i] for i in idxs if i < len(frames)]

    anims = {
        "idle_down": [walk_down[0]],
        "walk_down": walk_down,
        "idle_up": [walk_up[0]],
        "walk_up": walk_up,
        "idle_side": [walk_side[0]],
        "walk_side": walk_side,
        "idle_down_side": [walk_down_side[0]],
        "walk_down_side": walk_down_side,
        "idle_up_side": [walk_up_side[0]],
        "walk_up_side": walk_up_side,
        "attack_1": pick(swing1, [1, 3, 5]),
        "attack_2": pick(swing2, [1, 3, 5]),
        "attack_3": pick(swing3, [1, 3, 5]),
    }
    for k, v in anims.items():
        if not v:
            print(f"  WARNING: {k} empty")
    _compose_anims(anims, (64, 60),
                   KH / "processed/sheets/sora.png", KH / "manifests/sora.json",
                   "res://assets/franchises/kingdom_hearts/processed/sheets/sora.png",
                   fps={"walk_down": 10, "walk_up": 10, "walk_side": 10,
                        "walk_down_side": 10, "walk_up_side": 10,
                        "attack_1": 14, "attack_2": 14, "attack_3": 14})


## Item icons from the supplied items.png rips. Indices/anchors were read
## off tools/item_sheet.py contact sheets (identical detection params, so
## the numbering is deterministic). by_box crops straight from the raw
## sheet and keys the crop's own corner color (for the differently-colored
## border strips these sheets carry).
WORLD_ITEM_PICKS = {
    "pokemon": {
        "params": dict(min_area=24, merge_gap=1, lo=6, hi=40),
        "by_index": {
            14: "poke_ball", 11: "great_ball", 8: "ultra_ball", 5: "master_ball",
            36: "pkmn_potion", 43: "full_restore", 54: "escape_rope",
            56: "water_stone", 38: "thunder_stone", 99: "moon_stone",
            102: "focus_band", 149: "bicycle_voucher",
            39: "super_potion", 40: "hyper_potion", 42: "pkmn_ether",
            41: "lava_cookie", 55: "leaf_stone", 57: "tiny_mushroom",
            58: "big_mushroom", 60: "pecha_berry", 66: "cheri_berry",
            68: "oran_berry", 91: "sitrus_berry", 67: "star_piece",
            21: "red_shard", 23: "blue_shard", 27: "yellow_shard",
            30: "green_shard", 112: "nugget", 120: "twisted_spoon",
            103: "black_glasses", 87: "root_fossil", 104: "red_orb",
            105: "blue_orb", 121: "technical_machine", 145: "leftovers",
            167: "amulet_coin", 165: "shell_bell", 24: "soda_pop", 26: "lemonade",
        },
    },
    "dragon_ball": {
        "params": dict(min_area=20, merge_gap=0, lo=5, hi=30),
        "by_anchor": {
            (93, 72): "dragon_ball", (31, 71): "capsule", (129, 52): "sacred_water",
            (345, 35): "turtle_gi", (327, 34): "weighted_clothing",
            (309, 69): "saiyan_armor", (194, 52): "energy_crystal",
            (307, 199): "scouter", (30, 34): "hearty_ramen",
            (62, 36): "dino_drumstick", (75, 34): "mega_burger",
            (142, 33): "marbled_beef", (30, 52): "fresh_milk",
            (63, 53): "chilled_soda", (153, 188): "zeni_coin",
            (124, 90): "ancient_idol",
        },
        "by_box": {"giant_river_fish": (168, 28, 210, 53)},
    },
    "mario": {
        "path": "assets/franchises/mario/items.png",  # supplied at franchise root
        "params": dict(min_area=60, merge_gap=1, lo=12, hi=34),
        "by_anchor": {
            (53, 8): "ultra_mushroom", (77, 9): "refreshing_herb",
            (101, 8): "red_pepper", (119, 8): "green_pepper",
            (138, 8): "blue_pepper", (6, 40): "koopa_shell",
            (36, 40): "red_koopa_shell", (97, 35): "ice_flower",
            (129, 34): "smash_egg", (240, 33): "copy_flower",
            (273, 36): "mix_flower",
        },
    },
    "naruto": {
        "params": dict(min_area=24, merge_gap=1, lo=6, hi=40),
        "by_index": {
            21: "kunai", 27: "shuriken", 36: "fuma_shuriken",
            56: "soldier_pill", 57: "chakra_pill", 63: "ramen_bowl",
            62: "smoke_bomb", 7: "field_medkit", 10: "makibishi_spikes",
            12: "ichiraku_ticket",
        },
        "by_box": {
            "gama_wallet": (2, 986, 34, 1033),
            "dango_skewer": (103, 986, 135, 1032),
            "forehead_protector": (305, 992, 333, 1028),
            "explosive_tag": (550, 986, 588, 1033),
            "ryo_pouch": (744, 986, 780, 1033),
            "substitution_log": (600, 138, 655, 196),
        },
    },
}


def _fit_icon(im: Image.Image, max_px: int = 22) -> Image.Image:
    if im.width <= max_px and im.height <= max_px:
        return im
    k = max_px / max(im.width, im.height)
    return resize_rgba(im, (max(1, round(im.width * k)), max(1, round(im.height * k))))


def prep_world_items() -> None:
    for world, cfg in WORLD_ITEM_PICKS.items():
        raw = load_rgba(ROOT / cfg.get("path", f"assets/franchises/{world}/raw/items.png"))
        img = _key_sheet(raw.copy())
        p = cfg["params"]
        boxes = [b for b in find_islands(img, min_area=p["min_area"], merge_gap=p["merge_gap"])
                 if p["lo"] <= b[2] - b[0] <= p["hi"] and p["lo"] <= b[3] - b[1] <= p["hi"]]
        out = ROOT / f"assets/franchises/{world}/processed/items"
        out.mkdir(parents=True, exist_ok=True)
        done = 0
        for idx, iid in cfg.get("by_index", {}).items():
            if idx >= len(boxes):
                print(f"  {world}/{iid}: index {idx} out of range ({len(boxes)})")
                continue
            _fit_icon(clean_alpha(img.crop(tuple(boxes[idx])), lo=1, hi=255)).save(out / f"{iid}.png")
            done += 1
        for anchor, iid in cfg.get("by_anchor", {}).items():
            hit = None
            for b in boxes:
                if abs(b[0] - anchor[0]) <= 3 and abs(b[1] - anchor[1]) <= 3:
                    hit = b
                    break
            if hit is None:
                print(f"  {world}/{iid}: no island at {anchor}")
                continue
            _fit_icon(clean_alpha(img.crop(tuple(hit)), lo=1, hi=255)).save(out / f"{iid}.png")
            done += 1
        for iid, box in cfg.get("by_box", {}).items():
            # key the crop independently (the border strips use different
            # background colors) and keep only the item itself — grid-line
            # slivers survive the keying at crop edges
            crop = largest_component(_key_sheet(raw.crop(box)))
            _fit_icon(clean_alpha(crop, lo=1, hi=255)).save(out / f"{iid}.png")
            done += 1
        print(f"  {world}: {done} item icons")


## Decor furniture from assets/items/furniture: pure-appeal pieces with no
## display slots, sold in the shop's Decorate catalog. Indices refer to the
## tools/out/decor_<sheet>.png contact sheets (min_area=100, merge_gap=1,
## sizes 10..100). (id, name, price, appeal_modifiers)
DECOR_PICKS = {
    "Interior_objects": {
        17: ("oak_bookshelf", "Oak Bookshelf", 350, {"cozy": 1, "retro": 1}),
        22: ("weapon_display", "Weapon Display", 600, {"intense": 2}),
        25: ("woven_rug", "Woven Rug", 250, {"cozy": 2}),
        42: ("guild_banner", "Guild Banner", 400, {"intense": 1}),
        12: ("dragon_skull", "Dragon Skull", 900, {"intense": 2}),
        48: ("potted_orchid", "Potted Orchid", 200, {"cozy": 1}),
        49: ("gilded_chest", "Gilded Chest", 500, {"retro": 1}),
        46: ("scholars_desk", "Scholar's Desk", 450, {"modern": 1}),
        39: ("reading_bench", "Reading Bench", 300, {"cozy": 1}),
    },
    "cozyInterior_objects": {
        1: ("plant_cabinet", "Plant Cabinet", 420, {"cozy": 2}),
        8: ("potion_shelf", "Potion Shelf", 380, {"retro": 1}),
        16: ("jungle_planter", "Jungle Planter", 350, {"cozy": 2}),
        19: ("dragon_painting", "Dragon Painting", 700, {"retro": 2}),
        47: ("flower_vases", "Flower Vases", 180, {"cozy": 1}),
        26: ("mine_cart", "Mine Cart", 550, {"modern": 1}),
    },
    "supplies_objects": {
        6: ("stocked_shelf", "Stocked Shelf", 320, {"modern": 1}),
        25: ("produce_barrels", "Produce Barrels", 280, {"cozy": 1}),
        58: ("arms_rack", "Arms Rack", 650, {"intense": 2}),
        69: ("kite_shield", "Kite Shield", 300, {"intense": 1}),
    },
    "Other_objects": {
        6: ("dragon_trophy", "Dragon Trophy", 1500, {"intense": 3}),
        9: ("ale_barrel", "Ale Barrel", 220, {"cozy": 1}),
        13: ("knight_bust", "Knight Bust", 480, {"intense": 1}),
        14: ("war_banner_red", "War Banner (Red)", 350, {"intense": 1}),
        15: ("war_banner_blue", "War Banner (Blue)", 350, {"intense": 1}),
    },
    "Cave_objects_source": {
        7: ("crystal_cluster", "Crystal Cluster", 800, {"retro": 2}),
        11: ("azure_crystals", "Azure Crystals", 450, {"retro": 1}),
        21: ("stone_idol", "Stone Idol", 950, {"retro": 2}),
        67: ("fossil_skull", "Fossil Skull", 700, {"retro": 1, "intense": 1}),
    },
}
DECOR_PARAMS = dict(min_area=100, merge_gap=1, lo=10, hi=100)


def prep_shop_decor() -> None:
    """Slice the decor picks, write their sprites, and register them as
    zero-slot decor furniture (defs + prices). Idempotent."""
    import json as _json

    out = ROOT / "assets/shared/furniture/decor"
    out.mkdir(parents=True, exist_ok=True)
    written: list[tuple[str, str, int, dict, tuple]] = []
    for sheet, picks in DECOR_PICKS.items():
        img = load_rgba(ROOT / f"assets/items/furniture/{sheet}.png")
        p = DECOR_PARAMS
        boxes = [b for b in find_islands(img, min_area=p["min_area"], merge_gap=p["merge_gap"])
                 if p["lo"] <= b[2] - b[0] <= p["hi"] and p["lo"] <= b[3] - b[1] <= p["hi"]]
        for idx, (did, name, price, appeal) in picks.items():
            if idx >= len(boxes):
                print(f"  decor/{did}: index {idx} out of range ({len(boxes)})")
                continue
            im = clean_alpha(img.crop(tuple(boxes[idx])), lo=1, hi=255)
            if im.height > 64:
                k = 64.0 / im.height
                im = resize_rgba(im, (max(1, round(im.width * k)), 64))
            im.save(out / f"{did}.png")
            written.append((did, name, price, appeal, (im.width, im.height)))
    # a couple of the supplied plants round out the cozy corner (they're
    # small trees at native size — cap them like the sheet picks)
    for n, (did, name, price) in {1: ("garden_bush", "Shade Tree", 260),
                                  6: ("berry_bush", "Bloom Tree", 320)}.items():
        src = ROOT / f"assets/items/furniture/plants/Bushes{n}/Bush{n}_1.png"
        if src.exists():
            im = clean_alpha(load_rgba(src), lo=1, hi=255)
            if im.height > 64:
                k = 64.0 / im.height
                im = resize_rgba(im, (max(1, round(im.width * k)), 64))
            im.save(out / f"{did}.png")
            written.append((did, name, price, {"cozy": 2}, (im.width, im.height)))

    FLAT = {"woven_rug"}  # lies on the floor, drawn under everyone
    doc = _json.loads((ROOT / "data/shop_furniture.json").read_text(encoding="utf-8"))
    by_id = {f["id"]: f for f in doc["furniture"]}
    for did, name, price, appeal, (w, h) in written:
        by_id[did] = {
            "id": did, "name": name, "decor": True, "flat": did in FLAT,
            "furniture_type": "decor",
            "display_slots": [], "allowed_categories": [],
            "appeal_modifiers": {k: float(v) for k, v in appeal.items()},
            "blocks_movement": False, "customer_attention_modifier": 0.0,
            "is_moveable": True, "price_modifier": 1.0, "scenery": "",
            "size": [float(max(16, w)), float(max(12, min(28, round(h * 0.45))))],
            "sprite": f"res://assets/shared/furniture/decor/{did}.png",
            "unlock_level": 1,
        }
    doc["furniture"] = sorted(by_id.values(), key=lambda f: f["id"])
    (ROOT / "data/shop_furniture.json").write_text(_json.dumps(doc, indent=1, sort_keys=True) + "\n", encoding="utf-8")

    bal = _json.loads((ROOT / "data/balance.json").read_text(encoding="utf-8"))
    for did, _name, price, _appeal, _sz in written:
        bal["furniture_prices"][did] = price
    (ROOT / "data/balance.json").write_text(_json.dumps(bal, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"  decor: {len(written)} pieces written + registered")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "decor":
        print("shop decor..."); prep_shop_decor()
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "customers":
        # regenerate from scratch so renamed slugs leave no stale files
        for old in (ROOT / "assets/franchises").glob("*/processed/customers/*.png"):
            old.unlink()
        print("ff customers..."); prep_ff_customers()
        print("franchise customers..."); prep_franchise_customers()
        print("extra crops..."); prep_extra_customer_crops()
        print("walk anims..."); prep_customer_walk_anims()
        print("auto walk anims..."); prep_auto_walk_anims()
        write_customer_pool()
        print("done")
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "items":
        print("world items..."); prep_world_items()
        print("done")
        sys.exit(0)
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
    print("sora field..."); prep_sora_field()
    print("done")
