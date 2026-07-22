"""Assemble Piccolo's sprite sheet + manifest from DBZ LoG II OAM dumps.

Unlike build_link_from_oam.py (which pastes pre-decoded PNGs), this re-renders
each picked frame from the raw OAM/VRAM/PAL dumps so it can strip non-hero
objects: the SBC beam (muzzle tile 832, shaft 840, tip 848 — exported
separately for the in-engine beam special), parked offscreen objects, and the
stray overworld sprites that drift through the flight captures. Isolation is
"objects whose bbox is within GATHER of the hero object" (hero = live object
nearest screen center), after dropping static HUD tuples per group corpus.

Inputs (gitignored, recapture via tools/rom_ref/capture_piccolo_moves.lua +
capture_piccolo_extra.lua): tools/rom_ref/out/oam_dbz/. Frame picks chosen off
the unique-pose contact sheets + pose-order strings (unique_poses_dbz.py).
Capture pose facts: SBC charge alternates tags _01/_04, beam growth collapses
to one hero pose from _24 on; melee strikes are 2-pose crackle flickers;
mad (A-tap) is a clean 4-pose acrobatic flip -> used for the fly dodge.
"""
import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "rom_ref"))
import decode_oam_dbz as dec

OAMDIR = "tools/rom_ref/out/oam_dbz"
PREVIEW = f"{OAMDIR}/decoded/builder_preview"
SHEET_OUT = "assets/franchises/dragon_ball/processed/sheets/piccolo.png"
MANIFEST_OUT = "assets/franchises/dragon_ball/manifests/piccolo.json"
BEAM_OUT = "assets/franchises/dragon_ball/processed"

CELL = 48
COLS = 8
PIVOT = [24, 40]
BEAM_TILES = {832, 840, 848}
GATHER = 8
HUD_FRACTION = 0.6

# (anim_name, [tags], fps, loop) — verified on unique_*.png + order strings.
# Repeated tags share a sheet cell (frames array repeats the index).
ANIMS = [
    # idles: static pose + the ilong blink (pose ilong_043, held 4 frames
    # twice in 150) folded in for a 2 s loop
    ("idle_down", ["idn_00"] * 9 + ["ilong_043"], 5, True),
    ("idle_up", ["iup_00"], 5, True),
    ("idle_side", ["irt_00"], 5, True),
    # walks: 4-pose cycle, each pose held ~8 game-frames (order strings)
    ("walk_down", ["wdn_01", "wdn_09", "wdn_17", "wdn_25"], 8, True),
    ("walk_up", ["wup_01", "wup_09", "wup_17", "wup_25"], 8, True),
    ("walk_side", ["wrt_01", "wrt_09", "wrt_17", "wrt_25"], 8, True),
    # melee: the mad/mar A-tap flip-kick (user-confirmed: this IS Piccolo's
    # kick). The old mb* "crackle flicker" frames were NOT melee — B-tapped
    # with SBC preselected they're beam-charge flashes (user flagged the
    # shipped melee as incorrect) — dropped. attack_2/up fall back to these
    # via the play_action chain until a live-captured combo replaces them.
    ("attack_1_down", ["mad_01", "mad_05", "mad_09", "mad_13"], 14, False),
    ("attack_1_side", ["mar_01", "mar_05", "mar_09", "mar_13"], 14, False),
    # special (SBC): charge shimmer x2, then the two-handed firing thrust
    # (_25/_31 alternate for the hand-glow shimmer; beam pixels are stripped —
    # the engine draws the real beam from the exported sbc_* parts)
    ("special_down", ["kdn_01", "kdn_04", "kdn_01", "kdn_04", "kdn_25", "kdn_31", "kdn_25", "kdn_31"], 10, False),
    ("special_side", ["krt_01", "krt_04", "krt_01", "krt_04", "krt_25", "krt_31", "krt_25", "krt_31"], 10, False),
    ("special_up", ["kup_01", "kup_04", "kup_01", "kup_04", "kup_25", "kup_31", "kup_25", "kup_31"], 10, False),
    # fly (dodge): the REAL overworld flight sprites (user correction: the
    # mad/mar A-tap flip is Piccolo's KICK, a melee move, not his flight).
    # Early f* frames only — later ones carry stray overworld objects.
    ("fly_down", ["fdn_12", "fdn_13", "fdn_14", "fdn_15"], 16, False),
    ("fly_up", ["fup_00", "fup_08", "fup_16", "fup_24"], 16, False),
    ("fly_side", ["frt_12", "frt_13", "frt_15", "frt_16"], 16, False),
]

BEAM_SRC = "krt_49"  # full-length right-facing beam


def load_frame(tag):
    oam = open(f"{OAMDIR}/oam_{tag}.bin", "rb").read()
    vram = open(f"{OAMDIR}/objvram_{tag}.bin", "rb").read()
    pal = dec.load_palette(f"{OAMDIR}/objpal_{tag}.bin")
    return list(dec.parse_oam(oam)), vram, pal


def corpus_hud():
    """Static HUD tuples over the WHOLE corpus (per-group would eat the hero
    in 4-frame static idle groups where he never moves)."""
    frames = sorted(
        f for f in os.listdir(OAMDIR)
        if re.fullmatch(r"oam_\w+\.bin", f))
    counts = Counter()
    for fn in frames:
        oam = open(f"{OAMDIR}/{fn}", "rb").read()
        for o in dec.parse_oam(oam):
            counts[dec.obj_key(o)] += 1
    return {k for k, n in counts.items() if n > len(frames) * HUD_FRACTION}


def hero_objs(tag, hud):
    objs, vram, pal = load_frame(tag)
    live = [o for o in objs
            if dec.obj_key(o) not in hud and o["tile"] not in BEAM_TILES]
    if not live:
        raise SystemExit(f"{tag}: no live objects")
    hero = min(live, key=lambda o: (o["x"] + o["w"] / 2 - 120) ** 2
                                 + (o["y"] + o["h"] / 2 - 80) ** 2)
    hx0, hy0 = hero["x"], hero["y"]
    hx1, hy1 = hero["x"] + hero["w"], hero["y"] + hero["h"]
    keep = [o for o in live if dec.bbox_dist(o, hx0, hy0, hx1, hy1) <= GATHER]
    return keep, hero, vram, pal


def render_cell(tag, hud):
    keep, hero, vram, pal = hero_objs(tag, hud)
    ax = hero["x"] + hero["w"] // 2
    ay = hero["y"] + hero["h"]
    return dec.render(keep, vram, pal, CELL, CELL,
                      ox=PIVOT[0] - ax, oy=PIVOT[1] - ay)


def export_beam(hud):
    """Right-facing SBC parts: muzzle / one shaft segment / tip."""
    objs, vram, pal = load_frame(BEAM_SRC)
    live = [o for o in objs
            if dec.obj_key(o) not in hud and o["tile"] in BEAM_TILES]
    parts = {832: "sbc_muzzle", 848: "sbc_tip"}
    done = set()
    for o in sorted(live, key=lambda o: -(o["w"] * o["h"])):
        name = parts.get(o["tile"], "sbc_shaft")
        if name in done:
            continue
        done.add(name)
        cell = dec.render([o], vram, pal, o["w"], o["h"],
                          ox=-o["x"], oy=-o["y"])
        Image.fromarray(cell, "RGBA").save(f"{BEAM_OUT}/{name}.png")
        print(f"beam part {name}: {o['w']}x{o['h']} -> {BEAM_OUT}/{name}.png")
    missing = {"sbc_muzzle", "sbc_shaft", "sbc_tip"} - done
    if missing:
        raise SystemExit(f"beam parts missing from {BEAM_SRC}: {missing}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--analyze", action="store_true",
                    help="render picked frames to a preview contact sheet only")
    args = ap.parse_args()

    tags = []
    for _, anim_tags, _, _ in ANIMS:
        for t in anim_tags:
            if t not in tags:
                tags.append(t)
    missing = [t for t in tags if not os.path.exists(f"{OAMDIR}/oam_{t}.bin")]
    if missing:
        if args.analyze:
            print(f"WARNING: skipping uncaptured tags: {missing}")
            tags = [t for t in tags if t not in missing]
        else:
            raise SystemExit(f"uncaptured tags (rerun capture): {missing}")
    hud = corpus_hud()
    cells = {t: render_cell(t, hud) for t in tags}

    if args.analyze:
        os.makedirs(PREVIEW, exist_ok=True)
        path = f"{PREVIEW}/picked_frames.png"
        dec.contact_sheet(sorted(cells.items()), path)
        print(f"preview ({len(cells)} frames): {path}")
        return

    rows = (len(tags) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    cell_of = {}
    manifest_anims = {}
    for i, t in enumerate(tags):
        r, c = divmod(i, COLS)
        sheet.alpha_composite(Image.fromarray(cells[t], "RGBA"),
                              (c * CELL, r * CELL))
        cell_of[t] = i
    for name, anim_tags, fps, loop in ANIMS:
        manifest_anims[name] = {"frames": [cell_of[t] for t in anim_tags],
                                "fps": fps, "loop": loop}

    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    manifest = {
        "asset_id": "piccolo",
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
    print(f"sheet {COLS}x{rows} cells ({len(tags)} frames) -> {SHEET_OUT}")
    print(f"manifest -> {MANIFEST_OUT}")
    export_beam(hud)


if __name__ == "__main__":
    main()
