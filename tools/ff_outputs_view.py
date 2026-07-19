import sys
from pathlib import Path
sys.path.insert(0, "tools")
from PIL import Image, ImageDraw

ROOT = Path(".")
FF = ROOT / "assets/franchises/final_fantasy"
OUT = ROOT / "tools/out"
W = 1100
canvas = Image.new("RGB", (W, 1350), (40, 40, 52))
d = ImageDraw.Draw(canvas)
y = 4
# cloud sheet at 3x
sheet = Image.open(FF / "processed/sheets/cloud.png").convert("RGBA")
big = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
canvas.paste(big, (4, y), big)
d.text((big.width + 14, y + 4), "cloud sheet 3x: idle_d, walk_d x4, idle_u, walk_u x2 | idle_s, walk_s x2, atk1 x2, atk2 x2", fill=(255, 255, 150))
y += big.height + 10
# enemies row
x = 4
for uid in ["ghost", "giant_rat", "guard_hound", "magitek_armor", "malboro", "ahriman", "imperial_shadow", "soldier_3rd", "tonberry", "flan", "sand_worm", "behemoth"]:
    im = Image.open(FF / f"processed/sheets/{uid}.png").convert("RGBA")
    if x + im.width > W - 4:
        x = 4; y += 130
    canvas.paste(im, (x, y + 110 - im.height), im)
    d.text((x, y + 112), uid[:12], fill=(255, 255, 150))
    x += max(im.width + 8, 62)
y += 135
x = 4
for uid in ["red_dragon", "kaiser_dragon", "goddess"]:
    im = Image.open(FF / f"processed/sheets/{uid}.png").convert("RGBA")
    canvas.paste(im, (x, y + 130 - im.height), im)
    d.text((x, y + 132), uid, fill=(255, 255, 150))
    x += im.width + 30
# items 4x
for iid in ["mythril_sword", "genji_glove", "ff_ribbon"]:
    im = Image.open(FF / f"processed/items/{iid}.png").convert("RGBA")
    im = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
    canvas.paste(im, (x, y + 130 - im.height), im)
    d.text((x, y + 132), iid, fill=(150, 255, 150))
    x += im.width + 20
y += 155
# rooms at 1/4
x = 4
for i, rid in enumerate(["start_village", "combat_grove", "combat_glade", "combat_street", "treasure_manor", "boss_night"]):
    im = Image.open(ROOT / f"assets/locations/ffdungeon/processed/{rid}.png")
    im = im.resize((160, 96))
    if x + 165 > W:
        x = 4; y += 115
    canvas.paste(im, (x, y))
    d.text((x, y + 98), rid, fill=(150, 220, 255))
    x += 168
y += 120
tr = Image.open(ROOT / "assets/locations/ffdungeon/processed/trees.png")
tr = tr.resize((tr.width * 2, tr.height * 2), Image.NEAREST)
canvas.paste(tr, (4, y))
d.text((tr.width + 12, y + 4), "trees blocker 2x", fill=(150, 220, 255))
canvas.save(OUT / "ff_outputs.png")
print("ok")
