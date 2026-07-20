"""Jump Ultimate Stars (DS) crossover cast -> shop customer statics.

One rip per character, each on a flat background (sometimes with a differently
coloured border frame, so the corner colour AND the dominant colour are both
keyed). The idle/stand pose lives near the top of a JUS rip, but so do HP
bars, "STAND"/"Block" labels, ripper credits and manga panels — so islands are
scored for character-likeness (portrait aspect, mid size, many colours)
instead of just taking the topmost, and `largest_component` drops any label
text that shares a bounding box with the sprite.

A few sheets lead with a big portrait panel or a title letter; those are listed
in DEEP_SEARCH and searched further down the sheet, taking the most colourful
candidate rather than the first.

The customer pool is world-agnostic at runtime (ContentDatabase.customer_pool_entry
hashes over the whole pool), so these walk into the shop in every world.

Run: .venv312/Scripts/python tools/prep_anime_customers.py
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import (chroma_key, clean_alpha, find_islands, largest_component,
                       load_rgba, resize_rgba)

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / "assets/franchises/anime"
RES = "res://assets/franchises/anime"
STRIP = 700          # normal search window from the top of the sheet
DEEP = (0, 1600)     # sheets that open with a title letter or portrait panel
CAP = 38

## sheets whose idle pose sits further down, past a title/portrait/HP-bar block
DEEP_SEARCH = {"Chopper", "Frieza", "L", "Renji", "Kon", "NicoRobin",
               "DonPatch", "SetoKaiba"}

## file stem -> shop display name
NAMES = {
    "Bobobo": "Bobobo", "Byakuya": "Byakuya", "Chopper": "Chopper",
    "DioBrando": "Dio Brando", "DonPatch": "Don Patch", "EveJUS": "Eve",
    "Frieza": "Frieza", "GiornoGiovanna": "Giorno", "Gon": "Gon",
    "Gotenks": "Gotenks", "Hiei": "Hiei", "Ichigo": "Ichigo",
    "JonathanJoestar": "Jonathan Joestar", "JosephJoestar": "Joseph Joestar",
    "JosukeHigashikata": "Josuke", "JotaroKujo": "Jotaro", "JUS_Allen": "Allen Walker",
    "KenshinJUS": "Kenshin", "Killua": "Killua", "Kon": "Kon",
    "Kuwabara": "Kuwabara", "L": "L", "Light": "Light", "Luffy": "Luffy",
    "Mello": "Mello", "MisaAmane": "Misa Amane", "Nami": "Nami",
    "NicoRobin": "Nico Robin", "Orihime": "Orihime", "Renji": "Renji",
    "RukiaKuchiki": "Rukia", "Sanji": "Sanji", "Sasuke": "Sasuke (JUS)",
    "SetoKaiba": "Seto Kaiba", "Sogeking": "Sogeking", "Yoh": "Yoh",
    "Yugi": "Yugi", "Yusuke": "Yusuke", "Zoro": "Zoro",
}


def slug_for(stem: str) -> str:
    return "jus_" + stem.lower().replace("jus_", "").replace("jus", "").strip("_")


def _score(s: Image.Image) -> int | None:
    """A standing fighter, told apart from the junk that shares the top of a
    JUS rip by three cheap tests:
      fill ratio  - a portrait/manga panel is a ~solid rectangle, a sprite is not
      chroma      - a big white title letter ("F", "N") is achromatic
      colour count- HP bars and label text use only a handful of colours
    """
    w, h = s.size
    if not (26 <= h <= 100 and 12 <= w <= 70):
        return None
    if not (0.28 <= w / h <= 1.20):
        return None
    a = np.array(s)
    mask = a[..., 3] > 40
    if mask.sum() < 120 or float(mask.mean()) > 0.82:
        return None
    rgb = a[..., :3][mask].astype(int)
    # title letters are pure white/grey (chroma ~0); keep the bar low enough
    # that near-monochrome characters (Allen's white hair, Josuke's black suit)
    # still qualify
    if (rgb.max(axis=1) - rgb.min(axis=1)).mean() < 12:
        return None
    cols = {tuple(c) for c in rgb}
    return len(cols) if len(cols) >= 9 else None


def pick(path: Path) -> Image.Image | None:
    full = load_rgba(path)
    deep = path.stem in DEEP_SEARCH
    y0, y1 = DEEP if deep else (0, STRIP)
    img = full.crop((0, min(y0, full.height), full.width, min(y1, full.height)))
    corner = full.getpixel((0, 0))[:3]
    dom = Counter(img.convert("RGBA").getdata()).most_common(1)[0][0][:3]
    k = chroma_key(img, corner, tol=12)
    if dom != corner:
        k = chroma_key(k, dom, tol=12)
    cands = []
    for b in find_islands(k, min_area=300, merge_gap=2):
        s = clean_alpha(largest_component(k.crop(b)), lo=1, hi=255)
        if _score(s):
            cands.append((b[1], b[0], s))
    if not cands:
        return None
    # with the junk filtered out, reading order lands on the idle pose
    cands.sort(key=lambda t: (t[0], t[1]))
    return cands[0][2]


def main() -> None:
    out = A / "processed/customers"
    out.mkdir(parents=True, exist_ok=True)
    made: dict[str, str] = {}
    for p in sorted(A.glob("raw/*")):
        if p.suffix.lower() not in (".png", ".gif") or p.stem not in NAMES:
            continue
        s = pick(p)
        if s is None:
            print(f"  !! {p.stem}: no character island found")
            continue
        if s.height > CAP:
            k = CAP / s.height
            s = clean_alpha(resize_rgba(s, (max(1, round(s.width * k)), CAP)), lo=96, hi=160)
        slug = slug_for(p.stem)
        s.save(out / f"{slug}.png")
        made[slug] = NAMES[p.stem]
        print(f"  {slug}: {s.size}  ({NAMES[p.stem]})")
    (A / "customers.json").write_text(json.dumps(made, indent=2), encoding="utf-8")
    print(f"done: {len(made)} customers")


if __name__ == "__main__":
    main()
