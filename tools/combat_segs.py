"""Segment maps for the Mario combat sheets (heroes/enemies/boss): every
candidate row with id + first 4 frames, for writing MARIO_COMBAT configs."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from prep_supplied_assets import _key_sheet, _row_segments
from slice_lib import clean_alpha, load_rgba

ROOT = Path(__file__).resolve().parent.parent

SHEETS = {
    "hero_mario": "assets/franchises/mario/raw/heroes/mario_mario_overworld.png",
    "hero_luigi": "assets/franchises/mario/raw/heroes/mario_luigi_overworld.png",
    "en_goomba": "assets/franchises/mario/raw/enemies/mario_goomba.png",
    "en_koopa": "assets/franchises/mario/raw/enemies/mario_koopa_troopas.png",
    "en_boo": "assets/franchises/mario/raw/enemies/mario_boo.png",
    "en_bobomb": "assets/franchises/mario/raw/enemies/mario_bob_omb.png",
    "boss_bowser": "assets/franchises/mario/raw/enemies/mario_bowser_boss.png",
}


def main() -> None:
    names = sys.argv[1:] or SHEETS.keys()
    for name in names:
        img = _key_sheet(load_rgba(ROOT / SHEETS[name]))
        segments = _row_segments(img)[:16]
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
        out = ROOT / f"tools/out/cseg_{name}.png"
        sheet.convert("RGB").save(out)
        print("->", out.name, len(segments), "segs")


if __name__ == "__main__":
    main()
