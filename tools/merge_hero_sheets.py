"""Merge OAM-captured hero sheets (real-game walks/idles/rolls) with the
attack rows of the previous sheet-ripped manifests, producing the shipping
sheet + manifest per hero.

Why merge: the capture agent could not reach battles for every move (KH's
level-55 save is cutscene-locked on 13F; M&L's save sits in a quiet pre-boss
room), so captured sets lack some attacks. The old manifests' attack cells are
kept — the engine's play_action fallback chain (attack_N_<dir> -> attack_N_side
-> attack_N) blends both sources seamlessly. Old DIAGONAL walk variants are
deliberately dropped: mixing old diagonal art with new cardinal walks reads as
two different characters.

Old cells are pasted pivot-aligned into the new grid (pivots differ per sheet).
"""
import json
import os
from PIL import Image

MERGES = [
    {
        "world": "kingdom_hearts", "hero": "sora",
        "keep_old": ["attack_1", "attack_2", "attack_3"],
    },
    {
        "world": "mario", "hero": "mario",
        "keep_old": ["attack_1_down", "attack_2_down",
                     "attack_1_side", "attack_2_side"],
    },
]

def cell_image(sheet, grid, idx):
    w, h = grid["frame_width"], grid["frame_height"]
    c, r = idx % grid["columns"], idx // grid["columns"]
    return sheet.crop((c * w, r * h, (c + 1) * w, (r + 1) * h))

def main():
    for m in MERGES:
        wid, hid = m["world"], m["hero"]
        stage = f"tools/rom_ref/out/staging/{wid}"
        new_doc = json.load(open(f"{stage}/{hid}.json", encoding="utf-8"))
        new_sheet = Image.open(f"{stage}/{hid}_sheet.png").convert("RGBA")
        old_doc = json.load(open(f"assets/franchises/{wid}/manifests/{hid}.json", encoding="utf-8"))
        old_sheet_path = old_doc["sheet"].replace("res://", "")
        old_sheet = Image.open(old_sheet_path).convert("RGBA")

        ng, og = new_doc["grid"], old_doc["grid"]
        npv, opv = new_doc["pivot"], old_doc["pivot"]
        cols = ng["columns"]
        cw, ch = ng["frame_width"], ng["frame_height"]
        # start appending after the last cell the new animations reference
        used = max(max(a["frames"]) for a in new_doc["animations"].values()) + 1

        cells = []          # (old_idx -> new_idx) appended in order
        cell_of = {}
        anims = dict(new_doc["animations"])
        for name in m["keep_old"]:
            old_anim = old_doc["animations"][name]
            frames = []
            for oidx in old_anim["frames"]:
                if oidx not in cell_of:
                    cell_of[oidx] = used
                    cells.append(oidx)
                    used += 1
                frames.append(cell_of[oidx])
            anims[name] = {"frames": frames, "fps": old_anim["fps"],
                           "loop": old_anim.get("loop", False)}

        rows = (used + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
        sheet.alpha_composite(new_sheet, (0, 0))
        # pivot-aligned paste: old pivot lands on new pivot in each cell
        ox, oy = npv[0] - opv[0], npv[1] - opv[1]
        for i, oidx in enumerate(cells):
            idx = used - len(cells) + i
            src = cell_image(old_sheet, og, oidx)
            c, r = idx % cols, idx // cols
            sheet.alpha_composite(src, (c * cw + max(0, ox), r * ch + max(0, oy)))

        out_sheet = f"assets/franchises/{wid}/processed/sheets/{hid}.png"
        os.makedirs(os.path.dirname(out_sheet), exist_ok=True)
        sheet.save(out_sheet)
        manifest = {
            "asset_id": hid,
            "sheet": "res://" + out_sheet.replace("\\", "/"),
            "native_scale": new_doc.get("native_scale", 1),
            "display_scale": new_doc.get("display_scale", 1),
            "pivot": npv,
            "grid": {"frame_width": cw, "frame_height": ch,
                     "columns": cols, "rows": rows},
            "animations": anims,
        }
        with open(f"assets/franchises/{wid}/manifests/{hid}.json", "w",
                  encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, indent=1, ensure_ascii=False)
            f.write("\n")
        print(f"{hid}: {used} cells ({len(cells)} grafted from old sheet), "
              f"{len(anims)} anims -> {out_sheet}")

if __name__ == "__main__":
    main()
