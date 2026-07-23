"""Pokémon dungeon room backgrounds (640x384) composed from the user's PMD
tileset rips (bgs_dungeontiles, SilverDeoxys563/SparkuG23 — no credit needed).

Unlike the map-crop worlds (DBZ/Zelda), these rips are autotile ATLASES with
24px tiles at 25px pitch (1px teal separators). Rooms are composed from the
one region that is guaranteed contiguous and seamless: the ground column's
solid bottom block (x308-356, y540-732 — identical layout in all three
atlases, verified by teal-separator scan). Decals come from single tiles,
inset past their separator/fringe pixels:
  - donut pond tile (water column x634-658, y264-288; apple woods water
    carries baked magenta sparkle markers -> keyed out)
  - apple woods bush top (wall clump inset 2px to shed its grass fringe)
The boss room is a real map crop of Temporal Tower Summit (Past), 320x192
upscaled 2x (AGENT_GUIDE §4 room-crop recipe). Crystal-cluster wall tiles
were REJECTED as decals: they carry the wall's purple fill and read as
pasted boxes on a floor.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets/franchises/pokemon/raw/bgs_dungeontiles"
OUT = ROOT / "assets/locations/pkmndungeon/processed"
W, H = 640, 384

AW = "sprite_apple_woods.png"
CC = "sprite_crystal_cave_b01f_b05f.png"
GC = "sprite_golden_chamber.png"
TT = "sprite_temporal_tower_summit.png"


def crop(sheet: str, box) -> Image.Image:
    return Image.open(RAW / sheet).convert("RGBA").crop(box)


def key_magenta(img: Image.Image) -> Image.Image:
    """Remove the ripper's baked water-sparkle markers (pink/magenta)."""
    a = np.array(img)
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    mask = (r > 180) & (b > 180) & (g < 120)
    # fill with the tile's median water color instead of punching holes
    if mask.any():
        vis = a[~mask]
        fill = np.median(vis[:, :3], axis=0).astype(np.uint8)
        a[mask, 0], a[mask, 1], a[mask, 2] = fill[0], fill[1], fill[2]
    return Image.fromarray(a)


# The atlases lay 24px tiles at 25px pitch behind 1px LIGHT-CYAN separator
# lines (not the dark teal page color — that mistake shipped grid lines into
# the first pass of these rooms). Separator line positions detected by scan:
#   ground col lines x=308,333; row lines y=537+25k
#   water  col lines x=608,633,658; row lines y=162+25k
# A tile at (line_x, line_y) spans (line_x+1, line_y+1)+(24,24).
TILE = 24
PITCH = 25


def tiles(sheet: str, x_lines, y_lines) -> Image.Image:
    """Stitch the 24px tiles right+below the given separator lines, gapless."""
    img = Image.open(RAW / sheet).convert("RGBA")
    out = Image.new("RGBA", (TILE * len(x_lines), TILE * len(y_lines)))
    for j, ly in enumerate(y_lines):
        for i, lx in enumerate(x_lines):
            out.alpha_composite(img.crop((lx + 1, ly + 1, lx + 1 + TILE, ly + 1 + TILE)), (i * TILE, j * TILE))
    return out


GROUND_X = [308, 333]
GROUND_Y = [537 + 25 * k for k in range(7)]

aw_ground = tiles(AW, GROUND_X, GROUND_Y)
cc_ground = tiles(CC, GROUND_X, GROUND_Y)
gc_ground = tiles(GC, GROUND_X, GROUND_Y)
aw_pond = key_magenta(tiles(AW, [633], [262]))
cc_pool = key_magenta(tiles(CC, [633], [262]))
aw_clump = crop(AW, (86, 415, 106, 435))   # bush top, inset past grass fringe
gc_block = tiles(GC, [108], [162])         # golden wall block interior


def floor(tile: Image.Image) -> Image.Image:
    room = Image.new("RGBA", (W, H))
    for y in range(0, H, tile.height):
        for x in range(0, W, tile.width):
            room.alpha_composite(tile.crop((0, 0, min(tile.width, W - x), min(tile.height, H - y))), (x, y))
    return room


def save(room: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    room.convert("RGB").save(OUT / name)
    print(f"  {OUT / name}")


# start room: meadow with ponds and bush tops
room = floor(aw_ground)
for pos in [(500, 258), (152, 210), (330, 300)]:  # scattered spring pools
    room.alpha_composite(aw_pond, pos)
for pos in [(64, 52), (92, 58), (536, 66), (84, 300), (470, 120)]:
    room.alpha_composite(aw_clump, pos)
save(room, "start_meadow.png")

# combat: viridian woods variants
room = floor(aw_ground)
for pos in [(126, 70), (152, 76), (138, 96), (468, 250), (494, 246), (306, 162)]:
    room.alpha_composite(aw_clump, pos)
save(room, "combat_woods.png")

room = floor(aw_ground)
for pos in [(130, 100), (420, 280)]:
    room.alpha_composite(aw_pond, pos)
for pos in [(486, 84), (510, 94), (252, 282), (280, 286)]:
    room.alpha_composite(aw_clump, pos)
save(room, "combat_woods2.png")

# combat: cerulean depths variants
room = floor(cc_ground)
for pos in [(480, 240), (120, 84), (300, 180)]:
    room.alpha_composite(cc_pool, pos)
save(room, "combat_cave.png")

room = floor(cc_ground)
for pos in [(150, 260), (528, 96)]:
    room.alpha_composite(cc_pool, pos)
save(room, "combat_cave2.png")

# treasure: the golden chamber
save(floor(gc_ground), "treasure_vault.png")

# boss: Temporal Tower Summit (Past) arena, 320x192 crop -> 2x
arena = crop(TT, (152, 800, 472, 992)).resize((W, H), Image.NEAREST)
save(arena, "boss_summit.png")

# barrier: sealed golden block (repeats along blocked doorways)
gc_block.convert("RGB").save(OUT / "barrier_block.png")
print(f"  {OUT / 'barrier_block.png'}")
