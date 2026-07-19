"""Zelda world review sheets: numbered contact sheets + gridded maps so
frames and crops can be picked visually. Outputs to tools/out/z_*.png"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import chroma_key, contact_sheet, find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent
Z = ROOT / "assets/franchises/zelda"
OUT = Path(__file__).parent / "out"
OUT.mkdir(exist_ok=True)


def key_corner(img: Image.Image, tol: int = 10) -> Image.Image:
    c = img.getpixel((0, 0))
    if len(c) == 4 and c[3] == 0:
        return img
    img = chroma_key(img, (c[0], c[1], c[2]), tol=tol)
    return chroma_key(img, (255, 0, 255), tol=40)


def load_any(path: Path) -> Image.Image:
    img = Image.open(path)
    img.seek(0)
    return img.convert("RGBA")


def review(path: Path, tag: str, scale: int = 2, min_area: int = 30, merge_gap: int = 2,
           crop: tuple[int, int, int, int] | None = None) -> None:
    img = key_corner(load_any(path))
    if crop:
        img = img.crop(crop)
    boxes = find_islands(img, min_area=min_area, merge_gap=merge_gap)
    contact_sheet(img, boxes, OUT / f"z_{tag}_cs.png", scale=scale)
    print(f"{tag}: {len(boxes)} islands, sheet {img.size}")


def gridded(path: Path, tag: str, step: int = 64, shrink: int = 1) -> None:
    img = Image.open(path).convert("RGB")
    d = ImageDraw.Draw(img)
    for x in range(0, img.width, step):
        d.line([(x, 0), (x, img.height)], fill=(255, 0, 0), width=1)
        d.text((x + 2, 2), str(x), fill=(255, 255, 0))
    for y in range(0, img.height, step):
        d.line([(0, y), (img.width, y)], fill=(255, 0, 0), width=1)
        d.text((2, y + 2), str(y), fill=(255, 255, 0))
    if shrink > 1:
        img = img.resize((img.width // shrink, img.height // shrink))
    img.save(OUT / f"z_{tag}_grid.png")
    print(f"{tag}: gridded {img.size}")


if __name__ == "__main__":
    H = Z / "raw/heroes"
    E = Z / "raw/enemies"
    C = Z / "raw/customers"
    L = Z / "raw/locations"
    # Link: the sheet is tall; review in bands so numbering stays readable
    review(H / "zelda_hero.png", "link_top", scale=2, crop=(0, 0, 1208, 400))
    review(H / "zelda_hero.png", "link_mid", scale=2, crop=(0, 1000, 1208, 1300))
    review(H / "Link_sword_animation.png", "sword", scale=3)
    review(H / "link_bomb_Explosion.png", "expl", scale=3)
    review(E / "boss_1.png", "boss1", scale=2)
    review(E / "boss_2.png", "boss2", scale=2)
    review(E / "boss_3.png", "boss3", scale=2)
    for name in ["keese", "octorok", "chuchu", "rope", "spear_moblin", "stalfos",
                 "darknut", "leever", "peahat", "ghini", "keaton", "like_like",
                 "spiked_beetle", "wisp", "moldorms", "sluggula", "tektike",
                 "acrobandits", "puffstool", "rollobite", "crow", "beetle", "pesto"]:
        for ext in (".png", ".gif"):
            p = E / f"sprite_{name}{ext}"
            if p.exists():
                review(p, f"e_{name}", scale=2)
                break
    for name in ["hyrule_town_residents_1", "hyrule_town_residents_2", "hyrule_town_residents_3",
                 "princess_zelda", "royal_guards", "king_daltus", "carpenters",
                 "blade_brothers", "deku_scrub", "din_nayru_farore_oracles", "cuccos"]:
        for ext in (".png", ".gif"):
            p = C / f"sprite_{name}{ext}"
            if p.exists():
                review(p, f"c_{name}", scale=2)
                break
    gridded(H / "link_bomb.png", "items", step=32)
    gridded(L / "Game Boy Advance - The Legend of Zelda_ The Minish Cap - Maps - Lon Lon Ranch (1).png", "lonlon", step=64)
    gridded(L / "Game Boy Advance - The Legend of Zelda_ The Minish Cap - Maps - Hyrule Castle Garden (1).png", "garden", step=64)
    print("done")
