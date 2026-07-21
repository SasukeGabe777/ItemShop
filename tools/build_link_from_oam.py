"""Assemble Link's sprite sheet + manifest from OAM-decoded frames.

Inputs are the registered 48x48 frames produced by tools/rom_ref/decode_oam.py
(feet anchored at (24, 40) in every cell), captured from the real Minish Cap
via tools/rom_ref/capture_link_moves.lua etc. Those inputs are gitignored
(ROM-derived); this script is the permanent record of which captured pose maps
to which animation frame.

Frame picks were chosen off the labeled unique-pose contact sheets
(tools/rom_ref/out/oam/decoded/unique_<group>.png).
"""
import json
import os
from PIL import Image

SRC = "tools/rom_ref/out/oam/decoded"
SHEET_OUT = "assets/franchises/zelda/processed/sheets/link.png"
MANIFEST_OUT = "assets/franchises/zelda/manifests/link.json"

CELL = 48
COLS = 8
PIVOT = [24, 40]  # feet anchor used by decode_oam.py registration

# The 10-pose walk cycle holds each pose 3 game-frames (verified on vdn_*), so
# every 3rd dump starting at 01 samples each pose exactly once.
WALK = tuple(1 + 3 * i for i in range(10))

# (anim_name, [decoded frame tags], fps, loop) -- tags verified on unique_*.png.
# Repeated tags share one sheet cell; the manifest frames array repeats the
# index, which is how the idles get a short blink inside a 2 s loop.
ANIMS = [
    # idles: base pose x9 + eyes-closed blink (bdn/brt dense captures at
    # unique index 059); the up idle has no blink -- back view, verified static
    ("idle_down", ["idn_00"] * 9 + ["bdn_059"], 5, True),
    ("idle_up", ["iup_00"], 5, True),
    ("idle_side", ["irt_00"] * 9 + ["brt_059"], 5, True),
    # walks: full 10-pose cycle from the 36-frame f* captures
    ("walk_down", [f"fdn_{i:02d}" for i in WALK], 14, True),
    ("walk_up", [f"fup_{i:02d}" for i in WALK], 14, True),
    ("walk_side", [f"frt_{i:02d}" for i in WALK], 14, True),
    # attack_1: the clean steel slash arc (windup -> sweep -> follow-through)
    ("attack_1_down", ["sbd_01", "sbd_02", "sbd_03", "sbd_04"], 14, False),
    ("attack_1_side", ["sbr_01", "sbr_02", "sbr_03", "sbr_04"], 14, False),
    ("attack_1_up", ["sbu_01", "sbu_02", "sbu_03", "sbu_04"], 14, False),
    # attack_2: the glowing thrust / return cut, reads as a distinct second hit
    ("attack_2_down", ["sbd_09", "sbd_11", "sbd_12", "sbd_14"], 14, False),
    ("attack_2_side", ["sbr_05", "sbr_06", "sbr_07", "sbr_09"], 14, False),
    ("attack_2_up", ["sbu_05", "sbu_06", "sbu_07", "sbu_08"], 14, False),
    # roll (R-button dodge): side is the tucked tumble from rrt_06 on (the
    # first poses are a translucent wind-up ghost — skipped); down rolls read
    # subtle in the source game too. roll_up is NOT wired yet: that capture
    # bleached out in a screen-transition fade (unique_rup.png) — the engine
    # falls back to roll_side until a clean recapture lands.
    ("roll_down", ["rdn_04", "rdn_10", "rdn_16", "rdn_22", "rdn_28"], 16, False),
    ("roll_side", ["rrt_06", "rrt_09", "rrt_12", "rrt_15", "rrt_18", "rrt_27"], 16, False),
]

def main():
    total = len({tag for _, tags, _, _ in ANIMS for tag in tags})
    rows = (total + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    manifest_anims = {}
    cell_of = {}
    idx = 0
    for name, tags, fps, loop in ANIMS:
        frames = []
        for tag in tags:
            if tag not in cell_of:
                fp = f"{SRC}/link_{tag}.png"
                im = Image.open(fp).convert("RGBA")
                assert im.size == (CELL, CELL), f"{fp} is {im.size}, expected {CELL}x{CELL}"
                r, c = divmod(idx, COLS)
                sheet.alpha_composite(im, (c * CELL, r * CELL))
                cell_of[tag] = idx
                idx += 1
            frames.append(cell_of[tag])
        manifest_anims[name] = {"frames": frames, "fps": fps, "loop": loop}

    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    manifest = {
        "asset_id": "link",
        "sheet": "res://" + SHEET_OUT.replace("\\", "/"),
        "native_scale": 1,
        "display_scale": 1,
        "pivot": PIVOT,
        "grid": {"frame_width": CELL, "frame_height": CELL,
                 "columns": COLS, "rows": rows},
        "animations": manifest_anims,
    }
    with open(MANIFEST_OUT, "w", newline="\n") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    print(f"sheet {COLS}x{rows} cells ({total} frames) -> {SHEET_OUT}")
    print(f"manifest -> {MANIFEST_OUT}")

if __name__ == "__main__":
    main()
