"""Pass 2 over the ca249d7 OAM hero sheets — fixes the two player-visible
regressions from that merge (verified against the unique-pose sheets and the
in-game look):

Sora ("attack animation completely broken"):
- The grafted old-rip attack cells (attack_1/2/3) were pasted at native rip
  scale: ~1.2x the captured field sprite, with slash arcs clipped at the cell
  edge. Mid-combo Sora visibly ballooned. Fix: rescale those cells in place
  around the pivot to match the field sprite's body height.
- attack_1_side pointed at the captured battle "swing" (satk_00/07/19) which
  is actually Sora's ready-stance shuffle — no swing arc at all (the battle
  captures never landed a real slash; see the 13F/Strike Raid report). Fix:
  drop attack_1_side so all three combo hits use the (rescaled) real swing
  arcs, and repurpose the stance shuffle as the "special" cast animation —
  it reads as gathering power under the engine's Magic Burst FX.

Mario ("movement was better before"):
- The walk cycles included capture transition junk: back-turned turning
  frames at the start of every cycle and two arm-raised celebration frames in
  walk_down (verified on unique_mw*.png). Fix: manifest-only — repoint the
  cycles at the correct-facing cells already on the sheet (mwdn_09/11/14,
  mwup_09/11/14/21, mwrt_09/11/14/21/24; down plays as a pendulum).

Run: .venv312/Scripts/python tools/fix_hero_sheets_pass2.py
(idempotent: skips the Sora rescale if the sheet was already rescaled)
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

SORA_SHEET = ROOT / "assets/franchises/kingdom_hearts/processed/sheets/sora.png"
SORA_MANIFEST = ROOT / "assets/franchises/kingdom_hearts/manifests/sora.json"
MARIO_MANIFEST = ROOT / "assets/franchises/mario/manifests/mario.json"

RIP_CELLS = list(range(39, 48))   # grafted attack_1/2/3 cells
STANCE_CELLS = [30, 31, 32]       # satk ready-stance shuffle
FIELD_BODY_H = 42                 # captured walk ink height
RIP_BODY_H = 50                   # rip attack body ink height
SCALE = FIELD_BODY_H / RIP_BODY_H


def ink_h(cell: Image.Image) -> int:
    a = np.array(cell)
    ys = np.where(a[..., 3] > 0)[0]
    return int(ys.max() - ys.min() + 1) if len(ys) else 0


def fix_sora() -> None:
    doc = json.loads(SORA_MANIFEST.read_text(encoding="utf-8"))
    g, pv = doc["grid"], doc["pivot"]
    fw, fh, cols = g["frame_width"], g["frame_height"], g["columns"]
    sheet = Image.open(SORA_SHEET).convert("RGBA")

    heights = []
    for idx in RIP_CELLS:
        r, c = divmod(idx, cols)
        heights.append(ink_h(sheet.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))))
    if max(heights) <= FIELD_BODY_H + 4:
        print(f"sora: rip cells already rescaled (max ink {max(heights)}), skipping sheet edit")
    else:
        for idx in RIP_CELLS:
            r, c = divmod(idx, cols)
            box = (c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)
            cell = sheet.crop(box)
            scaled = cell.resize((round(fw * SCALE), round(fh * SCALE)), Image.LANCZOS)
            # keep the pivot fixed: paste so pivot*SCALE lands on the pivot
            off = (round(pv[0] * (1 - SCALE)), round(pv[1] * (1 - SCALE)))
            blank = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
            blank.alpha_composite(scaled, off)
            # crisp alpha after LANCZOS
            a = np.array(blank)
            a[..., 3] = np.where(a[..., 3] > 96, 255, 0)
            sheet.paste(Image.fromarray(a), box[:2])
        sheet.save(SORA_SHEET)
        print(f"sora: rescaled {len(RIP_CELLS)} rip attack cells by {SCALE:.2f}")

    anims = doc["animations"]
    anims.pop("attack_1_side", None)            # stance shuffle is not a swing
    anims["special"] = {"frames": STANCE_CELLS, "fps": 8, "loop": False}
    SORA_MANIFEST.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n",
                             encoding="utf-8", newline="\n")
    print(f"sora: manifest -> attacks use rescaled rip arcs; special = stance shuffle")


def fix_mario() -> None:
    doc = json.loads(MARIO_MANIFEST.read_text(encoding="utf-8"))
    anims = doc["animations"]
    # cell layout from build_mario_from_oam.py tag order (see its WALK_* lists)
    anims["walk_down"]["frames"] = [6, 7, 8, 7]          # mwdn_09/11/14 pendulum
    anims["walk_up"]["frames"] = [14, 15, 16, 17]        # mwup_09/11/14/21
    anims["walk_side"]["frames"] = [22, 23, 24, 25, 26]  # mwrt_09/11/14/21/24
    for k in ("walk_down", "walk_up", "walk_side"):
        anims[k]["fps"] = 10
    MARIO_MANIFEST.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n",
                              encoding="utf-8", newline="\n")
    print("mario: walk cycles repointed to correct-facing cells (turn/celebration junk dropped)")


if __name__ == "__main__":
    fix_sora()
    fix_mario()
