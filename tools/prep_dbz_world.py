"""Dragon Ball world prep: dungeon room backgrounds + obstacle props cut from
the LoG II map rips, and the worlds.json wiring (room_backgrounds,
obstacle_props, heroes list with Piccolo).

Sources (raw, spriters-resource rips on a mint key (71,255,187)):
- Northern Mountains: wilderness rooms — cabin start, stump-mesa / pine-trail /
  forest / waterfall-bridge combat, the ruined-dome cave (treasure, doubles as
  the "ruined lab" beat), and a barren crater plateau (boss arena).
- West City interiors were considered and dropped: the lab rooms are narrower
  than one 320x192 room crop.

Crop coordinates were picked off labeled candidate contact sheets (dominant-
color key scan) and each room was eyeballed at full size before landing here.

Run: .venv312/Scripts/python tools/prep_dbz_world.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import clean_alpha, flood_bg, largest_component

ROOT = Path(__file__).resolve().parent.parent
NM = (ROOT / "assets/franchises/dragon_ball/raw/locations/Game Boy Advance - "
      "Dragon Ball Z_ The Legacy of Goku II - Backgrounds - Northern Mountains.png")
OUT = ROOT / "assets/locations/dbzdungeon/processed"
RES = "res://assets/locations/dbzdungeon/processed"

# room name -> top-left of a 320x192 crop, exported 2x (640x384 = 20x12 cells)
ROOMS = {
    "start_cabin": (320, 2304),
    "combat_mesa": (1280, 1344),
    "combat_pines": (3712, 1920),
    "combat_forest": (1792, 3904),
    "combat_falls": (3264, 2304),
    "treasure_dome": (1728, 64),
    "boss_crater": (4800, 2176),
}

def is_meadow(rgb: np.ndarray) -> np.ndarray:
    """Flood family: every warm meadow tone (olive grass, orange flecks, light
    dirt). Pine needles stay because even the dark ones keep r below ~90."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r > 95) & (g > 95) & (b < 115)


def is_blue_tile(rgb: np.ndarray) -> np.ndarray:
    """The ruined-dome cave floor: saturated blue tiles + their light grid."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (b > 120) & (b > r.astype(np.int16) + 45)


# prop name -> (tight source rect around one object, flood background family)
PROPS = {
    "prop_pine": ((3742, 1925, 80, 150), is_meadow),
    "prop_pine_small": ((4165, 1980, 55, 100), is_meadow),
    "prop_debris": ((1938, 183, 42, 48), is_blue_tile),
}
PROP_CAP = 36  # dungeon places one prop per 32px cell


def main() -> None:
    im = Image.open(NM).convert("RGB")
    OUT.mkdir(parents=True, exist_ok=True)

    for name, (x, y) in ROOMS.items():
        crop = im.crop((x, y, x + 320, y + 192))
        crop.resize((640, 384), Image.NEAREST).save(OUT / f"{name}.png")
        print(f"room {name}: ({x},{y}) -> {OUT.relative_to(ROOT)}/{name}.png")

    for name, ((x, y, w, h), is_bg) in PROPS.items():
        cut = im.crop((x, y, x + w, y + h)).convert("RGBA")
        prop = clean_alpha(largest_component(flood_bg(cut, is_bg)), lo=1, hi=255)
        if prop.width > PROP_CAP or prop.height > PROP_CAP:
            k = min(PROP_CAP / prop.width, PROP_CAP / prop.height)
            prop = prop.resize((max(1, round(prop.width * k)),
                                max(1, round(prop.height * k))), Image.LANCZOS)
            prop = clean_alpha(prop, lo=96, hi=160)
        prop.save(OUT / f"{name}.png")
        print(f"prop {name}: {prop.size} -> {OUT.relative_to(ROOT)}/{name}.png")

    data_path = ROOT / "data/worlds.json"
    d = json.loads(data_path.read_text(encoding="utf-8"))
    for w in d["worlds"]:
        if w["id"] == "dragon_ball":
            w["heroes"] = ["goku", "piccolo"]
            w["obstacle_props"] = [f"{RES}/{p}.png" for p in PROPS]
            w["room_backgrounds"] = {
                "start": [f"{RES}/start_cabin.png"],
                "combat": [f"{RES}/combat_mesa.png", f"{RES}/combat_pines.png",
                           f"{RES}/combat_forest.png", f"{RES}/combat_falls.png"],
                "treasure": [f"{RES}/treasure_dome.png"],
                "boss": [f"{RES}/boss_crater.png"],
            }
    with open(data_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(d, indent=1, ensure_ascii=False) + "\n")
    print("worlds.json: dragon_ball wired (heroes, obstacle_props, room_backgrounds)")


if __name__ == "__main__":
    main()
