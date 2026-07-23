"""Naruto's missing back view, from the user's naruto_kakashi_update.png
(2026-07-22; the Kakashi column is a future hero — NOT wired yet).

The old rip had no back frames (walking up used the side profile as a
stopgap). This recomposes naruto.png at a 28x34 cell (old cells were 25x31,
the new frames are 33px tall), keeping every old frame at its old index,
and appends:
  frames 16-18: face-back walk (islands x7/x27/x46 of the back row)
  frames 19-21: melee_back -> attack_1_up
Manifest: idle_up [17], walk_up [16,17,18,17], attack_1_up [19,20,21].
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/franchises/naruto/raw/naruto_kakashi_update.png"
SHEET = ROOT / "assets/franchises/naruto/processed/sheets/naruto.png"
MANIFEST = ROOT / "assets/franchises/naruto/manifests/naruto.json"

OLD_CW, OLD_CH, OLD_COLS = 25, 31, 8
CW, CH, COLS = 28, 34, 8

src = load_rgba(SRC)
boxes = find_islands(src, min_area=40, merge_gap=1)
naruto_boxes = [b for b in boxes if b[2] <= 210]
# back-walk row (y 232-265) and melee_back row (y 339-371), left-to-right
back_walk = sorted([b for b in naruto_boxes if 230 <= b[1] <= 266 and b[0] < 70], key=lambda b: b[0])
melee_back = sorted([b for b in naruto_boxes if 338 <= b[1] <= 372 and b[0] < 70], key=lambda b: b[0])
assert len(back_walk) == 3 and len(melee_back) == 3, (back_walk, melee_back)

old = Image.open(SHEET).convert("RGBA")
new_frames = [src.crop(b) for b in back_walk] + [src.crop(b) for b in melee_back]
total = 16 + len(new_frames)
rows = (total + COLS - 1) // COLS
canvas = Image.new("RGBA", (COLS * CW, rows * CH), (0, 0, 0, 0))
for f in range(16):
    x = (f % OLD_COLS) * OLD_CW
    y = (f // OLD_COLS) * OLD_CH
    crop = old.crop((x, y, x + OLD_CW, y + OLD_CH))
    # playtest round 6: the side walk frames (4,5) face LEFT in the old rip
    # (engine expects RIGHT-facing side art) — flip their pixels
    if f in (4, 5):
        crop = crop.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.alpha_composite(crop, ((f % COLS) * CW + (CW - OLD_CW) // 2,
                                  (f // COLS) * CH + (CH - OLD_CH) - 2))
for n, crop in enumerate(new_frames):
    f = 16 + n
    canvas.alpha_composite(crop, ((f % COLS) * CW + (CW - crop.width) // 2,
                                  (f // COLS) * CH + (CH - crop.height) - 2))
canvas.save(SHEET)

m = json.loads(MANIFEST.read_text(encoding="utf-8"))
m["grid"] = {"frame_width": CW, "frame_height": CH, "columns": COLS, "rows": rows}
m["pivot"] = [CW // 2, CH - 4]
m["animations"]["idle_up"] = {"frames": [17], "fps": 3, "loop": True}
m["animations"]["walk_up"] = {"frames": [16, 17, 18, 17], "fps": 9, "loop": True}
m["animations"]["attack_1_up"] = {"frames": [19, 20, 21], "fps": 12, "loop": False}
with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(m, indent=1) + "\n")
print(f"naruto sheet {COLS}x{rows} cells of {CW}x{CH}; back walk 16-18, back melee 19-21")
