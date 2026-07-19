"""Wire the Zelda world data: Hyrule dungeon config, the MC enemy roster +
three-boss rotation, Link's bomb special, and the Minish Cap item catalog.
Idempotent — safe to re-run.

Run: .venv312/Scripts/python tools/wire_zelda_data.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
LOC = "res://assets/locations/zeldadungeon/processed"


def load(name: str) -> dict:
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def save(name: str, data: dict) -> None:
    (DATA / name).write_text(json.dumps(data, indent=1, sort_keys=False), encoding="utf-8")
    print(f"  wrote {name}")


# --- worlds.json -----------------------------------------------------------
worlds = load("worlds.json")
zw = next(w for w in worlds["worlds"] if w["id"] == "zelda")
zw["location"] = "Hyrule"
zw["boss"] = "big_green_chuchu"
zw["boss_rotation"] = ["big_green_chuchu", "big_blue_chuchu", "vaati"]
zw["enemies"] = ["keese", "octorok", "chuchu_green", "chuchu_blue", "rope", "leever",
                 "ghini", "keaton", "spiked_beetle", "moblin", "stalfos", "darknut"]
zw["dungeon_desc"] = "Ranch lanes and castle gardens, too quiet since the wind changed."
zw["room_backgrounds"] = {
    "start": [f"{LOC}/start_ranch.png"],
    "combat": [f"{LOC}/combat_orchard.png", f"{LOC}/combat_pens.png", f"{LOC}/combat_fields.png"],
    "treasure": [f"{LOC}/treasure_garden.png"],
    "boss": [f"{LOC}/boss_courtyard.png"],
}
zw["obstacle_texture"] = f"{LOC}/rocks.png"
zw["obstacle_style"] = "grid"
zw["market_goods"] = ["red_potion", "green_potion", "blue_potion", "deku_nut",
                      "wake_up_mushroom", "wooden_shield", "zelda_boomerang", "bomb_bag",
                      "remote_bomb", "fairy_bottle", "rupee", "zelda_lantern",
                      "pegasus_boots", "gust_jar", "rocs_cape", "white_sword",
                      "hylian_shield", "heart_container", "kinstone"]
save("worlds.json", worlds)

# --- enemies.json ----------------------------------------------------------
enemies = load("enemies.json")
enemies["enemies"] = [e for e in enemies["enemies"] if e.get("world") != "zelda"]
enemies["bosses"] = [b for b in enemies["bosses"] if b.get("world") != "zelda"]
enemies["enemies"] += [
    {"id": "keese", "name": "Keese", "world": "zelda", "hp": 20, "atk": 8, "spd": 145,
     "behavior": "swooper", "size": 12, "color": "#383858",
     "loot": [["rupee", 0.4]], "gold": [6, 14]},
    {"id": "octorok", "name": "Octorok", "world": "zelda", "hp": 35, "atk": 11, "spd": 75,
     "behavior": "shooter", "size": 15, "color": "#c85858",
     "loot": [["rupee", 0.35], ["deku_nut", 0.15]], "gold": [10, 20]},
    {"id": "chuchu_green", "name": "Green ChuChu", "world": "zelda", "hp": 30, "atk": 9, "spd": 70,
     "behavior": "creeper", "size": 14, "color": "#48c858",
     "loot": [["green_potion", 0.15], ["rupee", 0.3]], "gold": [8, 16]},
    {"id": "chuchu_blue", "name": "Blue ChuChu", "world": "zelda", "hp": 55, "atk": 13, "spd": 80,
     "behavior": "chaser", "size": 14, "color": "#58b8e8",
     "loot": [["blue_potion", 0.12], ["rupee", 0.3]], "gold": [12, 24]},
    {"id": "rope", "name": "Rope", "world": "zelda", "hp": 28, "atk": 10, "spd": 150,
     "behavior": "lunger", "size": 13, "color": "#58a838",
     "loot": [["rupee", 0.3]], "gold": [8, 16]},
    {"id": "leever", "name": "Leever", "world": "zelda", "hp": 40, "atk": 12, "spd": 65,
     "behavior": "creeper", "size": 14, "color": "#b04858",
     "loot": [["rupee", 0.3], ["green_potion", 0.1]], "gold": [10, 20]},
    {"id": "ghini", "name": "Ghini", "world": "zelda", "hp": 50, "atk": 12, "spd": 90,
     "behavior": "shy_ghost", "size": 16, "color": "#d8d8e8",
     "loot": [["rupee", 0.3], ["wake_up_mushroom", 0.12]], "gold": [12, 24]},
    {"id": "keaton", "name": "Keaton", "world": "zelda", "hp": 60, "atk": 14, "spd": 130,
     "behavior": "chaser", "size": 16, "color": "#e8b840",
     "loot": [["rupee", 0.5], ["kinstone", 0.15]], "gold": [20, 40]},
    {"id": "spiked_beetle", "name": "Spiked Beetle", "world": "zelda", "hp": 70, "atk": 13, "spd": 55,
     "behavior": "tank", "size": 15, "color": "#4878c8",
     "loot": [["rupee", 0.3], ["kinstone", 0.1]], "gold": [12, 26]},
    {"id": "moblin", "name": "Spear Moblin", "world": "zelda", "hp": 80, "atk": 15, "spd": 85,
     "behavior": "shooter", "size": 20, "color": "#487898",
     "loot": [["rupee", 0.3], ["remote_bomb", 0.12], ["red_potion", 0.1]], "gold": [18, 36]},
    {"id": "stalfos", "name": "Stalfos", "world": "zelda", "hp": 75, "atk": 16, "spd": 100,
     "behavior": "chaser", "size": 17, "color": "#8898b8",
     "loot": [["rupee", 0.3], ["small_key", 0.12], ["remote_bomb", 0.1]], "gold": [16, 32]},
    {"id": "darknut", "name": "Darknut", "world": "zelda", "hp": 220, "atk": 19, "spd": 70,
     "behavior": "tank", "size": 24, "color": "#b8b8c8",
     "loot": [["white_sword", 0.08], ["hylian_shield", 0.06], ["red_potion", 0.25]], "gold": [60, 120]},
]
enemies["bosses"] += [
    {"id": "big_green_chuchu", "name": "Big Green ChuChu", "world": "zelda",
     "hp": 950, "atk": 22, "spd": 85, "behavior": "boss_charger", "size": 44, "color": "#48c858",
     "loot": [["world_shard_zelda", 1.0], ["heart_container", 1.0], ["element_earth", 1.0]],
     "gold": [1500, 1900], "attacks": ["gel_slam", "gel_rain", "chu_charge", "split_bounce"],
     "telegraph": 0.65},
    {"id": "big_blue_chuchu", "name": "Big Blue ChuChu", "world": "zelda",
     "hp": 1150, "atk": 25, "spd": 80, "behavior": "boss_tank", "size": 44, "color": "#58b8e8",
     "loot": [["world_shard_zelda", 1.0], ["heart_container", 1.0], ["element_water", 1.0]],
     "gold": [1700, 2200], "attacks": ["gel_slam", "spark_ring", "chu_charge", "storm_call"],
     "telegraph": 0.6},
    {"id": "vaati", "name": "Vaati Transfigured", "world": "zelda",
     "hp": 1350, "atk": 28, "spd": 95, "behavior": "boss_psychic", "size": 52, "color": "#6858c0",
     "loot": [["world_shard_zelda", 1.0], ["heart_container", 1.0], ["element_wind", 1.0], ["element_fire", 0.8]],
     "gold": [2000, 2600], "attacks": ["eye_beam", "wind_gale", "shadow_dive", "orb_barrage"],
     "telegraph": 0.6},
]
save("enemies.json", enemies)

# --- items.json ------------------------------------------------------------
items = load("items.json")
NEW = [
    {"id": "gust_jar", "name": "Gust Jar", "world": "zelda", "category": "accessory",
     "slot": "accessory", "stats": {"spd": 2}, "price": 1200, "tags": ["tool", "wind"],
     "appeal": {"retro": 1.0},
     "desc": "Inhales webs, dust, and unsuspecting ChuChus. Exhales them with interest."},
    {"id": "cane_of_pacci", "name": "Cane of Pacci", "world": "zelda", "category": "accessory",
     "slot": "accessory", "stats": {"atk": 3}, "price": 1400, "tags": ["tool", "cane"],
     "appeal": {"retro": 1.0},
     "desc": "Flips pots, foes, and your worldview upside down."},
    {"id": "mole_mitts", "name": "Mole Mitts", "world": "zelda", "category": "accessory",
     "slot": "accessory", "stats": {"def": 2}, "price": 800, "tags": ["tool", "glove"],
     "appeal": {"cozy": 1.0},
     "desc": "Dig through anything. Manicure not included."},
    {"id": "zelda_lantern", "name": "Lantern", "world": "zelda", "category": "accessory",
     "slot": "accessory", "stats": {"def": 1}, "price": 500, "tags": ["tool", "light"],
     "appeal": {"cozy": 1.0},
     "desc": "Keeps the dark exactly one lantern-width away."},
    {"id": "pegasus_boots", "name": "Pegasus Boots", "world": "zelda", "category": "accessory",
     "slot": "accessory", "stats": {"spd": 5}, "price": 950, "tags": ["boots"],
     "appeal": {"modern": 1.0},
     "desc": "Run so fast the scenery apologizes."},
    {"id": "rocs_cape", "name": "Roc's Cape", "world": "zelda", "category": "accessory",
     "slot": "accessory", "stats": {"spd": 3, "def": 2}, "price": 1600, "tags": ["cape"],
     "appeal": {"modern": 1.0},
     "desc": "Jump. Higher. No — higher than that."},
    {"id": "white_sword", "name": "White Sword", "world": "zelda", "category": "weapon",
     "weapon_type": "sword_shield", "stats": {"atk": 9}, "price": 1500, "tags": ["sword"],
     "appeal": {"retro": 1.0},
     "desc": "Three Picori blessings and a fresh coat of courage."},
    {"id": "four_sword", "name": "Four Sword", "world": "zelda", "category": "weapon",
     "weapon_type": "sword_shield", "stats": {"atk": 13}, "price": 2600, "tags": ["sword"],
     "appeal": {"retro": 1.0, "modern": 1.0},
     "desc": "Splits its wielder into four. Splits the bill into one."},
    {"id": "remote_bomb", "name": "Remote Bomb", "world": "zelda", "category": "consumable",
     "effect": {"aoe_damage": 30}, "price": 90, "tags": ["bomb"],
     "appeal": {"modern": 1.0},
     "desc": "Boom on your schedule. Mostly on your schedule."},
    {"id": "wake_up_mushroom", "name": "Wake-Up Mushroom", "world": "zelda", "category": "consumable",
     "effect": {"heal": 25, "meter": 10}, "price": 60, "tags": ["mushroom"],
     "appeal": {"cozy": 1.0},
     "desc": "Smells the way an alarm clock sounds."},
    {"id": "kinstone", "name": "Kinstone Piece", "world": "zelda", "category": "treasure",
     "price": 120, "tags": ["valuable", "charm"], "appeal": {"cozy": 1.0, "retro": 1.0},
     "desc": "Half of a promise. Fuse it with a stranger's and fate does the paperwork."},
    {"id": "big_key", "name": "Big Key", "world": "zelda", "category": "treasure",
     "price": 400, "tags": ["key"], "appeal": {"retro": 1.0},
     "desc": "Too big for pockets. Opens the one door that matters."},
    {"id": "element_earth", "name": "Earth Element", "world": "zelda", "category": "treasure",
     "price": 3000, "tags": ["element", "valuable"], "appeal": {"retro": 1.0},
     "desc": "The ground hums politely whenever it passes."},
    {"id": "element_fire", "name": "Fire Element", "world": "zelda", "category": "treasure",
     "price": 3000, "tags": ["element", "valuable"], "appeal": {"retro": 1.0},
     "desc": "Warm to the touch. Warmer to the argument."},
    {"id": "element_water", "name": "Water Element", "world": "zelda", "category": "treasure",
     "price": 3000, "tags": ["element", "valuable"], "appeal": {"retro": 1.0},
     "desc": "Never spills. Judges those who do."},
    {"id": "element_wind", "name": "Wind Element", "world": "zelda", "category": "treasure",
     "price": 3000, "tags": ["element", "valuable"], "appeal": {"retro": 1.0},
     "desc": "Restless in the display case. Checks the window."},
]
have = {i["id"] for i in items["items"]}
items["items"] = [i for i in items["items"] if i["id"] not in {n["id"] for n in NEW}]
items["items"] += NEW
save("items.json", items)

# --- heroes.json -----------------------------------------------------------
heroes = load("heroes.json")
link = next(h for h in heroes["heroes"] if h["id"] == "link")
link["combat"]["special"] = {"kind": "bomb", "name": "Bomb", "dmg": 32, "radius": 62,
                             "fuse": 2.0, "cost": 30}
save("heroes.json", heroes)

# --- story_scenes.json -----------------------------------------------------
scenes = (DATA / "story_scenes.json").read_text(encoding="utf-8")
scenes2 = scenes.replace("Gohma's eye is NOT merchandise", "Vaati's eye is NOT merchandise")
if scenes2 != scenes:
    (DATA / "story_scenes.json").write_text(scenes2, encoding="utf-8")
    print("  story_scenes.json: Gohma line -> Vaati")
print("done")
