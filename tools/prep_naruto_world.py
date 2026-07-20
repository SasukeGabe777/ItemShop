"""Naruto (Path of the Ninja 2, DS) world prep: Naruto's animated hero sheet,
the enemy roster sliced off a palette-variant grid, the Sound Four + Kimimaro
bosses, Hidden Leaf Forest room backgrounds, obstacle props, and the item
icons that were still missing.

Source quirks this script handles (see docs/AGENT_GUIDE.md §4):

- `heroes/naruto_naruto.png` is pink-backed (248,104,184) with a 1px lavender
  border frame — the corner pixel samples the BORDER, so key both colors.
- `enemies/standard_enemies.png` is a grid where EVERY CELL HAS ITS OWN
  BACKGROUND COLOUR (palette-variant sheet). No single key works, so cells are
  auto-detected as large uniform-colour regions and each is keyed against its
  own background. Cell indices below were verified on tools/out contact sheets.
- The Konoha map is a set of DS screens on magenta; only two screens are wide
  enough for a 640x384 crop at 1:1, so rooms are cut at 320x192 and upscaled
  2x — which also lands each 16px map tile exactly on one 32px dungeon cell.
- Naruto's sheet is a fighting-game sheet: front poses plus RIGHT-facing
  attack poses, and no back views. up/* reuses the front frames and the attack
  anims are side-only, resolved by CharacterVisual's fallback chain.

Run: .venv312/Scripts/python tools/prep_naruto_world.py
"""
from __future__ import annotations

import json
import sys
from collections import Counter, deque
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import (chroma_key, clean_alpha, find_islands, flood_bg,
                       largest_component, load_rgba, resize_rgba)

ROOT = Path(__file__).resolve().parent.parent
N = ROOT / "assets/franchises/naruto"
RES = "res://assets/franchises/naruto"
LOC = ROOT / "assets/locations/narutodungeon/processed"
LOC_RES = "res://assets/locations/narutodungeon/processed"
KONOHA = N / "raw/locations/narutodungeon_konoha.png"


def key_colors(img: Image.Image, colors, tol: int = 12) -> Image.Image:
    for c in colors:
        img = chroma_key(img, c, tol=tol)
    return img


def write_manifest(uid: str, frames: list[Image.Image], anims: dict, cols: int | None = None) -> None:
    """Pack frames into a single-row (or `cols`-wide) sheet + manifest."""
    cw = max(f.width for f in frames)
    ch = max(f.height for f in frames)
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        x = (i % cols) * cw + (cw - f.width) // 2
        y = (i // cols) * ch + (ch - f.height)
        sheet.alpha_composite(f, (x, y))
    (N / "processed/sheets").mkdir(parents=True, exist_ok=True)
    sheet.save(N / f"processed/sheets/{uid}.png")
    manifest = {
        "asset_id": uid, "sheet": f"{RES}/processed/sheets/{uid}.png",
        "native_scale": 1, "display_scale": 1, "pivot": [cw // 2, ch - 1],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": cols, "rows": rows},
        "animations": anims,
    }
    (N / "manifests").mkdir(parents=True, exist_ok=True)
    (N / f"manifests/{uid}.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"  {uid}: {len(frames)} frame(s) {cw}x{ch}")


# --------------------------------------------------------------------------
# Hero: Naruto. Island indices verified on the 5x contact sheet.
NARUTO_PINK = (248, 104, 184)
NARUTO_BORDER = (170, 174, 210)
## sheet has no back views; up/* reuses the front frames. Attacks are
## right-facing only -> side-only anims, CharacterVisual falls back for up/down.
NARUTO_PICKS = {
    "idle_down": [0], "walk_down": [0, 1, 2],
    "idle_up": [0], "walk_up": [0, 1, 2],
    "idle_side": [3], "walk_side": [3, 4, 5],
    "attack_1_side": [15, 16, 17],   # punch -> chakra swirl -> follow-through
    "attack_2_side": [18, 19, 20],   # stance -> slash arc -> recovery
}


def _naruto_islands():
    img = key_colors(load_rgba(N / "raw/heroes/naruto_naruto.png"),
                     [NARUTO_PINK, NARUTO_BORDER])
    return img, find_islands(img, min_area=40, merge_gap=2)


def prep_hero() -> None:
    img, boxes = _naruto_islands()
    order: list[int] = []
    for picks in NARUTO_PICKS.values():
        for i in picks:
            if i not in order:
                order.append(i)
    frames = [clean_alpha(img.crop(boxes[i]), lo=1, hi=255) for i in order]
    anims = {}
    for name, picks in NARUTO_PICKS.items():
        fps = 9 if name.startswith("walk") else (12 if name.startswith("attack") else 3)
        anims[name] = {"frames": [order.index(i) for i in picks], "fps": fps,
                       "loop": not name.startswith("attack")}
    write_manifest("naruto", frames, anims, cols=8)
    portrait = clean_alpha(img.crop(boxes[0]), lo=1, hi=255)
    portrait.resize((portrait.width * 4, portrait.height * 4), Image.NEAREST).save(N / "processed/naruto.png")
    print(f"  naruto portrait {portrait.size} x4")


# --------------------------------------------------------------------------
# Enemies: auto-detected palette-variant cells.
def detect_cells(path: Path, min_area=900, lo=24, hi=140) -> list[tuple]:
    img = load_rgba(path)
    a = np.array(img); rgb = a[..., :3]
    h, w = rgb.shape[:2]
    sheet_area = h * w
    cands = [c for c, n in Counter(map(tuple, rgb.reshape(-1, 3)[::3])).most_common(60)
             if n * 3 > 1200]
    cells = []
    for col in cands:
        mask = np.all(rgb == np.array(col), axis=-1)
        visited = np.zeros((h, w), bool)
        for sy, sx in zip(*np.nonzero(mask)):
            if visited[sy, sx]:
                continue
            dq = deque([(sy, sx)]); visited[sy, sx] = True
            minx = maxx = sx; miny = maxy = sy; area = 0
            while dq:
                y, x = dq.popleft(); area += 1
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
                for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = True; dq.append((ny, nx))
            bw, bh = maxx-minx+1, maxy-miny+1
            if area > min_area and lo < bw < hi and lo < bh < hi and bw*bh < sheet_area*0.05:
                cells.append((int(minx), int(miny), int(maxx+1), int(maxy+1),
                              tuple(int(v) for v in col)))

    def overlaps(a_, b_):
        return not (a_[2] <= b_[0] or b_[2] <= a_[0] or a_[3] <= b_[1] or b_[3] <= a_[1])
    kept: list[tuple] = []
    for c in sorted(cells, key=lambda c: -((c[2]-c[0])*(c[3]-c[1]))):
        if not any(overlaps(c, k) for k in kept):
            kept.append(c)
    kept.sort(key=lambda c: (c[1], c[0]))
    return kept


## cell index -> enemy id, verified on the 86-cell contact sheet
NARUTO_ENEMIES = {
    "giant_snake": 0,       "forest_spider": 3,   "nin_panther": 5,
    "hawk_scout": 12,       "cave_scorpion": 18,  "rogue_ninja": 21,
    "mist_swordsman": 32,   "kunoichi_blade": 38, "puppet": 43,
    "bandit_brute": 45,     "clone_impostor": 51, "sound_ninja": 53,
}
ENEMY_CAP = 40


def prep_enemies() -> None:
    cells = detect_cells(N / "raw/enemies/standard_enemies.png")
    print(f"  detected {len(cells)} enemy cells")
    img = load_rgba(N / "raw/enemies/standard_enemies.png")
    for uid, idx in NARUTO_ENEMIES.items():
        x0, y0, x1, y1, bg = cells[idx]
        s = clean_alpha(chroma_key(img.crop((x0, y0, x1, y1)), bg, tol=10), lo=1, hi=255)
        s = clean_alpha(largest_component(s), lo=1, hi=255)
        if s.height > ENEMY_CAP:
            k = ENEMY_CAP / s.height
            s = clean_alpha(resize_rgba(s, (max(1, round(s.width*k)), ENEMY_CAP)), lo=96, hi=160)
        anims = {}
        for nm in ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side"]:
            anims[nm] = {"frames": [0], "fps": 3, "loop": True}
        write_manifest(uid, [s], anims)


# --------------------------------------------------------------------------
# Bosses: Sound Four + Kimimaro (bosses.png, flat corner background) and
# Zabuza, whose art lives on the customer sheet (he is the chapter-5 story
# boss and later a shop regular, so he must stay a boss).
NARUTO_BOSSES = {"jirobou": 0, "tayuya": 1, "kidomaru": 11, "kimimaro": 12}
BOSS_CAP = 96
## Jirobou and Tayuya fight as elite rank-and-file in ordinary rooms, so they
## are cut smaller — at boss scale they towered over the tank enemies and read
## as bosses that had wandered into the wrong room.
ELITE_CAP = 62
ELITES = {"jirobou", "tayuya"}


def _fit(s: Image.Image, cap: int) -> Image.Image:
    s = clean_alpha(largest_component(s), lo=1, hi=255)
    if s.height != cap:
        k = cap / s.height
        s = resize_rgba(s, (max(1, round(s.width * k)), cap))
        s = clean_alpha(s, lo=96, hi=160)
    return s


def prep_bosses() -> None:
    img = load_rgba(N / "raw/enemies/bosses.png")
    keyed = chroma_key(img, (55, 63, 63), tol=14)
    boxes = find_islands(keyed, min_area=60, merge_gap=2)
    for uid, idx in NARUTO_BOSSES.items():
        s = _fit(keyed.crop(boxes[idx]), ELITE_CAP if uid in ELITES else BOSS_CAP)
        anims = {n: {"frames": [0], "fps": 3, "loop": True}
                 for n in ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side"]}
        write_manifest(uid, [s], anims)
    # Zabuza: reuse the verified customer static, scaled to boss presence
    z = load_rgba(N / "processed/customers/zabuza.png")
    anims = {n: {"frames": [0], "fps": 3, "loop": True}
             for n in ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side"]}
    write_manifest("zabuza", [_fit(z, BOSS_CAP)], anims)


# --------------------------------------------------------------------------
# Rooms: 320x192 windows upscaled 2x. All verified 0% magenta void.
N_ROOMS = {
    "start_gate": (565, 1769),
    "combat_forest": (553, 55),
    "combat_grove": (60, 1080),
    "combat_cliffs": (3, 522),
    "treasure_cave": (1500, 40),
    "boss_ravine": (600, 1060),
}


def prep_rooms() -> None:
    img = load_rgba(KONOHA).convert("RGB")
    LOC.mkdir(parents=True, exist_ok=True)
    for name, (x, y) in N_ROOMS.items():
        c = img.crop((x, y, x + 320, y + 192))
        c.resize((640, 384), Image.NEAREST).save(LOC / f"{name}.png")
        print(f"  room {name}: (({x},{y}) 320x192) -> 640x384")


# --------------------------------------------------------------------------
# Obstacle props: objects lifted off the map by flooding the ground colours
# sampled from each crop's border ring (indexed art, so exact match is safe).
## Discrete objects only. A crop of the log-palisade *texture* was tried here
## and tiled into featureless slabs that swallowed the combat rooms — the same
## failure the prop system replaced (AGENT_GUIDE §7).
N_PROPS = {
    "prop_post": (1210, 755, 1230, 805),
    "prop_rock": (1246, 900, 1290, 945),
    "prop_stump": (1381, 722, 1405, 747),
}
PROP_CAP = 36


def _ring_flood(img: Image.Image, box, pad=6, top_n=16) -> Image.Image:
    x0, y0, x1, y1 = box
    c = img.crop((x0-pad, y0-pad, x1+pad, y1+pad)).convert("RGBA")
    rgb = np.array(c)[..., :3]
    ring = np.concatenate([rgb[:2].reshape(-1, 3), rgb[-2:].reshape(-1, 3),
                           rgb[:, :2].reshape(-1, 3), rgb[:, -2:].reshape(-1, 3)])
    cols = set(c0 for c0, _ in Counter(map(tuple, ring)).most_common(top_n))

    def is_bg(px):
        m = np.zeros(px.shape[:2], bool)
        for col in cols:
            m |= np.all(px == np.array(col), axis=-1)
        return m
    return flood_bg(c, is_bg)


def prep_props() -> None:
    img = load_rgba(KONOHA)
    LOC.mkdir(parents=True, exist_ok=True)
    for name, box in N_PROPS.items():
        s = clean_alpha(largest_component(_ring_flood(img, box)), lo=1, hi=255)
        if max(s.size) > PROP_CAP:
            k = PROP_CAP / max(s.size)
            s = clean_alpha(resize_rgba(s, (max(1, round(s.width*k)), max(1, round(s.height*k)))),
                            lo=96, hi=160)
        s.save(LOC / f"{name}.png")
        print(f"  {name}: {s.size}")


# --------------------------------------------------------------------------
# Items: only the icons that were still missing. Island indices verified on
# the 106-icon contact sheet.
N_ITEMS_MISSING = {
    "ninja_scroll": 94, "summoning_scroll": 96, "sannin_token": 83,
    "chakra_crystal": 71, "sharingan_fragment": 89, "training_weights": 93,
}
ITEM_CAP = 22


def prep_items() -> None:
    img = load_rgba(N / "raw/items.png")
    keyed = img
    for col in [(88, 136, 104), (0, 248, 248), (0, 208, 0), (0, 255, 255)]:
        keyed = chroma_key(keyed, col, tol=16)
    boxes = find_islands(keyed, min_area=12, merge_gap=1)
    out = N / "processed/items"
    out.mkdir(parents=True, exist_ok=True)
    for iid, idx in N_ITEMS_MISSING.items():
        s = clean_alpha(keyed.crop(boxes[idx]), lo=1, hi=255)
        if max(s.size) > ITEM_CAP:
            k = ITEM_CAP / max(s.size)
            s = clean_alpha(resize_rgba(s, (max(1, round(s.width*k)), max(1, round(s.height*k)))),
                            lo=96, hi=160)
        s.save(out / f"{iid}.png")
        print(f"  item {iid}: {s.size}")


# --------------------------------------------------------------------------
# Customers. The rip sheets stack several characters per file with a 1px
# (96,115,149) border frame over blue/green/magenta section backgrounds — the
# corner pixel samples the FRAME, so all four are keyed. Picks are
# (sheet, island index) under the island config in `_customer_islands`, all
# verified on tools/out contact sheets. Characters already present in
# processed/customers (kakashi, sakura, kiba, zabuza, haku, ...) are not
# re-cut here.
CUST_BGS = [(96, 115, 149), (128, 184, 248), (0, 248, 0), (255, 0, 255)]
CUST_PICKS = {
    "third_hokage": ("naruto_3rd_hokage_jiraiya", 0),
    "iruka": ("naruto_iruka_asuma_guy", 0),
    "asuma": ("naruto_iruka_asuma_guy", 6),
    "might_guy": ("naruto_iruka_asuma_guy", 9),
    "misumi": ("naruto_orochimaru_kabuto_misumi_itachi", 3),
    "itachi": ("naruto_orochimaru_kabuto_misumi_itachi", 15),
    "dosu": ("naruto_team_dosu", 0),
    "kin": ("naruto_team_dosu", 19),
    "zaku": ("naruto_team_dosu", 21),
    "shikamaru": ("naruto_shikamaru_ino_choji", 6),
    "ino": ("naruto_shikamaru_ino_choji", 9),
    "akamaru": ("naruto_kiba_akamaru_shino_hinata", 12),
    "shino": ("naruto_kiba_akamaru_shino_hinata", 18),
    "hinata": ("naruto_kiba_akamaru_shino_hinata", 33),
    "konohamaru": ("naruto_konohamaru_ebisu", 0),
    "neji": ("naruto_neji_lee_tenten", 0),
    "rock_lee": ("naruto_neji_lee_tenten", 10),
    "teuchi": ("naruto_teuchi_tazuna_mizuki", 0),
    "tazuna": ("naruto_teuchi_tazuna_mizuki", 8),
    "mizuki": ("naruto_teuchi_tazuna_mizuki", 17),
    "mist_ninja": ("naruto_hidden_mist_ninja", 0),
    "rain_ninja": ("naruto_hidden_rain_ninja", 0),
    "chunin_examiner": ("naruto_chunin_exam_examiners", 6),
}
CUST_CAP = 38


def _customer_islands(stem: str):
    img = load_rgba(N / f"raw/customers/{stem}.png")
    for c in CUST_BGS:
        img = chroma_key(img, c, tol=14)
    boxes = [b for b in find_islands(img, min_area=120, merge_gap=1)
             if 12 <= b[2]-b[0] <= 70 and 16 <= b[3]-b[1] <= 70]
    return img, boxes


def prep_customers() -> None:
    out = N / "processed/customers"
    out.mkdir(parents=True, exist_ok=True)
    cache: dict[str, tuple] = {}
    for slug, (stem, idx) in CUST_PICKS.items():
        if stem not in cache:
            cache[stem] = _customer_islands(stem)
        img, boxes = cache[stem]
        if idx >= len(boxes):
            print(f"  !! {slug}: island {idx} out of range ({len(boxes)})")
            continue
        s = clean_alpha(img.crop(boxes[idx]), lo=1, hi=255)
        if s.height > CUST_CAP:
            k = CUST_CAP / s.height
            s = clean_alpha(resize_rgba(s, (max(1, round(s.width*k)), CUST_CAP)), lo=96, hi=160)
        s.save(out / f"{slug}.png")
        print(f"  customer {slug}: {s.size}")


if __name__ == "__main__":
    print("hero:");     prep_hero()
    print("enemies:");  prep_enemies()
    print("bosses:");   prep_bosses()
    print("rooms:");    prep_rooms()
    print("props:");    prep_props()
    print("items:");    prep_items()
    print("customers:"); prep_customers()
    print("done")
