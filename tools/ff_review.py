"""Review renders for the Final Fantasy world pass: annotated island sheets
for Cloud + the weapons sheet, largest-island extraction previews for the
enemy/boss candidates, and downscaled maps with a crop grid.

Run: .venv312/Scripts/python tools/ff_review.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import _key_sheet
from slice_lib import clean_alpha, find_islands, largest_component, load_rgba

ROOT = Path(__file__).resolve().parent.parent
FF = ROOT / "assets/franchises/final_fantasy"
OUT = ROOT / "tools/out"
OUT.mkdir(parents=True, exist_ok=True)


def annotate(img: Image.Image, boxes: list, out_name: str, scale: int = 3) -> None:
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST).convert("RGBA")
    d = ImageDraw.Draw(big)
    for i, b in enumerate(boxes):
        x0, y0, x1, y1 = [v * scale for v in b]
        d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(255, 60, 60, 255))
        d.text((x0 + 1, max(0, y0 - 11)), str(i), fill=(255, 255, 80, 255))
    big.save(OUT / out_name)
    print(f"{out_name}: {len(boxes)} islands, {img.size}")


def main() -> None:
    # 1. Cloud sheet islands
    cloud = _key_sheet(load_rgba(FF / "raw/ff_cloud.png"))
    boxes = find_islands(cloud, min_area=40, merge_gap=0)
    annotate(cloud, boxes, "ff_cloud_islands.png", scale=3)

    # 2. Weapons sheet islands
    wp = _key_sheet(load_rgba(FF / "raw/items/Game Boy Advance - Final Fantasy VI Advance - Miscellaneous - Weapons (1).png"))
    wboxes = find_islands(wp, min_area=30, merge_gap=1)
    annotate(wp, wboxes, "ff_weapons_islands.png", scale=2)

    # 3. Enemy + boss extraction preview: largest island of each keyed sheet
    cands = [
        "ff_ghost", "ff_giant_rat", "ff_guard_hound", "ff_magitek_armor",
        "ff_malboro", "ff_ahriman_iii", "ff_imperial_shadow",
        "ff_soldier_3rd_class", "ff_master_tonberry",
        "ff_flan_master_black_flan_white_mousse", "ff_sand_worm", "ff_behemoth",
        "ff_red_dragon_vi", "ff_kaiser_dragon", "ff_goddess",
    ]
    cell_w, cell_h = 150, 170
    sheet = Image.new("RGBA", (cell_w * 5, cell_h * ((len(cands) + 4) // 5)), (40, 40, 52, 255))
    d = ImageDraw.Draw(sheet)
    for i, name in enumerate(cands):
        p = FF / f"raw/{name}.png"
        if not p.exists():
            d.text(((i % 5) * cell_w + 4, (i // 5) * cell_h + 4), f"{name} MISSING", fill=(255, 80, 80, 255))
            continue
        img = largest_component(_key_sheet(load_rgba(p)))
        img = clean_alpha(img, lo=1, hi=255)
        k = min(2.0, min((cell_w - 10) / img.width, (cell_h - 24) / img.height))
        if k < 1 or k >= 2:
            img = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.NEAREST)
        cx = (i % 5) * cell_w + (cell_w - img.width) // 2
        cy = (i // 5) * cell_h + (cell_h - 20 - img.height)
        sheet.alpha_composite(img, (cx, cy))
        d.text(((i % 5) * cell_w + 4, (i // 5) * cell_h + cell_h - 16),
               f"{name.replace('ff_', '')} {img.width}x{img.height}", fill=(255, 255, 150, 255))
    sheet.save(OUT / "ff_enemy_preview.png")
    print("ff_enemy_preview.png")

    # 4. Maps downscaled with a 128px source grid for picking room crops
    for name in ["Esperville", "Jidoor"]:
        p = FF / f"raw/locations/Game Boy Advance - Final Fantasy VI Advance - Maps - {name}.png"
        img = Image.open(p).convert("RGB")
        k = 700 / img.width
        small = img.resize((700, int(img.height * k)))
        d = ImageDraw.Draw(small)
        step = int(128 * k)
        for x in range(0, small.width, step):
            d.line([(x, 0), (x, small.height)], fill=(255, 0, 0), width=1)
            d.text((x + 2, 2), str(int(x / k)), fill=(255, 255, 0))
        for y in range(0, small.height, step):
            d.line([(0, y), (small.width, y)], fill=(255, 0, 0), width=1)
            d.text((2, y + 2), str(int(y / k)), fill=(255, 255, 0))
        small.save(OUT / f"ff_map_{name.lower()}.png")
        print(f"ff_map_{name.lower()}.png: {img.size} -> {small.size}")


if __name__ == "__main__":
    main()
