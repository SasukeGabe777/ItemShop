"""Per-character segment map: every detected candidate row with its id and
first frames, so AUTO_WALK_FIXES can name exact segments."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import AUTO_WALK_CUSTOMERS, _key_sheet, _row_segments
from slice_lib import clean_alpha, load_rgba

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    names = sys.argv[1:] or None
    for world, cfg in AUTO_WALK_CUSTOMERS.items():
        for name in cfg["names"]:
            if names and name not in names:
                continue
            path = ROOT / f"assets/franchises/{world}/raw/customers" / (cfg["pattern"] % name)
            if not path.exists():
                continue
            img = _key_sheet(load_rgba(path))
            segments = _row_segments(img)[:14]
            cell = 64
            sheet = Image.new("RGBA", (40 + 4 * (cell + 4), max(1, len(segments)) * (cell + 6) + 6),
                              (35, 35, 45, 255))
            d = ImageDraw.Draw(sheet)
            for i, seg in enumerate(segments):
                y = 4 + i * (cell + 6)
                d.text((4, y + cell // 2), str(i), fill=(255, 255, 150, 255))
                x = 40
                for b in seg["boxes"][:4]:
                    f = clean_alpha(img.crop(tuple(b)), lo=1, hi=255)
                    k = min(cell / max(1, f.height), cell / max(1, f.width), 2.5)
                    im = f.resize((max(1, int(f.width * k)), max(1, int(f.height * k))), Image.NEAREST)
                    sheet.alpha_composite(im, (x, y + cell - im.height))
                    x += cell + 4
            out = ROOT / f"tools/out/segs_{name}.png"
            sheet.convert("RGB").save(out)
            print("->", out)


if __name__ == "__main__":
    main()
