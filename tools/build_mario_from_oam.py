"""Assemble Mario's staged sprite sheet + manifest from OAM-decoded frames
(M&L Superstar Saga), modeled on tools/build_link_from_oam.py.

Source: tools/rom_ref/out/oam/decoded_ml/mario_*.png (decode_oam_ml.py,
48x48 cells, feet anchored at (24,40) -- bottom-center of Mario's own pal-0
bbox, no shared shadow object was found reliably; see decode_oam_ml.py).

Frame picks verified on tools/rom_ref/out/oam/decoded_ml/unique_<group>.png.
walk_side uses the "right" capture only -- the "left" capture was walking
into a wall (confirmed by the barrier edge-probe: this room's west edge is
blocked) and barely animated, so it was discarded rather than used as a
misleading side pose.

Staged only -- does not touch assets/ or data/.
"""
import json
import os
from PIL import Image

SRC = "tools/rom_ref/out/oam/decoded_ml"
SHEET_OUT = "tools/rom_ref/out/staging/mario/mario_sheet.png"
MANIFEST_OUT = "tools/rom_ref/out/staging/mario/mario.json"
FINAL_SHEET_RES = "res://assets/franchises/mario/processed/sheets/mario.png"

CELL = 48
COLS = 8
PIVOT = [24, 40]

# PASS-2 NOTE (see tools/fix_hero_sheets_pass2.py): the leading tags of every
# group are capture transition junk — back-turned turning frames (mw*_00/01/04,
# mwrt_08) and arm-raised celebration frames (mwdn_20/22). They stay in the
# tag lists so existing sheet cell indices keep their meaning, but the CYCLES
# below only play the verified correct-facing poses.
WALK_DN = ["mwdn_00", "mwdn_01", "mwdn_04", "mwdn_09", "mwdn_11", "mwdn_14", "mwdn_20", "mwdn_22"]
WALK_UP = ["mwup_00", "mwup_01", "mwup_04", "mwup_09", "mwup_11", "mwup_14", "mwup_21"]
WALK_RT = ["mwrt_00", "mwrt_01", "mwrt_04", "mwrt_08", "mwrt_09", "mwrt_11", "mwrt_14", "mwrt_21", "mwrt_24"]

ANIMS = [
    # idles: like Sora, no blink/fidget found in a dense 30-sample capture --
    # reported honestly as a single static pose rather than fabricated.
    ("idle_down", ["midn_00"], 3, True),
    ("idle_up", ["miup_00"], 3, True),
    ("idle_side", ["mirt_00"], 3, True),
    ("walk_down", WALK_DN, 14, True),
    ("walk_up", WALK_UP, 14, True),
    ("walk_side", WALK_RT, 14, True),
    # NOTE: no attack_1/attack_2 -- battles (where jump/hammer attacks live)
    # were not reached; see the final report for why.
]

def main():
    all_tags = {tag for _, tags, _, _ in ANIMS for tag in tags}
    n = len(all_tags)
    rows = (n + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    manifest_anims = {}
    cell_of = {}
    idx = 0
    for name, tags, fps, loop in ANIMS:
        frames = []
        for tag in tags:
            if tag not in cell_of:
                fp = f"{SRC}/mario_{tag}.png"
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
        "asset_id": "mario",
        "sheet": FINAL_SHEET_RES,
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
    print(f"sheet {COLS}x{rows} cells ({idx} unique frames) -> {SHEET_OUT}")
    print(f"manifest -> {MANIFEST_OUT}")

if __name__ == "__main__":
    main()
