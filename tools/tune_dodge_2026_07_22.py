"""Playtest 2026-07-22: dodge dashes travel too far on every roll hero —
bring them in line with Goku/Piccolo's fly (distance 60), which the user
called out as the reference feel. Named by the user: Sora, Mario, Luigi,
Link, plus the new Pokémon pair. Naruto's vanish and Cloud's guard were not
named and stay untouched. Idempotent.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
path = ROOT / "data/heroes.json"
data = json.loads(path.read_text(encoding="utf-8"))

# round 2 (same day): naruto's vanish joins the 60 club at the user's request
TARGET = {"sora": 60, "mario": 60, "luigi": 60, "link": 60, "pikachu": 60,
          "charmander": 60, "naruto": 60}
for h in data["heroes"]:
    if h["id"] in TARGET:
        old = h["combat"]["dodge"].get("distance")
        h["combat"]["dodge"]["distance"] = TARGET[h["id"]]
        print(f"  {h['id']:<12} dodge distance {old} -> {TARGET[h['id']]}")

with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
print("heroes.json updated")
