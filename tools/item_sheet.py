"""Numbered island contact sheets for the supplied items.png rips, so item
icons can be identified and mapped to game items by index."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import _key_sheet
from slice_lib import clean_alpha, find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    for world in ["pokemon", "dragon_ball", "naruto"]:
        img = _key_sheet(load_rgba(ROOT / f"assets/franchises/{world}/raw/items.png"))
        boxes = [b for b in find_islands(img, min_area=24, merge_gap=1)
                 if 6 <= b[2] - b[0] <= 40 and 6 <= b[3] - b[1] <= 40]
        cols = 16
        cell = 64
        rows = (len(boxes) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cell, rows * cell), (35, 35, 45, 255))
        d = ImageDraw.Draw(sheet)
        for i, b in enumerate(boxes):
            im = clean_alpha(img.crop(tuple(b)), lo=1, hi=255)
            k = 2 if im.height <= 24 and im.width <= 24 else 1
            if k > 1:
                im = im.resize((im.width * k, im.height * k), Image.NEAREST)
            cx, cy = (i % cols) * cell, (i // cols) * cell
            sheet.paste(im, (cx + (cell - im.width) // 2, cy + 46 - im.height), im)
            d.text((cx + 2, cy + 50), str(i), fill=(255, 255, 150, 255))
        out = ROOT / f"tools/out/items_idx_{world}.png"
        sheet.save(out)
        print(world, len(boxes), "->", out.name)


if __name__ == "__main__":
    main()
