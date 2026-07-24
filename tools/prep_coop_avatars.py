"""Extract co-op town/shop avatar walk blocks from the OMORI overworld rips in
assets/hero/p2-5/ into clean 3x4 (96x128) processed sheets + are referenced by
manifests in assets/hero/manifests/coop_<id>.json.

Every rip is an RPG Maker MV-style charset whose top-left (per-sheet offset)
3-column x 4-row block is the standard walk cycle with rows down/left/right/up.
We crop that block, chroma-key the sheet's flat background, snap the fringe, and
save a standalone 96x128 sheet. Re-runnable; never edits the raw sheets.

Run: .venv312\\Scripts\\python.exe tools\\prep_coop_avatars.py
"""
import os
from PIL import Image
import numpy as np

RAW = "assets/hero/p2-5"
OUT = "assets/hero/processed/coop"
CELL = 32

# id -> (filename, block origin (x,y), background color to key or None if the
# sheet already has alpha, key tolerance)
SHEETS = {
    "sunny":  ("PC _ Computer - Omori - Playable Characters (Overworld) - Sunny.png",         (0, 0),  (14, 44, 97),   70),
    "aubrey": ("PC _ Computer - Omori - Playable Characters (Overworld) - Aubrey (Faraway).png", (32, 0), (176, 38, 18), 70),
    "mari":   ("PC _ Computer - Omori - Non-Playable Characters (Overworld) - Mari.png",       (0, 0),  None,           0),
    # Note: the remaining rips (Kel, Basil, Vance, the enemies) are scattered
    # multi-pose sheets with non-32px, non-square cells and no clean top-left
    # walk block — they need per-sheet rect measurement, a separate pass.
}


def key_bg(block: Image.Image, bg, tol: int) -> Image.Image:
    """Punch the flat background colour to transparent, then snap the fringe."""
    a = np.array(block).astype(int)
    rgb = a[:, :, :3]
    dist = np.abs(rgb - np.array(bg)).max(axis=2)
    a[dist <= tol, 3] = 0
    # snap remaining semi-transparent fringe so edges stay crisp at 2x
    alpha = a[:, :, 3]
    alpha[(alpha > 0) & (alpha < 128)] = 0
    alpha[alpha >= 128] = 255
    a[:, :, 3] = alpha
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for aid, (fname, origin, bg, tol) in SHEETS.items():
        im = Image.open(os.path.join(RAW, fname)).convert("RGBA")
        ox, oy = origin
        block = im.crop((ox, oy, ox + CELL * 3, oy + CELL * 4))
        if bg is not None:
            block = key_bg(block, bg, tol)
        out_path = os.path.join(OUT, f"{aid}.png")
        block.save(out_path)
        opaque = int((np.array(block)[:, :, 3] > 0).sum())
        print(f"{aid:8s} -> {out_path}  ({opaque} opaque px)")


if __name__ == "__main__":
    main()
