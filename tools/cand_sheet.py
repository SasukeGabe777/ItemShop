"""Render the top-scoring candidate islands of problem customer sheets with
their crop boxes, so CUSTOMER_FIXES entries can be picked visually."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import _key_sheet, front_score
from slice_lib import clean_alpha, find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent

TARGETS = [
    ("kingdom_hearts", "kh_%s_gba.png", ["goofy", "hades", "hercules", "peter_pan", "tidus", "wakka"]),
    ("mario", "mario_%s.png", ["boo", "dry_bones", "koopa_troopas", "lady_lima"]),
]


def main() -> None:
    for world, pattern, names in TARGETS:
        for name in names:
            path = ROOT / f"assets/franchises/{world}/raw/customers" / (pattern % name)
            img = _key_sheet(load_rgba(path))
            cands = []
            for box in find_islands(img, min_area=80, merge_gap=1)[:260]:
                w, h = box[2] - box[0], box[3] - box[1]
                if not (12 <= w <= 60 and 16 <= h <= 80):
                    continue
                cand = img.crop(tuple(box))
                s = front_score(cand)
                if s > -0.5:
                    cands.append((s, tuple(box), cand))
            cands.sort(key=lambda c: -c[0])
            cands = cands[:14]
            cell = 130
            sheet = Image.new("RGBA", (max(1, len(cands)) * cell, 150), (35, 35, 45, 255))
            d = ImageDraw.Draw(sheet)
            for j, (s, box, cand) in enumerate(cands):
                im = clean_alpha(cand, lo=1, hi=255)
                k = min(2, 90 // max(1, im.height)) or 1
                if k > 1:
                    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
                sheet.paste(im, (j * cell + (cell - im.width) // 2, 100 - im.height), im)
                d.text((j * cell + 2, 104), f"{j} s={int(s)}", fill=(255, 255, 150, 255))
                d.text((j * cell + 2, 116), str(box[:2]), fill=(180, 220, 255, 255))
                d.text((j * cell + 2, 128), str(box[2:]), fill=(180, 220, 255, 255))
            out = ROOT / f"tools/out/cand_{world}_{name}.png"
            sheet.save(out)
            print(out.name, len(cands))


if __name__ == "__main__":
    main()
