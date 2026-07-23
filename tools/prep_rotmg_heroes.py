"""Build ROTMG hero spritesheets + manifests from the official player atlas.

ROTMG player avatars are native 8x8 sprites on Sheets/atlases/characters.png,
indexed in spritesheet.json's `animatedSprites` (spriteSheetName == "players").
Each class index has 3 directions (0=down, 2=side, 3=up) x 3 actions
(0=stand, 1=walk[3 frames], 2=attack[2]). Side frames already face RIGHT, so no
flip is needed (the engine flips for left).

Heroes are SHOOTERS: the ranged basic never plays an attack animation (the sprite
keeps walking/standing, ROTMG-style), so we only build idle + walk x 3 dirs = 12
frames. Frames are trimmed, bottom-centre aligned (feet-registered) and upscaled
6x into a 4-col x 3-row grid.

Re-runnable: rewrites processed/sheets/<id>.png, processed/<id>.png (portrait),
and manifests/<id>.json for every hero. Never touches raw/.
"""
import json, os
from collections import defaultdict
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets/franchises/rotmg/raw")
PROC = os.path.join(ROOT, "assets/franchises/rotmg/processed")
MAN = os.path.join(ROOT, "assets/franchises/rotmg/manifests")
SCALE = 4
CELL = 32  # 8 * SCALE — sits between Link (~24px) and Sora (~43px) on screen

# hero id -> class index (verified by pixel-match against raw/customers/*.png)
HEROES = {
    "archer": 1,
    "knight": 5,
    "wizard": 2,
    "rogue": 0,
    "necromancer": 8,
    "ninja": 13,
}

_atlas = None
_pos = None  # index -> (direction, action) -> list of (frame_index, position)


def _load():
    global _atlas, _pos
    d = json.load(open(os.path.join(RAW, "Sheets/atlases/spritesheet.json"), encoding="utf-8"))
    _atlas = Image.open(os.path.join(RAW, "Sheets/atlases/characters.png")).convert("RGBA")
    _pos = defaultdict(lambda: defaultdict(list))
    for a in d["animatedSprites"]:
        if a["spriteSheetName"] == "players":
            _pos[a["index"]][(a["direction"], a["action"])].append(
                (a["spriteData"]["index"], a["spriteData"]["position"]))


def _frames(idx, direction, action):
    """All frames for (index, direction, action), sorted by atlas frame index so
    the walk cycle keeps its authored order. Returns list of 8x8 RGBA crops."""
    out = sorted(_pos[idx][(direction, action)], key=lambda t: t[0])
    return [_atlas.crop((p["x"], p["y"], p["x"] + p["w"], p["y"] + p["h"])) for _, p in out]


def _cell(im):
    """Trim to content, upscale, bottom-centre align into a CELL x CELL tile."""
    a = np.array(im.convert("RGBA"))
    m = a[:, :, 3] > 16
    if m.any():
        ys, xs = np.where(m)
        im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    im = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
    tile = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    x = (CELL - im.width) // 2
    y = CELL - im.height - 2  # 2px foot margin
    tile.paste(im, (max(0, x), max(0, y)), im)
    return tile


def build_hero(hid, idx):
    # frame plan: rows = down / side / up, cols = idle, walk0, walk1, walk2
    plan = [("down", 0), ("side", 2), ("up", 3)]
    sheet = Image.new("RGBA", (CELL * 4, CELL * 3), (0, 0, 0, 0))
    for r, (name, direction) in enumerate(plan):
        stand = _frames(idx, direction, 0)
        walk = _frames(idx, direction, 1)
        cells = [stand[0]] + walk[:3]
        while len(cells) < 4:  # pad short cycles by repeating the stand pose
            cells.append(stand[0])
        # ROTMG side sprites face LEFT; the engine flips for leftward movement,
        # so stored side frames must face RIGHT — mirror them (fixes the flip)
        if name == "side":
            cells = [c.transpose(Image.FLIP_LEFT_RIGHT) for c in cells]
        for c, fr in enumerate(cells[:4]):
            sheet.paste(_cell(fr), (c * CELL, r * CELL))
    os.makedirs(os.path.join(PROC, "sheets"), exist_ok=True)
    sheet.save(os.path.join(PROC, "sheets", f"{hid}.png"))
    # static portrait = idle-down
    _cell(_frames(idx, 0, 0)[0]).save(os.path.join(PROC, f"{hid}.png"))
    # manifest
    manifest = {
        "asset_id": hid,
        "sheet": f"res://assets/franchises/rotmg/processed/sheets/{hid}.png",
        "native_scale": 1, "display_scale": 1,
        "pivot": [CELL // 2, CELL - 3],
        "grid": {"frame_width": CELL, "frame_height": CELL, "columns": 4, "rows": 3},
        "animations": {
            "idle_down": {"frames": [0], "fps": 3, "loop": True},
            "walk_down": {"frames": [1, 2, 3, 2], "fps": 8, "loop": True},
            "idle_side": {"frames": [4], "fps": 3, "loop": True},
            "walk_side": {"frames": [5, 6, 7, 6], "fps": 8, "loop": True},
            "idle_up": {"frames": [8], "fps": 3, "loop": True},
            "walk_up": {"frames": [9, 10, 11, 10], "fps": 8, "loop": True},
        },
    }
    os.makedirs(MAN, exist_ok=True)
    with open(os.path.join(MAN, f"{hid}.json"), "w", newline="\n") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    return sheet


def main():
    _load()
    for hid, idx in HEROES.items():
        build_hero(hid, idx)
        print(f"built hero {hid} (class idx {idx})")


if __name__ == "__main__":
    main()
