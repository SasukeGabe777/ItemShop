"""Labeled contact sheet of every processed customer-pool sprite, for
eyeballing which extracted frames are not clean front-facing stands."""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
CELL_W, CELL_H, LABEL_H = 72, 78, 10


def main() -> None:
    pngs = sorted(ROOT.glob("assets/franchises/*/processed/customers/*.png"))
    cols = 10
    rows = (len(pngs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * CELL_W, rows * (CELL_H + LABEL_H)), (30, 30, 40, 255))
    d = ImageDraw.Draw(sheet)
    for i, p in enumerate(pngs):
        im = Image.open(p).convert("RGBA")
        if im.height > CELL_H - 8:
            k = (CELL_H - 8) / im.height
            im = im.resize((max(1, round(im.width * k)), CELL_H - 8), Image.NEAREST)
        cx = (i % cols) * CELL_W
        cy = (i // cols) * (CELL_H + LABEL_H)
        sheet.paste(im, (cx + (CELL_W - im.width) // 2, cy + CELL_H - im.height - 2), im)
        d.text((cx + 2, cy + CELL_H), f"{i} {p.stem[:11]}", fill=(255, 255, 160, 255))
    out = ROOT / "tools/out/pool_sheet.png"
    out.parent.mkdir(exist_ok=True)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
    print(f"{len(pngs)} sprites -> {out}")


if __name__ == "__main__":
    main()
