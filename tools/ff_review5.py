"""Round 5: corner-color-only keying for the FF6 monster rips (the shared
_key_sheet also keys any >12% color, which eats these sprites' bodies).
Preview = biggest-box island of each candidate after gentle merge."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import chroma_key, clean_alpha, find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent
FF = ROOT / "assets/franchises/final_fantasy"
OUT = ROOT / "tools/out"


def key_corner(img: Image.Image, tol: int = 10) -> Image.Image:
    c = img.getpixel((0, 0))
    if len(c) == 4 and c[3] == 0:
        return img  # already transparent bg
    img = chroma_key(img, (c[0], c[1], c[2]), tol=tol)
    img = chroma_key(img, (255, 0, 255), tol=40)  # magenta border strips
    return img


CANDS = [
    "ff_ghost", "ff_giant_rat", "ff_guard_hound", "ff_magitek_armor",
    "ff_malboro", "ff_ahriman_iii", "ff_imperial_shadow",
    "ff_soldier_3rd_class", "ff_master_tonberry",
    "ff_flan_master_black_flan_white_mousse", "ff_sand_worm", "ff_behemoth",
    "ff_red_dragon_vi", "ff_kaiser_dragon", "ff_goddess",
]


def biggest_box(img: Image.Image):
    boxes = find_islands(img, min_area=200, merge_gap=3)
    if not boxes:
        return None
    return max(boxes, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))


def main() -> None:
    cell_w, cell_h = 170, 190
    sheet = Image.new("RGBA", (cell_w * 5, cell_h * ((len(CANDS) + 4) // 5)), (40, 40, 52, 255))
    d = ImageDraw.Draw(sheet)
    for i, name in enumerate(CANDS):
        img = key_corner(load_rgba(FF / f"raw/{name}.png"))
        b = biggest_box(img)
        if b is None:
            d.text(((i % 5) * cell_w + 4, (i // 5) * cell_h + 4), f"{name} EMPTY", fill=(255, 80, 80, 255))
            continue
        fr = clean_alpha(img.crop(tuple(b)), lo=1, hi=255)
        k = min(1.5, (cell_w - 10) / fr.width, (cell_h - 24) / fr.height)
        if k != 1:
            fr = fr.resize((max(1, int(fr.width * k)), max(1, int(fr.height * k))), Image.NEAREST)
        cx = (i % 5) * cell_w + (cell_w - fr.width) // 2
        cy = (i // 5) * cell_h + (cell_h - 20 - fr.height)
        sheet.alpha_composite(fr, (cx, cy))
        d.text(((i % 5) * cell_w + 4, (i // 5) * cell_h + cell_h - 16),
               f"{name.replace('ff_', '')} {b[2]-b[0]}x{b[3]-b[1]} @{b[0]},{b[1]}",
               fill=(255, 255, 150, 255))
    sheet.save(OUT / "ff_enemy_preview2.png")
    print("ff_enemy_preview2.png")


if __name__ == "__main__":
    main()
