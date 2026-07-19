"""Round 3: every Cloud island as a big labeled tile (no keying — raw alpha),
so each frame's facing/pose can be identified by number."""
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
print(f"{len(boxes)} islands (unkeyed)")
Z = 5
cols = 10
cell_w, cell_h = 110, 150
rows = (len(boxes) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (44, 44, 56, 255))
d = ImageDraw.Draw(sheet)
for i, b in enumerate(boxes):
    fr = clean_alpha(img.crop(tuple(b)), lo=1, hi=255)
    z = min(Z, (cell_w - 6) // max(1, fr.width), (cell_h - 26) // max(1, fr.height))
    z = max(1, z)
    fr = fr.resize((fr.width * z, fr.height * z), Image.NEAREST)
    cx = (i % cols) * cell_w + (cell_w - fr.width) // 2
    cy = (i // cols) * cell_h + (cell_h - 22 - fr.height)
    sheet.alpha_composite(fr, (cx, cy))
    d.text(((i % cols) * cell_w + 4, (i // cols) * cell_h + cell_h - 18),
           f"#{i} {b[0]},{b[1]} {b[2]-b[0]}x{b[3]-b[1]}", fill=(255, 255, 130, 255))
sheet.save(OUT / "ff_cloud_tiles.png")
with open(OUT / "ff_cloud_boxes_unkeyed.txt", "w") as f:
    for i, b in enumerate(boxes):
        f.write(f"{i}: {tuple(int(v) for v in b)}\n")
print("ff_cloud_tiles.png")
