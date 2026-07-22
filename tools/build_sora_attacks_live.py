"""Wire Sora's TRUE animations from the user's live-recorded CoM sessions
(out/oam_kh_live, decoded by decode_oam_kh_live.py + the Strike-Raid cluster
extraction) into the shipping sheet + manifest.

Everything below was demonstrated by the user in-game and verified on
final_picks.png / throw_picks.png:
- FIELD swings (field-sprite scale == walk scale, no rescale, per the user's
  own judgement that these read cleaner than battle frames), in four facings:
  side x3 sequences (swing / sweep / dash-thrust), down, up.
- Strike Raid: the lunging throw pose (special cast anim) + the spinning
  keyblade exported as strike_raid_blade.png for the projectile special
  (heroes.json switches sora's special kind to projectile with this sprite).
Left-facing sources are mirrored (manifest side/down/up anims face right).

Run: .venv312/Scripts/python tools/build_sora_attacks_live.py
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
LIVE = ROOT / "tools/rom_ref/out/oam_kh_live/decoded"
SHEET = ROOT / "assets/franchises/kingdom_hearts/processed/sheets/sora.png"
MANIFEST = ROOT / "assets/franchises/kingdom_hearts/manifests/sora.json"
BLADE_OUT = ROOT / "assets/franchises/kingdom_hearts/processed/strike_raid_blade.png"

FIRST_CELL = 39   # overwrite the old rip cells; 30-38 keep stance (unused) + roll

# (anim, [(file, mirror)], fps, loop)
ANIMS = [
    ("attack_1_side", [("sora_live_001883", 1), ("sora_live_001889", 1), ("sora_live_001894", 1)], 12, False),
    ("attack_2_side", [("sora_live_002747", 0), ("sora_live_002758", 0), ("sora_live_002762", 0)], 12, False),
    ("attack_3_side", [("sora_live_002602", 1), ("sora_live_002643", 1), ("sora_live_002689", 1)], 12, False),
    ("attack_1_down", [("sora_live_002854", 0), ("sora_live_002860", 0), ("sora_live_002869", 0)], 12, False),
    ("attack_1_up", [("sora_live_002997", 0), ("sora_live_003027", 0), ("sora_live_003030", 0)], 12, False),
    # Strike Raid cast: the lunging throw held briefly (blade flies as the
    # engine projectile). Source faces left -> mirrored.
    ("special", [("throw_live_012380", 1), ("throw_live_012380", 1), ("throw_live_012386", 1)], 10, False),
]
DROP = ["attack_1", "attack_2", "attack_3"]
BLADE_SRC = "blade_live_012392"  # horizontal spinning keyblade, faces left


def main() -> None:
    doc = json.loads(MANIFEST.read_text(encoding="utf-8"))
    cols = doc["grid"]["columns"]
    fw, fh = doc["grid"]["frame_width"], doc["grid"]["frame_height"]

    cells = []  # (file, mirror)
    for _, frames, _, _ in ANIMS:
        for fm in frames:
            if fm not in cells:
                cells.append(fm)
    total = FIRST_CELL + len(cells)
    rows = (total + cols - 1) // cols

    sheet = Image.open(SHEET).convert("RGBA")
    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    out.paste(sheet.crop((0, 0, cols * fw, min(sheet.height, rows * fh))), (0, 0))
    for idx in range(FIRST_CELL, rows * cols):
        r, c = divmod(idx, cols)
        out.paste(Image.new("RGBA", (fw, fh), (0, 0, 0, 0)), (c * fw, r * fh))
    cell_of = {}
    for i, (name, mirror) in enumerate(cells):
        idx = FIRST_CELL + i
        im = Image.open(LIVE / f"{name}.png").convert("RGBA")
        if mirror:
            im = ImageOps.mirror(im)
        r, c = divmod(idx, cols)
        out.paste(im, (c * fw, r * fh))
        cell_of[(name, mirror)] = idx
    out.save(SHEET)

    anims = doc["animations"]
    for name in DROP:
        anims.pop(name, None)
    for name, frames, fps, loop in ANIMS:
        anims[name] = {"frames": [cell_of[fm] for fm in frames],
                       "fps": fps, "loop": loop}
    doc["grid"]["rows"] = rows
    MANIFEST.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n",
                        encoding="utf-8", newline="\n")

    blade = ImageOps.mirror(Image.open(LIVE / f"{BLADE_SRC}.png").convert("RGBA"))
    blade = blade.crop(blade.getbbox())
    blade.save(BLADE_OUT)
    print(f"sora: {len(cells)} live cells at {FIRST_CELL}+, rows={rows}")
    print(f"blade sprite {blade.size} -> {BLADE_OUT.relative_to(ROOT)}")
    print("anims:", ", ".join(sorted(anims)))


if __name__ == "__main__":
    main()
