import sys
from pathlib import Path
sys.path.insert(0, "tools")
from PIL import Image, ImageDraw
from prep_ff_world import key_corner
from slice_lib import load_rgba

ROOT = Path(".")
FF = ROOT / "assets/franchises/final_fantasy"
raw = load_rgba(FF / "raw/items/Game Boy Advance - Final Fantasy VI Advance - Miscellaneous - Weapons (1).png")
strip = key_corner(raw.crop((0, 400, 256, 496)))
big = strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST).convert("RGBA")
d = ImageDraw.Draw(big)
for x in range(0, strip.width + 1, 16):
    d.line([(x * 4, 0), (x * 4, big.height)], fill=(255, 0, 0, 140))
    d.text((x * 4 + 1, 1), str(x), fill=(255, 255, 0, 255))
for y in range(0, strip.height + 1, 16):
    d.line([(0, y * 4), (big.width, y * 4)], fill=(255, 0, 0, 140))
    d.text((1, y * 4 + 1), str(y + 400), fill=(255, 255, 0, 255))
bg = Image.new("RGBA", big.size, (40, 40, 60, 255))
bg.alpha_composite(big)
bg.convert("RGB").save(ROOT / "tools/out/ff_weapons_bottom.png")
print("ok", strip.size)
