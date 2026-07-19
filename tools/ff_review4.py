"""Round 4: 8x zoom of specific Cloud islands to read facings exactly."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import clean_alpha, find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent
FF = ROOT / "assets/franchises/final_fantasy"
OUT = ROOT / "tools/out"

img = load_rgba(FF / "raw/ff_cloud.png")
boxes = find_islands(img, min_area=40, merge_gap=0)
PICKS = [7, 8, 13, 14, 16, 17, 21, 27, 28, 33, 36, 38, 39, 42, 44, 47,
         51, 53, 56, 58, 59, 60, 64, 66, 70, 72, 73, 74, 75, 79, 80,
         40, 45, 46, 9, 51, 52]
Z = 8
cols = 8
cell_w, cell_h = 150, 230
rows = (len(PICKS) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (44, 44, 56, 255))
d = ImageDraw.Draw(sheet)
for j, i in enumerate(PICKS):
    fr = clean_alpha(img.crop(tuple(boxes[i])), lo=1, hi=255)
    z = min(Z, (cell_w - 6) // max(1, fr.width), (cell_h - 26) // max(1, fr.height))
    fr = fr.resize((fr.width * z, fr.height * z), Image.NEAREST)
    cx = (j % cols) * cell_w + (cell_w - fr.width) // 2
    cy = (j // cols) * cell_h + (cell_h - 22 - fr.height)
    sheet.alpha_composite(fr, (cx, cy))
    d.text(((j % cols) * cell_w + 4, (j // cols) * cell_h + cell_h - 18),
           f"#{i}", fill=(255, 255, 130, 255))
sheet.save(OUT / "ff_cloud_zoom.png")
print("ff_cloud_zoom.png")
