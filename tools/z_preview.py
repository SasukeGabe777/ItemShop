"""Collage every prepped Zelda output (at 2-3x) for visual verification."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
Z = ROOT / "assets/franchises/zelda"
OUT = Path(__file__).parent / "out"


def grid_of(paths: list[tuple[str, Path]], scale: int, cols: int, cell: int, out: Path) -> None:
    if not paths:
        print(out.name, "SKIPPED (no inputs)")
        return
    rows = (len(paths) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell, rows * (cell + 14)), (44, 46, 66))
    d = ImageDraw.Draw(img)
    for n, (name, p) in enumerate(paths):
        x, y = (n % cols) * cell, (n // cols) * (cell + 14)
        if p.exists():
            s = Image.open(p).convert("RGBA")
            s = s.resize((s.width * scale, s.height * scale), Image.NEAREST)
            if s.width > cell or s.height > cell:
                r = min(cell / s.width, cell / s.height)
                s = s.resize((max(1, int(s.width * r)), max(1, int(s.height * r))), Image.NEAREST)
            img.paste(s, (x + (cell - s.width) // 2, y + (cell - s.height) // 2), s)
        d.text((x + 2, y + cell + 1), name, fill=(255, 255, 120))
    img.save(out)
    print(out.name, img.size)


enemies = ["keese", "octorok", "chuchu_green", "chuchu_blue", "rope", "leever",
           "ghini", "keaton", "spiked_beetle", "moblin", "stalfos", "darknut",
           "big_green_chuchu", "big_blue_chuchu", "vaati"]
grid_of([(e, Z / f"processed/sheets/{e}.png") for e in enemies], 2, 8, 200, OUT / "zp_enemies.png")

items = sorted((Z / "processed/items").glob("*.png"))
grid_of([(p.stem, p) for p in items], 3, 9, 80, OUT / "zp_items.png")

cust = sorted((Z / "processed/customers").glob("*.png"))
grid_of([(p.stem, p) for p in cust], 2, 8, 80, OUT / "zp_customers.png")

grid_of([("link_sheet", Z / "processed/sheets/link.png"),
         ("bomb", Z / "processed/bomb.png"),
         ("explosion", Z / "processed/sheets/bomb_explosion.png"),
         ("portrait", Z / "processed/link.png")], 2, 1, 560, OUT / "zp_link.png")

rooms = sorted((ROOT / "assets/locations/zeldadungeon/processed").glob("*.png"))
grid_of([(p.stem, p) for p in rooms], 1, 3, 330, OUT / "zp_rooms.png")
