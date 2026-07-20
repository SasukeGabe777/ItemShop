"""Give every selectable consumable a real effect.

The expedition picker offers any item in the `consumable` or `food` category,
but 33 of them shipped with no `effect` block at all — picking them burned an
item slot and did literally nothing. This assigns each one a faithful effect,
scaled against the items that already worked (kh_potion 40, hi_potion 100,
ff_tent 200, elixirs 999).

Only items that are missing an effect are touched, so re-running is safe and
hand-tuned values elsewhere are left alone.

Run: .venv312/Scripts/python tools/wire_consumable_effects.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ITEMS = ROOT / "data/items.json"

EFFECTS: dict[str, dict] = {
    # --- Pokemon medicine, tiered like the originals -----------------------
    "super_potion": {"heal": 60},
    "hyper_potion": {"heal": 120},
    "pkmn_ether": {"meter": 30},            # restores move energy, not HP
    "lava_cookie": {"heal": 60},
    "pecha_berry": {"heal": 20},
    "cheri_berry": {"heal": 20},
    "oran_berry": {"heal": 30},
    "sitrus_berry": {"heal": 60},
    "leftovers": {"heal": 25},
    "soda_pop": {"heal": 35},
    "lemonade": {"heal": 55},
    # --- food: a meal restores HP in proportion to how absurd it is --------
    "hearty_ramen": {"heal": 70},
    "dino_drumstick": {"heal": 90},
    "mega_burger": {"heal": 75},
    "marbled_beef": {"heal": 85},
    "fresh_milk": {"heal": 40},
    "chilled_soda": {"heal": 35},
    "giant_river_fish": {"heal": 100},
    "dango_skewer": {"heal": 30},
    # --- Mario ------------------------------------------------------------
    "1up_mushroom": {"revive": 1},
    "1up_super_mushroom": {"revive": 1, "heal": 100},
    "ultra_mushroom": {"heal": 80},
    "refreshing_herb": {"heal": 50},
    "poison_mushroom": {"self_damage": 25},   # a trap item, and honest about it
    # --- Naruto tools -----------------------------------------------------
    "field_medkit": {"heal": 70},
    "makibishi_spikes": {"aoe_damage": 25},
    "substitution_log": {"invincible": 2.0},  # takes exactly one hit for you
    # --- peppers: the classic power/guard/speed trio ----------------------
    "red_pepper": {"buff_atk": 6},
    "green_pepper": {"buff_def": 6},
    "blue_pepper": {"invincible": 1.5},
    # --- Smash items ------------------------------------------------------
    "smash_egg": {"aoe_damage": 40},
    "copy_flower": {"aoe_damage": 35},
    "mix_flower": {"aoe_damage": 60},
}


def main() -> None:
    d = json.loads(ITEMS.read_text(encoding="utf-8"))
    items = d["items"] if isinstance(d, dict) else d
    by_id = {i["id"]: i for i in items}
    added, skipped, missing = 0, 0, []
    for iid, fx in EFFECTS.items():
        it = by_id.get(iid)
        if it is None:
            missing.append(iid)
            continue
        if it.get("effect"):
            skipped += 1
            continue
        it["effect"] = fx
        added += 1
    # LF + indent 1 to match the file (AGENT_GUIDE §6)
    with open(ITEMS, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(d, indent=1, ensure_ascii=False) + "\n")
    print(f"  effects added: {added}, already had one: {skipped}")
    if missing:
        print(f"  !! unknown ids: {missing}")

    dead = [i["id"] for i in items
            if i.get("category") in ("consumable", "food") and not i.get("effect")]
    print(f"  selectable consumables still without an effect: {len(dead)} {dead}")


if __name__ == "__main__":
    main()
