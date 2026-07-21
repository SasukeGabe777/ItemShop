"""Assemble Sora's staged sprite sheet + manifest from OAM-decoded frames
(Kingdom Hearts: Chain of Memories), modeled on tools/build_link_from_oam.py.

Field frames (idle/walk) come from tools/rom_ref/out/oam/decoded_kh/sora_*.png
(decode_oam_kh.py, 64x64 cells, feet anchored at (32,56)). Battle frames
(attack/dodge-roll) come from decoded_kh_battle/sora_*.png (decode_oam_kh_battle.py,
same 64x64/feet-at-(32,56) convention, anchored on the body bbox bottom-center
since battle has no separate shadow object).

Frame picks verified on the labeled unique-pose contact sheets:
tools/rom_ref/out/oam/decoded_kh/unique_<group>.png and
tools/rom_ref/out/oam/decoded_kh_battle/unique_<group>.png.

Staged only -- does not touch assets/ or data/. Sheet path in the manifest
points at the eventual res:// location for when this is promoted.
"""
import json
import os
from PIL import Image

FIELD_SRC = "tools/rom_ref/out/oam/decoded_kh"
BATTLE_SRC = "tools/rom_ref/out/oam/decoded_kh_battle"
SHEET_OUT = "tools/rom_ref/out/staging/kingdom_hearts/sora_sheet.png"
MANIFEST_OUT = "tools/rom_ref/out/staging/kingdom_hearts/sora.json"
FINAL_SHEET_RES = "res://assets/franchises/kingdom_hearts/processed/sheets/sora.png"

CELL = 64
COLS = 8
PIVOT = [32, 56]

# The 9-pose walk cycle holds each pose ~4 game-frames (verified on sw*_*
# tags via unique_poses_kh.py), so first-occurrence tags sample each pose
# once. Confirmed the cycle actually repeats (36-frame capture wrapped back
# to pose 1 at the end).
WALK_DN = ["swdn_00", "swdn_01", "swdn_05", "swdn_09", "swdn_13", "swdn_17", "swdn_21", "swdn_25", "swdn_29"]
WALK_UP = ["swup_00", "swup_01", "swup_05", "swup_09", "swup_13", "swup_17", "swup_21", "swup_25", "swup_29"]
WALK_RT = ["swrt_00", "swrt_01", "swrt_05", "swrt_09", "swrt_13", "swrt_17", "swrt_21", "swrt_25", "swrt_29"]

# (anim_name, src_dir, [frame tags], fps, loop)
ANIMS = [
    # idles: Sora has no blink/fidget in this game -- verified with a 200-sample
    # (~20s), every-6-frame dense capture that never varied. Single static pose,
    # reported honestly rather than fabricating a blink.
    ("idle_down", FIELD_SRC, ["sidn_00"], 3, True),
    ("idle_up", FIELD_SRC, ["siup_00"], 3, True),
    ("idle_side", FIELD_SRC, ["sirt_00"], 3, True),
    ("walk_down", FIELD_SRC, WALK_DN, 14, True),
    ("walk_up", FIELD_SRC, WALK_UP, 14, True),
    ("walk_side", FIELD_SRC, WALK_RT, 14, True),
    # attack_1: real battle capture (Keyblade drawn, sword swing) -- side view
    # only (CoM battles are side-view; fallback chain covers down/up).
    ("attack_1_side", BATTLE_SRC, ["satk_00", "satk_07", "satk_19"], 10, False),
    # roll: the Dodge Roll sleight (confirmed via in-game tutorial text: "Tap
    # the +Control Pad Left or Right twice: Dodge Roll"), captured via a
    # double-tap in battle. This IS Sora's dodge in CoM -- there is no
    # separate "jump-dodge"; B is a plain Jump per the same tutorial.
    ("roll_side", BATTLE_SRC, ["sdodge2_tap2_00", "sdodge2_tap2_02", "sdodge2_tap2_10",
                               "sdodge2_tap2_17", "sdodge2_tap2_23", "sdodge2_tap2_29"], 12, False),
    # NOTE: no "special_*" entry -- the Strike Raid sleight (3 attack cards
    # summing 24-26) was not reached; see the final report for why.
]

def main():
    total = sum(len(tags) for _, _, tags, _, _ in ANIMS)  # upper bound; dedup below
    all_keys = {(src, tag) for _, src, tags, _, _ in ANIMS for tag in tags}
    n = len(all_keys)
    rows = (n + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    manifest_anims = {}
    cell_of = {}
    idx = 0
    for name, src, tags, fps, loop in ANIMS:
        frames = []
        for tag in tags:
            key = (src, tag)
            if key not in cell_of:
                fp = f"{src}/sora_{tag}.png"
                im = Image.open(fp).convert("RGBA")
                assert im.size == (CELL, CELL), f"{fp} is {im.size}, expected {CELL}x{CELL}"
                r, c = divmod(idx, COLS)
                sheet.alpha_composite(im, (c * CELL, r * CELL))
                cell_of[key] = idx
                idx += 1
            frames.append(cell_of[key])
        manifest_anims[name] = {"frames": frames, "fps": fps, "loop": loop}

    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    manifest = {
        "asset_id": "sora",
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
