"""Wire the Pokémon world data: Charmander hero, Pikachu's Discharge nova,
the three-boss rotation (Latios -> Ho-Oh -> Mewtwo), and the world entry's
heroes list. Idempotent: strips this script's entries and re-adds them.

Data files use indent=1 and LF endings (AGENT_GUIDE §6) — do not change.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def load(name):
    return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))


def save(name, data):
    text = json.dumps(data, indent=1, ensure_ascii=False)
    with open(ROOT / "data" / name, "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n")


# --- heroes.json -----------------------------------------------------------
heroes = load("heroes.json")
hlist = heroes["heroes"]

pikachu = next(h for h in hlist if h["id"] == "pikachu")
pikachu["combat"]["special"] = {
    "kind": "nova",
    "name": "Discharge",
    "dmg": 26,
    "radius": 48,
    "cost": 30,
    "sheet": "res://assets/franchises/pokemon/processed/pikachu_discharge.png",
    "frames": 8,
    "fps": 12,
}

hlist[:] = [h for h in hlist if h["id"] != "charmander"]
charmander = {
    "id": "charmander",
    "name": "Charmander",
    "world": "pokemon",
    "weapon_type": "claw",
    "color": "#f08030",
    "base_stats": {"hp": 120, "atk": 15, "def": 7, "spd": 130},
    "combat": {
        "basic": {"hits": 3, "dmg": [9, 9, 15], "range": 20, "arc": 80},
        "special": {
            "kind": "nova",
            "name": "Fire Spin",
            "dmg": 30,
            "radius": 52,
            "cost": 32,
            "sheet": "res://assets/franchises/pokemon/processed/charmander_firespin.png",
            "frames": 15,
            "fps": 14,
        },
        "dodge": {"kind": "roll", "distance": 85, "iframes": 0.35},
        "finisher": {"name": "Flamethrower", "dmg": 100, "radius": 105},
    },
    "default_equipment": {},
    "hire_cost": 1500,
    "bio": "Keeps the shop's forge lit and the tea perpetually over-steeped. The tail flame doubles as a mood ring.",
    "guild_line": "Char! (Patch: 'Mind the tail near the plushie shelf. We've had incidents.')",
}
idx = next(i for i, h in enumerate(hlist) if h["id"] == "pikachu")
hlist.insert(idx + 1, charmander)
save("heroes.json", heroes)
print("heroes.json: pikachu nova special + charmander added")

# --- enemies.json ----------------------------------------------------------
enemies = load("enemies.json")
bosses = enemies["bosses"]
bosses[:] = [b for b in bosses if b["id"] not in ("latios", "ho_oh")]

latios = {
    "id": "latios",
    "name": "Latios",
    "world": "pokemon",
    "hp": 1200,
    "atk": 28,
    "spd": 170,
    "behavior": "boss_charger",
    "size": 24,
    "color": "#4890d8",
    "loot": [["world_shard_pkmn", 1.0], ["rare_candy", 0.8], ["ultra_ball", 0.6]],
    "gold": [3000, 3800],
    "attacks": ["zen_headbutt", "dragon_pulse", "giga_impact", "luster_purge"],
    "telegraph": 0.55,
}
ho_oh = {
    "id": "ho_oh",
    "name": "Ho-Oh",
    "world": "pokemon",
    "hp": 1500,
    "atk": 31,
    "spd": 120,
    "behavior": "boss_tank",
    "size": 34,
    "color": "#e83820",
    "loot": [["world_shard_pkmn", 1.0], ["rare_candy", 1.0], ["lucky_egg", 0.6]],
    "gold": [3600, 4400],
    "attacks": ["sacred_fire", "air_slash", "sky_attack", "whirlwind"],
    "telegraph": 0.65,
}
midx = next(i for i, b in enumerate(bosses) if b["id"] == "mewtwo")
bosses.insert(midx, ho_oh)
bosses.insert(midx, latios)
save("enemies.json", enemies)
print("enemies.json: latios + ho_oh bosses added before mewtwo")

# --- worlds.json -----------------------------------------------------------
worlds = load("worlds.json")
pk = next(w for w in worlds["worlds"] if w["id"] == "pokemon")
pk["heroes"] = ["pikachu", "charmander"]
pk["boss_rotation"] = ["latios", "ho_oh", "mewtwo"]
LOC = "res://assets/locations/pkmndungeon/processed"
pk["room_backgrounds"] = {
    "start": [f"{LOC}/start_meadow.png"],
    "combat": [
        f"{LOC}/combat_woods.png",
        f"{LOC}/combat_woods2.png",
        f"{LOC}/combat_cave.png",
        f"{LOC}/combat_cave2.png",
    ],
    "treasure": [f"{LOC}/treasure_vault.png"],
    "boss": [f"{LOC}/boss_summit.png"],
}
pk["barriers"] = {
    "h": [f"{LOC}/barrier_block.png"],
    "v": [f"{LOC}/barrier_block.png"],
}
save("worlds.json", worlds)
print("worlds.json: pokemon heroes + boss_rotation + rooms + barriers wired")
