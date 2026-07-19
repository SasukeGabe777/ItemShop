import sys
from pathlib import Path
sys.path.insert(0, "tools")
from PIL import Image, ImageDraw
from ff_review5 import key_corner, CANDS
from slice_lib import clean_alpha, largest_component, load_rgba

ROOT = Path(".")
FF = ROOT / "assets/franchises/final_fantasy"
OUT = ROOT / "tools/out"
cell_w, cell_h = 170, 190
sheet = Image.new("RGBA", (cell_w * 5, cell_h * ((len(CANDS) + 4) // 5)), (40, 40, 52, 255))
d = ImageDraw.Draw(sheet)
for i, name in enumerate(CANDS):
    img = key_corner(load_rgba(FF / f"raw/{name}.png"))
    fr = clean_alpha(largest_component(img), lo=1, hi=255)
    k = min(1.5, (cell_w - 10) / fr.width, (cell_h - 24) / fr.height)
    if k != 1:
        fr = fr.resize((max(1, int(fr.width * k)), max(1, int(fr.height * k))), Image.NEAREST)
    cx = (i % 5) * cell_w + (cell_w - fr.width) // 2
    cy = (i // 5) * cell_h + (cell_h - 20 - fr.height)
    sheet.alpha_composite(fr, (cx, cy))
    d.text(((i % 5) * cell_w + 4, (i // 5) * cell_h + cell_h - 16),
           f"{name.replace('ff_', '')} {fr.width}x{fr.height}", fill=(255, 255, 150, 255))
sheet.save(OUT / "ff_enemy_preview4.png")
print("done")
