"""Compose the user's move_VFX drop (2026-07-22, assets/shared/effects/
move_VFX — folder-per-effect, folder-per-variant, frame PNGs) into compact
strip sheets under assets/shared/effects/processed/ for EffectFlipbook and
animated Projectiles. References supplied by the user:

  0126/000-007  standard enemy shooter, 8 dirs x 4 frames (flame bolt)
  0013/032-039  standard enemy shooter, 8 dirs x 2 frames (bubble chain)
  0160/001      standard enemy shooter, non-directional pulse flipbook
  0062/000-007  boss shooter, 8 dirs x 1 (star trail)
  0069/000-007  boss shooter, 8 dirs x 1 (dart)
  0055/000      boss gather/charge-up ring (volley flourish)
  0005/001      boss explosion/slam
  0013/040      boss dash wind
  0147/000      standard enemy melee impact
  0235/001      standard enemy dash poof
  0148/pieces   Naruto dodge: substitution log + smoke (composited here)
  0240/000      Naruto special: pulsing rasengan orb

Direction rows are stored [S, SW, W, NW, N, NE, E, SE] = folder order
000..007 (verified in-game via tests/vfx_probe_shot).
"""
from __future__ import annotations

import glob
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/shared/effects/move_VFX"
OUT = ROOT / "assets/shared/effects/processed"


def frames_of(folder: str, limit: int | None = None, step: int = 1, start: int = 0):
    files = sorted(glob.glob(str(SRC / folder / "*.png")))[start::step]
    if limit:
        files = files[:limit]
    return [Image.open(f).convert("RGBA") for f in files]


def strip(rows: list[list[Image.Image]], name: str) -> None:
    """rows -> one sheet: vframes=len(rows), hframes=max row length."""
    cw = max(i.width for r in rows for i in r)
    ch = max(i.height for r in rows for i in r)
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (cw * cols, ch * len(rows)), (0, 0, 0, 0))
    for ry, row in enumerate(rows):
        for cx, img in enumerate(row):
            sheet.alpha_composite(img, (cx * cw + (cw - img.width) // 2,
                                        ry * ch + (ch - img.height) // 2))
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / name)
    print(f"  {name}: {cols}x{len(rows)} cells of {cw}x{ch}")


# directional shooter sets (rows = dirs 000..007)
strip([frames_of(f"0126/{i:03d}") for i in range(8)], "shot_flame.png")
strip([frames_of(f"0013/{i:03d}") for i in range(32, 40)], "shot_bubble.png")
strip([frames_of(f"0062/{i:03d}") for i in range(8)], "shot_star.png")
strip([frames_of(f"0069/{i:03d}") for i in range(8)], "shot_dart.png")
# non-directional flipbooks
strip([frames_of("0160/001", limit=12, step=2)], "shot_pulse.png")
strip([frames_of("0055/000", limit=12, step=2)], "boss_gather.png")
strip([frames_of("0005/001", limit=12, step=2)], "slam_boom.png")
strip([frames_of("0013/040")], "dash_boss.png")
strip([frames_of("0147/000", limit=12)], "melee_impact.png")
strip([frames_of("0235/001", limit=12, step=1)], "dash_enemy.png")
strip([frames_of("0240/000", limit=12, start=2)], "naruto_rasengan.png")

# Naruto substitution: log + expanding smoke composited from pieces
p = SRC / "0148/pieces"


def piece(n: str) -> Image.Image:
    return Image.open(p / f"{n}.png").convert("RGBA")


log = piece("000_13")
cell = 48
seq = []
for parts in (["000_13"], ["000_13", "004_05"], ["000_13", "020_05"],
              ["016_05"], ["014_05"], ["018_05"]):
    f = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    for name in parts:
        img = piece(name)
        f.alpha_composite(img, ((cell - img.width) // 2, cell - img.height - 2))
    seq.append(f)
strip([seq], "naruto_sub.png")
