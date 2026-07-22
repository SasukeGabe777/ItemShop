"""Assemble Goku's sprite sheet + manifest from DBZ LoG II OAM dumps
(tools/rom_ref/out/oam_dbz_goku, captured via capture_goku_moves.lua with the
character poke 0x02038EBC/0x03000E90=4).

Isolation differs from build_piccolo_from_oam.py: Goku's capture zone (East
District 439) has ambient OBJ critters/props with no constant offset to the
hero, so proximity clustering fails — the hero is isolated by an exact tile
ALLOWLIST instead (body = tile 656; Kamehameha beam = 592 muzzle / 600 shaft
/ 608 tip, excluded from hero cells and exported as kame_* parts for the
engine's beam special, mirroring Piccolo's sbc_* trio at a -240 tile offset).

Frame picks verified on out/oam_dbz_goku/decoded/unique_*.png + the pose
order strings from the capture agent's report.

Run: .venv312/Scripts/python tools/build_goku_from_oam.py [--analyze]
"""
import argparse
import json
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "rom_ref"))
import decode_oam_dbz as dec

OAMDIR = "tools/rom_ref/out/oam_dbz_goku"
PREVIEW = f"{OAMDIR}/decoded/builder_preview"
SHEET_OUT = "assets/franchises/dragon_ball/processed/sheets/goku.png"
MANIFEST_OUT = "assets/franchises/dragon_ball/manifests/goku.json"
BEAM_OUT = "assets/franchises/dragon_ball/processed"

CELL = 48
COLS = 8
PIVOT = [24, 40]
BODY_TILE = 656
BEAM_TILES = {592: "kame_muzzle", 600: "kame_shaft", 608: "kame_tip"}

# (anim, [tags], fps, loop) — orders: walks are 4-pose cycles at 01/09/17/25;
# A-tap kick 6 action poses; B-tap punch 3 (long-held pose 2); Kamehameha =
# 2-pose charge shimmer then the beam-out firing pose.
ANIMS = [
    ("idle_down", ["idn_00"] * 9 + ["ilong_036"], 5, True),
    ("idle_up", ["iup_00"], 5, True),
    ("idle_side", ["irt_00"], 5, True),
    ("walk_down", ["wdn_01", "wdn_09", "wdn_17", "wdn_25"], 8, True),
    ("walk_up", ["wup_01", "wup_09", "wup_17", "wup_25"], 8, True),
    ("walk_side", ["wrt_01", "wrt_09", "wrt_17", "wrt_25"], 8, True),
    ("attack_1_down", ["madn_01", "madn_05", "madn_09", "madn_13"], 14, False),
    ("attack_1_side", ["mart_01", "mart_05", "mart_09", "mart_13"], 14, False),
    ("attack_1_up", ["maup_01", "maup_05", "maup_09", "maup_13"], 14, False),
    ("attack_2_down", ["mbdn_01", "mbdn_09", "mbdn_25"], 12, False),
    ("attack_2_side", ["mbrt_01", "mbrt_09", "mbrt_25"], 12, False),
    ("attack_2_up", ["mbup_01", "mbup_09", "mbup_25"], 12, False),
    ("special_down", ["kdn_01", "kdn_04", "kdn_01", "kdn_04", "kdn_30", "kdn_36", "kdn_30", "kdn_36"], 10, False),
    ("special_side", ["krt_01", "krt_04", "krt_01", "krt_04", "krt_30", "krt_36", "krt_30", "krt_36"], 10, False),
    ("special_up", ["kup_01", "kup_04", "kup_01", "kup_04", "kup_30", "kup_36", "kup_30", "kup_36"], 10, False),
]

BEAM_SRC = "krt_35"


def load_frame(tag):
    oam = open(f"{OAMDIR}/oam_{tag}.bin", "rb").read()
    vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
    pal = dec.load_palette(f"{OAMDIR}/objpal_{tag}.bin")
    return list(dec.parse_oam(oam)), vram, pal


def render_cell(tag):
    objs, vram, pal = load_frame(tag)
    body = [o for o in objs if o["tile"] == BODY_TILE]
    if not body:
        raise SystemExit(f"{tag}: no body-tile object")
    x0 = min(o["x"] for o in body); x1 = max(o["x"] + o["w"] for o in body)
    y1 = max(o["y"] + o["h"] for o in body)
    return dec.render(body, vram, pal, CELL, CELL,
                      ox=PIVOT[0] - (x0 + x1) // 2, oy=PIVOT[1] - y1)


def export_beam():
    objs, vram, pal = load_frame(BEAM_SRC)
    done = set()
    for o in sorted((o for o in objs if o["tile"] in BEAM_TILES),
                    key=lambda o: -(o["w"] * o["h"])):
        name = BEAM_TILES[o["tile"]]
        if name in done:
            continue
        done.add(name)
        cell = dec.render([o], vram, pal, o["w"], o["h"], ox=-o["x"], oy=-o["y"])
        Image.fromarray(cell, "RGBA").save(f"{BEAM_OUT}/{name}.png")
        print(f"beam part {name}: {o['w']}x{o['h']}")
    missing = set(BEAM_TILES.values()) - done
    if missing:
        raise SystemExit(f"beam parts missing from {BEAM_SRC}: {missing}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--analyze", action="store_true")
    args = ap.parse_args()
    tags = []
    for _, anim_tags, _, _ in ANIMS:
        for t in anim_tags:
            if t not in tags:
                tags.append(t)
    cells = {t: render_cell(t) for t in tags}
    if args.analyze:
        os.makedirs(PREVIEW, exist_ok=True)
        dec.contact_sheet(sorted(cells.items()), f"{PREVIEW}/picked_frames.png")
        print(f"preview ({len(cells)}): {PREVIEW}/picked_frames.png")
        return
    rows = (len(tags) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    cell_of = {}
    for i, t in enumerate(tags):
        r, c = divmod(i, COLS)
        sheet.alpha_composite(Image.fromarray(cells[t], "RGBA"), (c * CELL, r * CELL))
        cell_of[t] = i
    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    manifest = {
        "asset_id": "goku",
        "sheet": "res://" + SHEET_OUT.replace("\\", "/"),
        "native_scale": 1,
        "display_scale": 1,
        "pivot": PIVOT,
        "grid": {"frame_width": CELL, "frame_height": CELL,
                 "columns": COLS, "rows": rows},
        "animations": {name: {"frames": [cell_of[t] for t in anim_tags],
                              "fps": fps, "loop": loop}
                       for name, anim_tags, fps, loop in ANIMS},
    }
    with open(MANIFEST_OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(f"sheet {COLS}x{rows} ({len(tags)} frames) -> {SHEET_OUT}")
    export_beam()


if __name__ == "__main__":
    main()
