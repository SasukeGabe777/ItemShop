"""Point the dragon_ball roster at enemies that actually exist in Legacy of
Goku II (art prepped by prep_dbz_enemies.py):

- saibaman -> dbz_wolf (Wilderness Wolf), frieza_soldier -> sabertooth_tiger
  (Saber-Toothed Tiger): LoG 1 enemies with no LoG II art source; stats kept.
- boss great_ape_vegeta -> perfect_cell (Perfect Cell), stats kept — the
  dungeon's boss room background is already the captured Cell Games Arena.

Only data/enemies.json + data/worlds.json reference these ids (verified by
grep). Idempotent. Run: .venv312/Scripts/python tools/wire_dbz_enemy_data.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

RENAMES = {
    "saibaman": ("dbz_wolf", "Wilderness Wolf"),
    "frieza_soldier": ("sabertooth_tiger", "Saber-Toothed Tiger"),
    "great_ape_vegeta": ("perfect_cell", "Perfect Cell"),
}


def save(path: Path, obj, indent: int) -> None:
    path.write_text(json.dumps(obj, indent=indent, ensure_ascii=False) + "\n",
                    encoding="utf-8", newline="\n")


def main() -> None:
    enemies = json.loads((DATA / "enemies.json").read_text(encoding="utf-8"))
    changed = 0
    for section in ("enemies", "bosses"):
        for e in enemies.get(section, []):
            eid = str(e.get("id", ""))
            if eid in RENAMES:
                e["id"], e["name"] = RENAMES[eid]
                changed += 1
    save(DATA / "enemies.json", enemies, 1)

    worlds = json.loads((DATA / "worlds.json").read_text(encoding="utf-8"))
    for w in worlds.get("worlds", []):
        if w.get("id") != "dragon_ball":
            continue
        w["enemies"] = [RENAMES.get(e, (e,))[0] for e in w.get("enemies", [])]
        if str(w.get("boss", "")) in RENAMES:
            w["boss"] = RENAMES[str(w["boss"])][0]
    save(DATA / "worlds.json", worlds, 1)
    print(f"renamed {changed} enemy/boss defs; dragon_ball roster:",
          [w["enemies"] for w in worlds["worlds"] if w["id"] == "dragon_ball"][0],
          "boss:", [w["boss"] for w in worlds["worlds"] if w["id"] == "dragon_ball"][0])


if __name__ == "__main__":
    main()
