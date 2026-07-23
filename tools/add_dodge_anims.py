"""Wire the user's dodge-animation drop (2026-07-22 round 2) into existing
hero sheets: link_dodge.png, pikachu_dash.png, charmander_dash.png.

Appends new cell rows to each hero's processed sheet and adds roll_*
animations to the manifest (combat_hero plays "roll" via the
roll_<dir> -> roll_side -> roll fallback chain; side frames face RIGHT).
Mario/Luigi get their dodges via prep_mario_luigi_v2.py instead (their
dodge rows live inside mario_luigi_new.png).

Island indices verified on contact_link/charm/pika sheets (scale 3):
link groups: 0-7 roll down, 8-14 roll side (faces LEFT -> flip), 15-22
roll up; pikachu/charmander: 4 right-facing dash frames each.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from slice_lib import find_islands, load_rgba

ROOT = Path(__file__).resolve().parent.parent

JOBS = {
    "link": {
        "source": ROOT / "assets/franchises/zelda/raw/heroes/link_dodge.png",
        "sheet": ROOT / "assets/franchises/zelda/processed/sheets/link.png",
        "manifest": ROOT / "assets/franchises/zelda/manifests/link.json",
        "anims": {
            "roll_down": [0, 1, 2, 3, 4, 5],
            "roll_side": [-9, -10, -11, -12, -13, -14],  # neg = flip island -i-1
            "roll_up": [15, 16, 17, 18, 19, 20],
        },
        "fps": 24,
    },
    "pikachu": {
        "source": ROOT / "assets/franchises/pokemon/raw/heroes/pikachu_dash.png",
        "sheet": ROOT / "assets/franchises/pokemon/processed/sheets/pikachu.png",
        "manifest": ROOT / "assets/franchises/pokemon/manifests/pikachu.json",
        "anims": {"roll_side": [0, 1, 2, 3]},
        "fps": 18,
    },
    "charmander": {
        "source": ROOT / "assets/franchises/pokemon/raw/heroes/charmander_dash.png",
        "sheet": ROOT / "assets/franchises/pokemon/processed/sheets/charmander.png",
        "manifest": ROOT / "assets/franchises/pokemon/manifests/charmander.json",
        "anims": {"roll_side": [0, 1, 2, 3]},
        "fps": 18,
    },
}


def run(name: str, job: dict) -> None:
    src = load_rgba(job["source"])
    boxes = find_islands(src, min_area=30, merge_gap=1)
    manifest = json.loads(job["manifest"].read_text(encoding="utf-8"))
    grid = manifest["grid"]
    cw, ch = grid["frame_width"], grid["frame_height"]
    cols, rows = grid["columns"], grid["rows"]
    # idempotent: rebuild from a sheet stripped of any previously-appended
    # dodge rows (base row count = rows without roll_* frames)
    existing_roll_frames = [f for a, d in manifest["animations"].items()
                            if a.startswith("roll") for f in d["frames"]]
    sheet = Image.open(job["sheet"]).convert("RGBA")
    if existing_roll_frames:
        base_rows = min(existing_roll_frames) // cols
        sheet = sheet.crop((0, 0, cols * cw, base_rows * ch))
        rows = base_rows
        manifest["animations"] = {a: d for a, d in manifest["animations"].items()
                                  if not a.startswith("roll")}
    total = sum(len(v) for v in job["anims"].values())
    new_rows = (total + cols - 1) // cols
    out = Image.new("RGBA", (cols * cw, (rows + new_rows) * ch), (0, 0, 0, 0))
    out.alpha_composite(sheet, (0, 0))
    idx = rows * cols
    for anim, frame_ids in job["anims"].items():
        indices = []
        for fid in frame_ids:
            flip = fid < 0
            real = -fid - 1 if flip else fid
            crop = src.crop(boxes[real])
            if flip:
                crop = crop.transpose(Image.FLIP_LEFT_RIGHT)
            if crop.width > cw or crop.height > ch:
                r = min(cw / crop.width, ch / crop.height)
                crop = crop.resize((max(1, int(crop.width * r)), max(1, int(crop.height * r))), Image.NEAREST)
            cx = (idx % cols) * cw + (cw - crop.width) // 2
            cy = (idx // cols) * ch + (ch - crop.height) - 2
            out.alpha_composite(crop, (cx, cy))
            indices.append(idx)
            idx += 1
        manifest["animations"][anim] = {"frames": indices, "fps": job["fps"], "loop": False}
    grid["rows"] = rows + new_rows
    out.save(job["sheet"])
    with open(job["manifest"], "w", encoding="utf-8", newline="\n") as f:
        indent = 2 if name in ("pikachu", "charmander") else 1
        f.write(json.dumps(manifest, indent=indent) + "\n")
    print(f"  {name}: +{total} roll frames, sheet now {grid['columns']}x{grid['rows']} cells")


if __name__ == "__main__":
    for name, job in JOBS.items():
        run(name, job)
