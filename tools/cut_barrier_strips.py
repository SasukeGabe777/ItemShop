"""Barrier/border strip tiles for final_fantasy and naruto dungeons, cut from
the EXISTING raw map rips used for those worlds' room crops (no emulator --
neither ROM is available). Staged to tools/rom_ref/out/staging/<world>/ for
review; NOT wired into assets/ or data/.

Sources (see docs/AGENT_GUIDE.md SS4 for the chroma recipe book):
- final_fantasy: the same two Esperville/Jidoor map rips tools/prep_ff_world.py
  crops rooms from.
    * Esperville has scale=1.0 for every FF_ROOM_CROPS entry (no resize), so
      native map pixels already equal final room pixels; barrier tiles cut
      from it are used as-is, matching cut_obstacle_props.py's prop_pine cuts.
    * Jidoor's town crops (combat_street/treasure_manor) use scale=1.25 to
      reach 640x384; barrier tiles cut from elsewhere in the SAME file get the
      same 1.25x NEAREST upscale, on the assumption (unverified beyond that
      shared crop factor) that the sheet is one uniform-resolution rip.
- naruto: assets/franchises/naruto/raw/locations/narutodungeon_konoha.png,
  the same file tools/prep_naruto_world.py cuts N_ROOMS from. Every room crop
  there is 320x192 -> 640x384, a uniform 2x; barrier tiles use the same 2x.

Coordinates below were verified two ways: an ASCII color-class map (print a
"."/letter grid over 4px cells so background vs. art is unambiguous, immune
to the zoomed-screenshot scale trap) and a visual contact sheet actually
viewed before picking these boxes -- see tools/rom_ref/out/staging/<world>/
contact_sheet.png.

Run: .venv312/Scripts/python tools/cut_barrier_strips.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import chroma_key, clean_alpha, keep_components, largest_component, load_rgba

ROOT = Path(__file__).resolve().parent.parent
FF_MAP_DIR = ROOT / "assets/franchises/final_fantasy/raw/locations"
NARUTO_MAP = ROOT / "assets/franchises/naruto/raw/locations/narutodungeon_konoha.png"
OUT_FF = ROOT / "tools/rom_ref/out/staging/final_fantasy"
OUT_NARUTO = ROOT / "tools/rom_ref/out/staging/naruto"

ESPERVILLE = FF_MAP_DIR / "Game Boy Advance - Final Fantasy VI Advance - Maps - Esperville.png"
JIDOOR = FF_MAP_DIR / "Game Boy Advance - Final Fantasy VI Advance - Maps - Jidoor.png"


def nearest(img: Image.Image, k: float) -> Image.Image:
    return img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.NEAREST)


# ---------------------------------------------------------------------------
# Final Fantasy: ruin wall (Esperville castle-ruin tower, matches the rock
# cliff border used in combat_grove/combat_glade/start_village/boss_night --
# all four are Esperville crops at scale 1.0) + garden fence/hedge (Jidoor,
# matches combat_street/treasure_manor's scale 1.25 town crops).
#
# Verified on tools/rom_ref/out/staging/final_fantasy/contact_sheet.png.
FF_RUIN_BG = (25, 49, 41)  # solid dark-green canvas behind the ruin tower art
FF_RUIN = {
    # crenellated tower top: two merlons + the grass->rock transition edge.
    # keep_components (not largest_component) -- the valley between merlons
    # touches background, splitting the crenellation into separate blobs.
    "ff_ruinwall_cap.png": ("cap", (1053, 88, 1149, 136), "keep"),
    # straight tower shaft, a column with no window notch (the notch sits at
    # x=1121-1137 per the ASCII scan; this column is clear of it).
    "ff_ruinwall_mid.png": ("mid", (1061, 132, 1101, 240), "largest"),
}

FF_FENCE_BG = (0, 0, 0)
FF_FENCE = {
    # pure rail lattice, no post -- a long clean run exists left of the first
    # post (post shafts center at native x=744 and x=792, spacing 48).
    "ff_fence_mid.png": (650, 286, 730, 304),
    # one decorative post: ball finial + hedge wrapping its corner + shaft
    # running down, standing in as the strip's end-cap (no distinct end-post
    # art exists separate from this corner post itself).
    "ff_fence_cap.png": (722, 248, 766, 336),
}
FF_HEDGE = {
    # clipped rectangular boxwood hedge block bordering the same garden path.
    "ff_hedge_mid.png": (698, 250, 774, 271),
}
JIDOOR_SCALE = 1.25  # matches FF_ROOM_CROPS scale for combat_street/treasure_manor


def cut_ff() -> None:
    OUT_FF.mkdir(parents=True, exist_ok=True)
    esp = load_rgba(ESPERVILLE)
    for name, (kind, box, mode) in FF_RUIN.items():
        crop = chroma_key(esp.crop(box), FF_RUIN_BG, tol=16)
        crop = keep_components(crop, min_area=25) if mode == "keep" else largest_component(crop)
        crop = clean_alpha(crop, lo=1, hi=255)
        crop.save(OUT_FF / name)
        print(f"  {name}: {crop.size} <- Esperville {box} (scale 1.0, no upscale)")

    jid = load_rgba(JIDOOR)
    for name, box in FF_FENCE.items():
        crop = chroma_key(jid.crop(box), FF_FENCE_BG, tol=20)
        crop = keep_components(crop, min_area=20)
        crop = clean_alpha(crop, lo=1, hi=255)
        crop = nearest(crop, JIDOOR_SCALE)
        crop.save(OUT_FF / name)
        print(f"  {name}: {crop.size} <- Jidoor {box} x{JIDOOR_SCALE}")
    for name, box in FF_HEDGE.items():
        crop = chroma_key(jid.crop(box), FF_FENCE_BG, tol=20)
        crop = keep_components(crop, min_area=20)
        crop = clean_alpha(crop, lo=1, hi=255)
        crop = nearest(crop, JIDOOR_SCALE)
        crop.save(OUT_FF / name)
        print(f"  {name}: {crop.size} <- Jidoor {box} x{JIDOOR_SCALE}")


# ---------------------------------------------------------------------------
# Naruto: two real border walls found already built into the Konoha map --
# a gray rock/cliff scalloped wall (matches combat_cliffs.png's border style)
# and a brown wood-log palisade of the identical scalloped shape in a
# different palette (appears twice independently: by the training clearing
# and again fencing the pasture near the bottom bridge -- confirms it's a
# real reusable tileset piece, not a one-off paint blob).
#
# Both are full-bleed opaque wall texture (no separate background to key --
# the crop IS the wall, ground-baked by construction) cropped tight to the
# wall band only. No crisp small repeat unit was measurable (autocorrelation
# on the merlon texture didn't show a clean period -- this is a painted DS
# tileset, not hard pixel art), so "mid" is the longest clean run found and
# "cap" is a narrower slice off its end; there is no visually distinct
# end-post art in the source, so cap and mid share the same texture.
#
# Verified on tools/rom_ref/out/staging/naruto/contact_sheet.png.
NARUTO_SCALE = 2.0  # matches every N_ROOMS entry in prep_naruto_world.py (320x192 -> 640x384)
NARUTO_WALLS = {
    "naruto_cliff_mid.png": (1262, 64, 1358, 128),
    "naruto_cliff_cap.png": (1326, 64, 1358, 128),
    # revised after an ASCII color-class scan showed the tree canopy actually
    # extends to native x=1172 (not 1153 as a first zoomed-screenshot read
    # suggested) and the wall band is y=170-221, not 166-230 -- the scale
    # trap, caught before shipping instead of after.
    "naruto_palisade_mid.png": (1185, 172, 1249, 218),
    "naruto_palisade_cap.png": (1225, 172, 1257, 218),
}


def cut_naruto() -> None:
    OUT_NARUTO.mkdir(parents=True, exist_ok=True)
    kon = Image.open(NARUTO_MAP).convert("RGB")
    for name, box in NARUTO_WALLS.items():
        crop = kon.crop(box).convert("RGBA")
        crop = nearest(crop, NARUTO_SCALE)
        crop.save(OUT_NARUTO / name)
        print(f"  {name}: {crop.size} <- Konoha {box} x{NARUTO_SCALE}")


if __name__ == "__main__":
    print("final_fantasy:")
    cut_ff()
    print("naruto:")
    cut_naruto()
    print("done")
