"""Idempotent data wiring for the Naruto world: expands the placeholder 5-enemy
roster to 12 + two Sound Four elites, adds Kidomaru and Kimimaro beside the
existing (story-critical, already tuned) Zabuza, points the world at the Konoha
rooms and obstacle props, and maps dungeon_naruto at the supplied
naruto_dungeon.mp3.

Safe to edit and re-run: naruto entries are stripped and re-added, except
Zabuza whose tuned definition is preserved verbatim (he is the chapter-5 story
boss and becomes a shop regular afterwards — see data/customers.json).

Schema matches data/enemies.json exactly: `loot` is a list of [item_id, chance]
pairs and `gold` is a top-level [min, max]. JSON indent = 1 for these files
(AGENT_GUIDE §6).

Run: .venv312/Scripts/python tools/wire_naruto_data.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
LOC = "res://assets/locations/narutodungeon/processed"
SHARD = "world_shard_naruto"


def load(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def save(name: str, obj, indent: int) -> None:
    # newline="\n": these files are LF in the repo and Python would otherwise
    # write CRLF on Windows, turning a small edit into a whole-file diff
    with open(DATA / name, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(obj, indent=indent, ensure_ascii=False) + "\n")


# id, name, hp, atk, spd, size, behavior, color, loot pairs, gold
ENEMIES = [
    ("giant_snake", "Giant Snake", 85, 15, 90, 22, "lunger", "#6858a8",
     [["chakra_crystal", 0.12], ["soldier_pill", 0.15]], [20, 40]),
    ("forest_spider", "Forest Spider", 48, 12, 85, 18, "ambusher", "#8a5a3a",
     [["makibishi_spikes", 0.25], ["kunai", 0.15]], [12, 26]),
    ("nin_panther", "Nin-Panther", 55, 14, 155, 16, "chaser", "#b07840",
     [["soldier_pill", 0.18], ["ryo_pouch", 0.12]], [16, 32]),
    ("hawk_scout", "Hawk Scout", 32, 10, 170, 14, "swooper", "#c8a870",
     [["ninja_scroll", 0.1], ["ryo_pouch", 0.15]], [10, 24]),
    ("cave_scorpion", "Cave Scorpion", 60, 15, 90, 16, "lunger", "#5a5ab0",
     [["field_medkit", 0.15], ["makibishi_spikes", 0.2]], [16, 30]),
    ("rogue_ninja", "Rogue Ninja", 45, 12, 130, 15, "chaser", "#584878",
     [["kunai", 0.2], ["shuriken", 0.3], ["smoke_bomb", 0.15]], [14, 28]),
    ("mist_swordsman", "Mist Swordsman", 72, 17, 120, 18, "lunger", "#4a7fb0",
     [["kunai", 0.25], ["field_medkit", 0.12]], [22, 42]),
    ("kunoichi_blade", "Blade Kunoichi", 62, 15, 125, 16, "chaser", "#d08040",
     [["shuriken", 0.25], ["dango_skewer", 0.2]], [18, 36]),
    ("puppet", "Battle Puppet", 55, 11, 100, 16, "shooter", "#985838",
     [["ninja_scroll", 0.12], ["kunai", 0.2]], [16, 30]),
    ("bandit_brute", "Bandit Brute", 115, 18, 60, 24, "tank", "#8a6a4a",
     [["ryo_pouch", 0.35], ["ramen_bowl", 0.2]], [30, 55]),
    ("clone_impostor", "Shadow Clone Impostor", 35, 12, 135, 15, "splitter", "#e8a030",
     [["soldier_pill", 0.12], ["ramen_bowl", 0.2]], [12, 26]),
    ("sound_ninja", "Sound Ninja", 40, 13, 120, 15, "shooter", "#788088",
     [["explosive_tag", 0.2], ["chakra_pill", 0.1]], [14, 28]),
]
# Sound Four rank-and-file that fight like mini-bosses in ordinary rooms
ELITES = [
    ("jirobou", "Jirobou", 260, 21, 55, 28, "tank", "#e8c060",
     [["chakra_pill", 0.4], ["ninja_scroll", 0.25], ["ryo_pouch", 0.5]], [70, 120]),
    ("tayuya", "Tayuya", 230, 20, 130, 22, "shooter", "#c04858",
     [["chakra_pill", 0.4], ["summoning_scroll", 0.2], ["ryo_pouch", 0.5]], [70, 120]),
]
# added beside the existing zabuza entry, which is preserved as-is
NEW_BOSSES = [
    {"id": "kidomaru", "name": "Kidomaru", "world": "naruto", "hp": 1250, "atk": 27,
     "spd": 100, "behavior": "boss_ranged", "size": 26, "color": "#b06840",
     "loot": [[SHARD, 1.0], ["summoning_scroll", 1.0], ["sharingan_fragment", 0.5]],
     "gold": [2200, 2800],
     "attacks": ["spider_web_net", "golden_arrow", "spider_drop", "sticky_barrage"],
     "telegraph": 0.6, "phases": 2},
    {"id": "kimimaro", "name": "Kimimaro", "world": "naruto", "hp": 1500, "atk": 31,
     "spd": 120, "behavior": "boss_charger", "size": 28, "color": "#e0e0e8",
     "loot": [[SHARD, 1.0], ["sannin_token", 1.0], ["training_weights", 0.5]],
     "gold": [2600, 3200],
     "attacks": ["bone_lance", "dance_of_camellia", "willow_barrage", "bone_forest"],
     "telegraph": 0.5, "phases": 3},
]
ROTATION = ["zabuza", "kidomaru", "kimimaro"]


def enemy_entry(eid, name, hp, atk, spd, size, behavior, color, loot, gold):
    return {"id": eid, "name": name, "world": "naruto", "hp": hp, "atk": atk,
            "spd": spd, "behavior": behavior, "size": size, "color": color,
            "loot": loot, "gold": gold}


def wire_enemies() -> None:
    d = load("enemies.json")
    d["enemies"] = [e for e in d["enemies"] if e.get("world") != "naruto"]
    for spec in ENEMIES + ELITES:
        d["enemies"].append(enemy_entry(*spec))
    kept = [b for b in d["bosses"] if b.get("world") != "naruto" or b.get("id") == "zabuza"]
    d["bosses"] = kept + NEW_BOSSES
    save("enemies.json", d, 1)
    print(f"  enemies: {len(ENEMIES)} + {len(ELITES)} elite; bosses: zabuza + "
          f"{[b['id'] for b in NEW_BOSSES]}")


def wire_world() -> None:
    d = load("worlds.json")
    ws = d["worlds"] if isinstance(d, dict) else d
    for w in ws:
        if w.get("id") != "naruto":
            continue
        w["location"] = "Hidden Leaf Forest"
        w["boss"] = "zabuza"
        w["boss_rotation"] = ROTATION
        w["enemies"] = [e[0] for e in ENEMIES] + [e[0] for e in ELITES]
        w["dungeon_desc"] = ("Training grounds and forest road outside the village wall, "
                             "quiet in the way that means someone is watching.")
        w["room_backgrounds"] = {
            "start": [f"{LOC}/start_gate.png"],
            "combat": [f"{LOC}/combat_forest.png", f"{LOC}/combat_grove.png",
                       f"{LOC}/combat_cliffs.png"],
            "treasure": [f"{LOC}/treasure_cave.png"],
            "boss": [f"{LOC}/boss_ravine.png"],
        }
        w["obstacle_props"] = [f"{LOC}/prop_post.png", f"{LOC}/prop_rock.png",
                               f"{LOC}/prop_stump.png"]
        w.pop("obstacle_texture", None)
        w.pop("obstacle_style", None)
        print(f"  world: {len(w['enemies'])} enemies, rotation {w['boss_rotation']}")
    save("worlds.json", d, 1)


def wire_music() -> None:
    """The supplied override is named naruto_dungeon.mp3, not dungeon_naruto.
    The manifest's `file` field exists for exactly this, so point at it rather
    than renaming a user-supplied file.

    Surgical text edit, not a json round-trip: this file is hand-formatted with
    compact inline arrays that json.dumps would reflow into a huge diff."""
    p = DATA / "music_manifest.json"
    text = p.read_text(encoding="utf-8")
    old = '"dungeon_naruto": {"file": "dungeon_naruto"'
    new = '"dungeon_naruto": {"file": "naruto_dungeon"'
    if new in text:
        print("  music: already wired")
        return
    if old not in text:
        raise SystemExit(f"music_manifest.json: could not find {old!r} to patch")
    with open(p, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text.replace(old, new))
    print("  music: dungeon_naruto -> naruto_dungeon.mp3")


# slug -> display name for the customers cut by prep_naruto_world.prep_customers
NEW_CUSTOMERS = {
    "third_hokage": "Third Hokage", "iruka": "Iruka", "asuma": "Asuma",
    "might_guy": "Might Guy", "misumi": "Misumi", "itachi": "Itachi",
    "dosu": "Dosu", "kin": "Kin", "zaku": "Zaku", "shikamaru": "Shikamaru",
    "ino": "Ino", "akamaru": "Akamaru", "shino": "Shino", "hinata": "Hinata",
    "konohamaru": "Konohamaru", "neji": "Neji", "rock_lee": "Rock Lee",
    "teuchi": "Teuchi", "tazuna": "Tazuna", "mizuki": "Mizuki",
    "mist_ninja": "Mist Ninja", "rain_ninja": "Rain Ninja",
    "chunin_examiner": "Chunin Examiner",
}


def wire_customers() -> None:
    """customer_visuals.json is indent=2 (not 1 like the others) — writing it
    with the wrong indent turns an 85-line change into a 1400-line diff."""
    d = load("customer_visuals.json")
    pool = d["pool"]
    existing = {p.get("slug") for p in pool}
    added = 0
    for slug, name in NEW_CUSTOMERS.items():
        if slug in existing:
            continue
        pool.append({
            "slug": slug, "name": name, "world": "naruto",
            "static": f"res://assets/franchises/naruto/processed/customers/{slug}.png",
        })
        added += 1
    save("customer_visuals.json", d, 2)
    print(f"  customers: +{added} (pool now {len(pool)})")


if __name__ == "__main__":
    print("enemies:"); wire_enemies()
    print("world:");   wire_world()
    print("music:");   wire_music()
    print("customers:"); wire_customers()
    print("done")
