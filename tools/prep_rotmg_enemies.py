"""Build ROTMG enemy spritesheets + manifests from the loose raw sprites.

ROTMG realm/godland enemies are single high-res sprites with (at most) a 2-frame
wobble in-game. We downscale each loose sprite to a role-appropriate size and
synthesize a 2-frame idle/walk "breathing" cycle (frame 1 = body squashed ~8%,
feet-anchored) so nothing ships as a lifeless single frame. Directions all reuse
the same frames (ROTMG enemies don't have per-facing art); the engine flips the
side view for leftward movement, which reads correctly for the profile sprites.

Re-runnable: rewrites processed/sheets/<id>.png + manifests/<id>.json per enemy.
Never touches raw/. The ENEMIES table here is the record of source->id + size.
"""
import os
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets/franchises/rotmg/raw/enemies/Standard Enemies")
PROC = os.path.join(ROOT, "assets/franchises/rotmg/processed")
MAN = os.path.join(ROOT, "assets/franchises/rotmg/manifests")

# id -> (source filename without .png, target max dimension in px)
ENEMIES = {
    "red_demon":          ("red demon", 40),
    "crystal_scorpion":   ("Crystallised Scorpion", 42),
    "crystal_cyclops":    ("Crystallised Cyclops", 46),
    "crystal_lizard":     ("Crystallised Lizard", 38),
    "megamoth_larva":     ("Megamoth Larva", 32),
    "swoll_fairy":        ("Swoll Fairy", 32),
    "snake_sentry":       ("Snakepit Guard (t)", 40),
    "ent_ancient":        ("Ent Ancient", 46),
    "queen_bee":          ("Queen Bee", 34),
    "spider_queen":       ("Spider Queen", 44),
    "corruption_phantom": ("Corruption Phantom", 40),
    "spoiled_creampuff":  ("Spoiled Creampuff", 30),
}


def trim(im):
    a = np.array(im.convert("RGBA"))
    m = a[:, :, 3] > 16
    if not m.any():
        return im
    ys, xs = np.where(m)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def build(eid, src, target):
    im = trim(Image.open(os.path.join(RAW, src + ".png")).convert("RGBA"))
    # scale so the larger dimension == target, keep aspect
    scale = target / max(im.width, im.height)
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    im = im.resize((w, h), Image.LANCZOS)
    # crisp the fringe that LANCZOS softens
    a = np.array(im).astype(np.int16)
    a[:, :, 3] = np.where(a[:, :, 3] < 96, 0, np.where(a[:, :, 3] > 150, 255, a[:, :, 3]))
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

    cw, ch = w, h
    sheet = Image.new("RGBA", (cw * 2, ch), (0, 0, 0, 0))
    sheet.paste(im, (0, 0), im)  # frame 0: rest
    # frame 1: body squashed 8% vertically, feet-anchored (breathing)
    sh = max(1, round(h * 0.92))
    squashed = im.resize((w, sh), Image.LANCZOS)
    sheet.paste(squashed, (cw + (cw - w) // 2, ch - sh), squashed)
    os.makedirs(os.path.join(PROC, "sheets"), exist_ok=True)
    sheet.save(os.path.join(PROC, "sheets", f"{eid}.png"))
    # static fallback
    im.save(os.path.join(PROC, f"{eid}.png"))

    manifest = {
        "asset_id": eid,
        "sheet": f"res://assets/franchises/rotmg/processed/sheets/{eid}.png",
        "native_scale": 1, "display_scale": 1,
        "pivot": [cw // 2, ch - 1],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": 2, "rows": 1},
        "animations": {
            "idle_down": {"frames": [0, 1], "fps": 3, "loop": True},
            "walk_down": {"frames": [0, 1], "fps": 6, "loop": True},
            "idle_side": {"frames": [0, 1], "fps": 3, "loop": True},
            "walk_side": {"frames": [0, 1], "fps": 6, "loop": True},
            "idle_up": {"frames": [0, 1], "fps": 3, "loop": True},
            "walk_up": {"frames": [0, 1], "fps": 6, "loop": True},
        },
    }
    import json
    os.makedirs(MAN, exist_ok=True)
    with open(os.path.join(MAN, f"{eid}.json"), "w", newline="\n") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    return (cw, ch)


def main():
    for eid, (src, target) in ENEMIES.items():
        sz = build(eid, src, target)
        print(f"built enemy {eid:20s} from '{src}'  frame={sz}")


if __name__ == "__main__":
    main()
