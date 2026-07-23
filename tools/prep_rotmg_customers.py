"""Build ROTMG customer static sprites from the loose class art.

Each ROTMG class doubles as a shop customer (another adventurer browsing the
wares). Downscales the loose 190px front-pose sprites to ~30px statics at
processed/customers/<slug>.png. Never touches raw/. The CUSTOMERS map here is the
record of slug -> source file.
"""
import os
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets/franchises/rotmg/raw/customers")
OUT = os.path.join(ROOT, "assets/franchises/rotmg/processed/customers")
SIZE = 30

# slug -> (display name, source filename without .png)
CUSTOMERS = {
    "archer": ("Archer", "Archer"),
    "assassin": ("Assassin", "Assassin"),
    "bard": ("Bard", "Bard"),
    "huntress": ("Huntress", "Huntress"),
    "kensei": ("Kensei", "Kensei"),
    "knight": ("Knight", "Knight"),
    "mystic": ("Mystic", "Mystic"),
    "necromancer": ("Necromancer", "Necromancer"),
    "ninja": ("Ninja", "Ninja"),
    "paladin": ("Paladin", "Paladin"),
    "priest": ("Priest", "Priest"),
    "rogue": ("Rogue", "Rogue"),
    "samurai": ("Samurai", "Samurai"),
    "sorcerer": ("Sorcerer", "Sorcerer"),
    "summoner": ("Summoner", "Summoner"),
    "trickster": ("Trickster", "Trickster"),
    "warrior": ("Warrior", "Warrior"),
    "wizard": ("Wizard", "Wizard"),
    "void_huntsman": ("Void Huntsman", "Void Huntsman"),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for slug, (name, src) in CUSTOMERS.items():
        fp = os.path.join(RAW, src + ".png")
        if not os.path.exists(fp):
            print(f"  !! missing {src}"); continue
        im = Image.open(fp).convert("RGBA")
        a = np.array(im); m = a[:, :, 3] > 16
        ys, xs = np.where(m)
        im = im.crop((xs.min(), ys.min(), xs.max()+1, ys.max()+1))
        scale = SIZE / max(im.width, im.height)
        im = im.resize((max(1, round(im.width*scale)), max(1, round(im.height*scale))), Image.LANCZOS)
        b = np.array(im).astype(np.int16)
        b[:, :, 3] = np.where(b[:, :, 3] < 90, 0, np.where(b[:, :, 3] > 150, 255, b[:, :, 3]))
        Image.fromarray(np.clip(b, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, slug + ".png"))
        print(f"  customer {slug:14s} {im.size} <- {src}")


if __name__ == "__main__":
    main()
