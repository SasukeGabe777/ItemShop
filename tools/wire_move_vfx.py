"""Wire the move_VFX drop into hero data (2026-07-22): Naruto's substitution
log+smoke on his vanish dodge (0148/pieces) and the pulsing rasengan on his
Shadow Clone Strike (0240/000). Idempotent.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
path = ROOT / "data/heroes.json"
data = json.loads(path.read_text(encoding="utf-8"))

naruto = next(h for h in data["heroes"] if h["id"] == "naruto")
naruto["combat"]["dodge"].update({
    "vfx_sheet": "res://assets/shared/effects/processed/naruto_sub.png",
    "vfx_frames": 6,
    "vfx_fps": 12,
})
naruto["combat"]["special"].update({
    "vfx_sheet": "res://assets/shared/effects/processed/naruto_rasengan.png",
    "vfx_frames": 12,
    "vfx_fps": 16,
})

with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
print("naruto dodge + special VFX wired")
