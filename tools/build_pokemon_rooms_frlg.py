"""Pokémon dungeon pass 2 — FireRed/LeafGreen location drop (2026-07-22,
user-supplied after 'rooms feel very empty' playtest note).

Adds real map-crop rooms per the DBZ recipe (GBA 16px tiles: crop 320x192,
upscale 2x so each source tile lands on one 32px dungeon cell):
  - start_pallet   : Pallet Town garden/pond (partial lab building at the
                     crop edge patched over with grass tiles)
  - combat_tower   : Pokemon Tower 3F gravestone floor (round-room black
                     void corners filled with the floor tile)
  - combat_hideout : Rocket Hideout B1F ("a laboratory that should have
                     stayed closed") — black void filled with its floor
  - treasure_casino: Rocket Game Corner slot floor
Obstacle props chroma-keyed from the magenta tileset rip (sprite_tileset):
pine tree, bush, white boulder, rock pile, gravestone — 2x to match the
room pixel density. Barrier: the user-supplied Strength boulder
(raw/barrier_block.png) at 2x, replacing the golden block.
Coordinates verified on mapruler_/contact_frlg_tiles overlays (scale 2 —
coords below are already divided back to native).
"""
from pathlib import Path

import numpy as np
from PIL import Image

import sys
sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import chroma_key, clean_alpha, largest_component, load_rgba

ROOT = Path(__file__).resolve().parent.parent
LOC = ROOT / "assets/franchises/pokemon/raw/locations"
RAW = ROOT / "assets/franchises/pokemon/raw"
OUT = ROOT / "assets/locations/pkmndungeon/processed"
W, H = 640, 384


def fill_black(img: Image.Image, tile: Image.Image) -> Image.Image:
    """Replace near-black void pixels with a tiled floor sample."""
    a = np.array(img.convert("RGB"))
    t = np.array(tile.convert("RGB"))
    th, tw = t.shape[:2]
    mask = a.sum(axis=2) < 30
    ys, xs = np.nonzero(mask)
    a[ys, xs] = t[ys % th, xs % tw]
    return Image.fromarray(a)


def room_from_map(sheet: str, box, name: str, fill_tile_at=None, patches=None) -> None:
    img = Image.open(LOC / sheet).convert("RGB")
    crop = img.crop(box)
    if patches:
        for (px0, py0, px1, py1), (sx, sy) in patches:
            tile = img.crop((sx, sy, sx + 16, sy + 16))
            for y in range(py0, py1, 16):
                for x in range(px0, px1, 16):
                    crop.paste(tile, (x, y))
    if fill_tile_at:
        sx, sy = fill_tile_at
        crop = fill_black(crop, img.crop((sx, sy, sx + 16, sy + 16)))
    up = crop.resize((W, H), Image.NEAREST)
    OUT.mkdir(parents=True, exist_ok=True)
    up.save(OUT / name)
    print(f"  {OUT / name}")


# start: Pallet Town garden + pond; patch the lab-building remnant (crop-local
# rect) with plain grass sampled at map (48, 312)
room_from_map(
    "sprite_pallet_town.png", (40, 176, 360, 368), "start_pallet.png",
    patches=[((168, 0, 296, 96), (64, 64))],
)
# combat: Pokemon Tower 3F — fill round-room void with the haunted floor
room_from_map(
    "sprite_pok_mon_tower.png", (40, 430, 360, 622), "combat_tower.png",
    fill_tile_at=(192, 500),
)
# combat: Rocket Hideout B1F — fill void with the olive lab floor
room_from_map(
    "sprite_rocket_hideout.png", (48, 192, 368, 384), "combat_hideout.png",
    fill_tile_at=(208, 240),
)
# treasure: Rocket Game Corner slot floor — fill edge void with carpet
# right edge of the crop overruns into the adjacent sheet panel — patch it
# with plain carpet before the void fill
room_from_map(
    "sprite_rocket_game_corner.png", (0, 40, 320, 232), "treasure_casino.png",
    fill_tile_at=(240, 190), patches=[((272, 0, 320, 192), (240, 190))],
)

# --- obstacle props from the magenta tileset rip ---------------------------
tiles = load_rgba(LOC / "sprite_tileset.png")
tiles = chroma_key(tiles, tiles.getpixel((0, 0))[:3], tol=16)
PROPS = {
    "prop_pine": (98, 42, 131, 81),      # big pine tree
    "prop_bush": (4, 139, 21, 156),      # small round tree/bush
    "prop_boulder": (181, 125, 199, 146),  # white boulder
    "prop_rocks": (162, 196, 179, 214),  # brown rock pile
    "prop_grave": (238, 404, 256, 441),  # gravestone (RAWR sheet joke aside)
}
for name, box in PROPS.items():
    crop = clean_alpha(largest_component(tiles.crop(box)))
    up = crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST)
    up.save(OUT / f"{name}.png")
    print(f"  {OUT / name}.png {up.size}")

# --- barrier: user-supplied Strength boulder at 2x --------------------------
b = load_rgba(RAW / "barrier_block.png")
b = clean_alpha(b)
b.resize((b.width * 2, b.height * 2), Image.NEAREST).save(OUT / "barrier_boulder.png")
print(f"  {OUT / 'barrier_boulder.png'}")
