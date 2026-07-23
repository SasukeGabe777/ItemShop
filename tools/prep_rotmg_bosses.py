"""Build ROTMG boss spritesheets + manifests from the loose Bosses/ sprites.

Same pipeline as the enemies (downscale + 2-frame feet-anchored breathing), but
sized for boss presence (~100-120px). Bosses are driven by the Boss class's
telegraph->attack loop, so idle+breathe is all the art they need. Oryx_boss_1 is
the mandatory debut boss; the rest form the random pool.

Re-runnable: rewrites processed/sheets/<id>.png + manifests/<id>.json per boss.
"""
import os, json
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets/franchises/rotmg/raw/enemies/Bosses")
PROC = os.path.join(ROOT, "assets/franchises/rotmg/processed")
MAN = os.path.join(ROOT, "assets/franchises/rotmg/manifests")

# id -> (source filename without .png, target max dimension in px)
BOSSES = {
    "oryx":            ("Oryx_boss_1", 120),   # always the debut fight
    "cube_god":        ("Cube God", 104),
    "rock_dragon":     ("Rock Dragon", 112),
    "avatar":          ("Avatar", 110),
    "grand_sphinx":    ("Grand Sphinz", 106),   # note: pack misspells "Sphinz"
    "ghost_ship":      ("Ghost Ship", 118),
    "lord_lost_lands": ("Lord of the Lost Lands", 114),
    "oryx_2":          ("Oryx_boss_2", 106),
    "oryx_3":          ("Oryx_boss_3", 114),
}


def trim(im):
    a = np.array(im.convert("RGBA"))
    m = a[:, :, 3] > 16
    if not m.any():
        return im
    ys, xs = np.where(m)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def build(bid, src, target):
    im = trim(Image.open(os.path.join(RAW, src + ".png")).convert("RGBA"))
    scale = target / max(im.width, im.height)
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    im = im.resize((w, h), Image.LANCZOS)
    a = np.array(im).astype(np.int16)
    a[:, :, 3] = np.where(a[:, :, 3] < 96, 0, np.where(a[:, :, 3] > 150, 255, a[:, :, 3]))
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

    cw, ch = w, h
    sheet = Image.new("RGBA", (cw * 2, ch), (0, 0, 0, 0))
    sheet.paste(im, (0, 0), im)
    sh = max(1, round(h * 0.95))  # subtler breathe for the big bodies
    squashed = im.resize((w, sh), Image.LANCZOS)
    sheet.paste(squashed, (cw + (cw - w) // 2, ch - sh), squashed)
    os.makedirs(os.path.join(PROC, "sheets"), exist_ok=True)
    sheet.save(os.path.join(PROC, "sheets", f"{bid}.png"))
    im.save(os.path.join(PROC, f"{bid}.png"))

    manifest = {
        "asset_id": bid,
        "sheet": f"res://assets/franchises/rotmg/processed/sheets/{bid}.png",
        "native_scale": 1, "display_scale": 1,
        "pivot": [cw // 2, ch - 1],
        "grid": {"frame_width": cw, "frame_height": ch, "columns": 2, "rows": 1},
        "animations": {
            "idle_down": {"frames": [0, 1], "fps": 2, "loop": True},
            "walk_down": {"frames": [0, 1], "fps": 4, "loop": True},
            "idle_side": {"frames": [0, 1], "fps": 2, "loop": True},
            "walk_side": {"frames": [0, 1], "fps": 4, "loop": True},
            "idle_up": {"frames": [0, 1], "fps": 2, "loop": True},
            "walk_up": {"frames": [0, 1], "fps": 4, "loop": True},
        },
    }
    os.makedirs(MAN, exist_ok=True)
    with open(os.path.join(MAN, f"{bid}.json"), "w", newline="\n") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    return (cw, ch)


def main():
    for bid, (src, target) in BOSSES.items():
        sz = build(bid, src, target)
        print(f"built boss {bid:16s} from '{src}'  frame={sz}")


if __name__ == "__main__":
    main()
