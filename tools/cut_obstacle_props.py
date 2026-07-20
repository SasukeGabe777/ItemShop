"""Cut clean, transparent-backed obstacle prop sprites for the four worlds
that used map-crop wall textures (the "messy walls" playtest feedback).
Each world gets 2-4 unscaled object sprites that the dungeon places one per
32px cell instead of stretching a tile over the obstacle rect.

Sources:
- zelda: Lon Lon Ranch map objects sitting on plain grass (flood the greens)
- mario: Beanbean avenue trees against the sky (flood the blues)
- final_fantasy: Esperville tileset pines on pure black (chroma key)
- kingdom_hearts: the already-transparent crate pile + barrel, downscaled

Run: .venv312/Scripts/python tools/cut_obstacle_props.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import (chroma_key, clean_alpha, flood_bg, largest_component,
                       load_rgba, resize_rgba)

ROOT = Path(__file__).resolve().parent.parent
LOC = ROOT / "assets/locations"

LONLON = ROOT / ("assets/franchises/zelda/raw/locations/Game Boy Advance - The"
                 " Legend of Zelda_ The Minish Cap - Maps - Lon Lon Ranch (1).png")
BEANBEAN = LOC / ("mariodungeon/Game Boy Advance - Mario & Luigi_ Superstar"
                  " Saga - Maps - Beanbean Castle Town (Exterior).png")
ESPERVILLE = ROOT / ("assets/franchises/final_fantasy/raw/locations/Game Boy"
                     " Advance - Final Fantasy VI Advance - Maps - Esperville.png")

CAP_W, CAP_H = 36, 36


def save_prop(img: Image.Image, path: Path) -> None:
    img = clean_alpha(largest_component(img), lo=1, hi=255)
    if img.width > CAP_W or img.height > CAP_H:
        k = min(CAP_W / img.width, CAP_H / img.height)
        img = resize_rgba(img, (max(1, round(img.width * k)), max(1, round(img.height * k))))
        img = clean_alpha(img, lo=96, hi=160)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  {path.relative_to(ROOT)}: {img.size}")


def is_grass(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (g > r + 15) & (g > b + 50)


def is_sky(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (b > r + 30) & (b > 180) & (g > 150)


def cut_zelda() -> None:
    src = load_rgba(LONLON)
    for name, box in {
        "prop_boulder": (166, 812, 192, 830),
        "prop_rocks": (110, 805, 144, 828),
        "prop_haystack": (225, 516, 256, 553),
        "prop_stumps": (191, 767, 208, 786),
    }.items():
        save_prop(flood_bg(src.crop(box), is_grass), LOC / f"zeldadungeon/processed/{name}.png")


def cut_mario() -> None:
    src = load_rgba(BEANBEAN)
    # avenue tree crowns cut just above the hedgerow they sit on
    for name, box in {
        "prop_tree_a": (545, 413, 597, 458),
        "prop_tree_b": (599, 414, 652, 459),
    }.items():
        save_prop(flood_bg(src.crop(box), is_sky), LOC / f"mariodungeon/processed/{name}.png")


def cut_ff() -> None:
    src = load_rgba(ESPERVILLE)
    for name, box in {
        "prop_pine": (272, 2235, 290, 2303),
        "prop_pine_small": (256, 2252, 272, 2301),
    }.items():
        save_prop(chroma_key(src.crop(box), (0, 0, 0), tol=28), LOC / f"ffdungeon/processed/{name}.png")


def cut_kh() -> None:
    crates = load_rgba(LOC / "processed/crates.png")
    save_prop(crates, LOC / "processed/prop_crates.png")
    barrel = load_rgba(LOC / "processed/barrel.png")
    save_prop(barrel, LOC / "processed/prop_barrel.png")


if __name__ == "__main__":
    print("zelda props:")
    cut_zelda()
    print("mario props:")
    cut_mario()
    print("final_fantasy props:")
    cut_ff()
    print("kingdom_hearts props:")
    cut_kh()
    print("done")
