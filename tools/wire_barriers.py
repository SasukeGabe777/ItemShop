"""Wire real-game barrier strip art into worlds.json ("barriers" key).

Idempotent: rewrites each listed world's "barriers" entry in place. Strips are
cut by tools/cut_barrier_strips.py (FF/Naruto, from raw map rips) and the
BizHawk BG-layer pipeline (tools/rom_ref/) for ROM-available worlds.
dungeon.gd tiles "h" strips along horizontal obstacle runs and "v" strips
along vertical ones, one variant per rect.
"""
import json

WORLDS = "data/worlds.json"

BARRIERS = {
    "final_fantasy": {
        "h": [
            "res://assets/locations/ffdungeon/processed/barrier_fence.png",
            "res://assets/locations/ffdungeon/processed/barrier_hedge.png",
        ],
        "v": [
            "res://assets/locations/ffdungeon/processed/barrier_ruinwall.png",
        ],
    },
    # naruto was tried with cliff/palisade strips and REVERTED: its painted
    # rooms already draw their own borders, and opaque texture rects pasted
    # over painted canopy/cliffs read as patches (probe blk_naruto_room0/2,
    # 2026-07-20). Scatter props suit that world; None = remove the key.
    "naruto": None,
}

def main():
    data = json.load(open(WORLDS, encoding="utf-8"))
    worlds = data["worlds"] if isinstance(data, dict) and "worlds" in data else data
    for w in worlds:
        if w["id"] in BARRIERS:
            if BARRIERS[w["id"]] is None:
                if w.pop("barriers", None) is not None:
                    print("removed barriers:", w["id"])
            else:
                w["barriers"] = BARRIERS[w["id"]]
                print("wired barriers:", w["id"])
    with open(WORLDS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")

if __name__ == "__main__":
    main()
