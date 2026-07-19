"""Round 2: coordinate-grid render of the Cloud sheet + island dumps for the
sheets whose largest-component extraction failed."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import _key_sheet
from slice_lib import find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent
FF = ROOT / "assets/franchises/final_fantasy"
OUT = ROOT / "tools/out"


def grid_render(img: Image.Image, out_name: str, scale: int = 4, step: int = 16) -> None:
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST).convert("RGBA")
    d = ImageDraw.Draw(big)
    for x in range(0, img.width + 1, step):
        d.line([(x * scale, 0), (x * scale, big.height)], fill=(255, 0, 0, 120))
        d.text((x * scale + 1, 1), str(x), fill=(255, 255, 0, 255))
    for y in range(0, img.height + 1, step):
        d.line([(0, y * scale), (big.width, y * scale)], fill=(255, 0, 0, 120))
        d.text((1, y * scale + 1), str(y), fill=(255, 255, 0, 255))
    big.save(OUT / out_name)
    print(out_name)


def main() -> None:
    cloud = _key_sheet(load_rgba(FF / "raw/ff_cloud.png"))
    grid_render(cloud, "ff_cloud_grid.png", scale=4, step=16)
    boxes = find_islands(cloud, min_area=40, merge_gap=0)
    with open(OUT / "ff_cloud_boxes.txt", "w") as f:
        for i, b in enumerate(boxes):
            f.write(f"{i}: {tuple(b)}  {b[2]-b[0]}x{b[3]-b[1]}\n")
    print(f"ff_cloud_boxes.txt ({len(boxes)})")

    for name in ["ff_red_dragon_vi", "ff_behemoth", "ff_ghost", "ff_guard_hound",
                 "ff_soldier_3rd_class", "ff_imperial_shadow", "ff_kaiser_dragon",
                 "ff_giant_rat", "ff_magitek_armor"]:
        img = _key_sheet(load_rgba(FF / f"raw/{name}.png"))
        grid_render(img, f"grid_{name}.png", scale=2, step=32)


if __name__ == "__main__":
    main()
