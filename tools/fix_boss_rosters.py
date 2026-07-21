"""Refile misplaced entries between the enemies/bosses lists in enemies.json.

Two verified defects (NEXT_TASKS P1, confirmed by cross-checking every world's
"enemies" pool and "boss_rotation" against the definition lists):
- guard_armor + darkside sat in the ENEMIES list while kingdom_hearts'
  boss_rotation referenced them as bosses -> boss rooms got empty defs.
- Ten FF6 monsters sat in the BOSSES list while final_fantasy's enemy pool
  referenced them as regular enemies -> normal rooms drew empty defs whenever
  the run pool picked them.

Idempotent: entries are moved by id; rerunning is a no-op.
"""
import json

PATH = "data/enemies.json"
TO_BOSSES = ["guard_armor", "darkside"]
TO_ENEMIES = ["ghost", "giant_rat", "guard_hound", "imperial_shadow",
              "soldier_3rd", "sand_worm", "ahriman", "malboro",
              "magitek_armor", "behemoth"]

def main():
    doc = json.load(open(PATH, encoding="utf-8"))
    enemies, bosses = doc["enemies"], doc["bosses"]
    for eid in TO_BOSSES:
        hit = [x for x in enemies if x["id"] == eid]
        if hit:
            enemies.remove(hit[0])
            bosses.append(hit[0])
            print("enemy -> boss:", eid)
    for eid in TO_ENEMIES:
        hit = [x for x in bosses if x["id"] == eid]
        if hit:
            bosses.remove(hit[0])
            enemies.append(hit[0])
            print("boss -> enemy:", eid)
    with open(PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write("\n")

if __name__ == "__main__":
    main()
