"""Rebuild the workshop into a broad, economically coherent recipe catalog.

Recipes target roughly a 20% value gain over ingredients plus workshop fee.
The few material-dense recipes that cannot reach that target still have a
positive return. This script is idempotent and preserves the project's
one-space, sorted-key JSON convention.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECIPES_PATH = ROOT / "data" / "recipes.json"
ITEMS_PATH = ROOT / "data" / "items.json"
TARGET_RETURN = 1.20


STRUCTURE_OVERRIDES: dict[str, dict] = {
    "r_ice_cream": {"inputs": {"frost_shard": 1, "fresh_milk": 1}, "count": 8},
    "r_ribbon_charm": {
        "inputs": {"ff_ribbon": 1, "keychain": 1},
        "output": "fairy_harp_keyblade",
        "count": 1,
    },
    "r_dango_batch": {"count": 8},
    "r_mega_burger": {"count": 4},
    "r_ultra_ball": {"inputs": {"great_ball": 1, "blue_shard": 1}},
    "r_fairy_bottle": {"count": 2},
    "r_bomb_bag": {"inputs": {"mario_bobomb": 1, "deku_wood": 1}},
    "r_full_restore_brew": {"count": 2},
    "r_lucky_meal": {"count": 3},
    "r_pow": {"inputs": {"koopa_shell": 1, "gold_coin": 2}},
    "r_field_medkit": {
        "inputs": {"refreshing_herb": 1, "pecha_berry": 1, "ff_potion": 1},
        "count": 2,
    },
    "r_mix_flower": {"inputs": {"ice_flower": 1, "red_pepper": 1}},
    "r_water_stone": {"inputs": {"blue_shard": 1}},
    "r_thunder_stone": {"inputs": {"yellow_shard": 1}},
    "r_leaf_stone": {"inputs": {"green_shard": 1}},
    "r_fire_stone": {"inputs": {"red_shard": 1}},
    "r_remedy": {"inputs": {"ff_potion": 1, "green_potion": 1}},
    "r_sitrus_blend": {"inputs": {"oran_berry": 2}},
    "r_shard_lantern": {
        "inputs": {"bright_shard": 1, "deku_wood": 1},
        "output": "zelda_lantern",
    },
    "r_koopa_ball": {
        "inputs": {"koopa_shell": 1, "poke_ball": 1, "red_shard": 1},
        "output": "ultra_ball",
    },
    "r_royal_feast": {"count": 2},
}


NEW_RECIPES = [
    # Kingdom Hearts presentation and keyblade synthesis.
    ("r_paopu_charm", 1, {"paopu_fruit": 1, "bright_shard": 1}, "paopu_charm", 1, True),
    ("r_lady_luck", 4, {"keychain": 1, "lucky_egg": 1, "yellow_shard": 1}, "lady_luck_keyblade", 1, True),
    ("r_poison_key", 3, {"keychain": 1, "poison_mushroom": 1, "smoke_bomb": 1}, "poison_kingdom_key", 1, True),
    # Mario food, flowers, eggs, and beanwork.
    ("r_copy_flower", 3, {"fire_flower": 1, "ice_flower": 1}, "copy_flower", 1, False),
    ("r_yoshi_egg", 3, {"smash_egg": 1, "sitrus_berry": 1}, "yoshi_egg", 2, True),
    ("r_bean_candy", 4, {"hee_bean": 1, "hoo_bean": 1, "woo_bean": 1, "chuckle_bean": 1}, "rare_candy", 1, True),
    ("r_dk_hammer", 4, {"mario_hammer": 1, "deku_wood": 1}, "dk_hammer", 1, True),
    ("r_1up_mushroom", 4, {"one_up_mushroom": 1, "super_mushroom": 1}, "1up_mushroom", 1, True),
    ("r_1up_super", 5, {"ultra_mushroom": 1, "one_up_mushroom": 1}, "1up_super_mushroom", 1, True),
    # Zelda carpentry, tools, and legendary upgrades.
    ("r_wooden_shield", 2, {"deku_wood": 2}, "wooden_shield", 1, False),
    ("r_boomerang", 2, {"deku_wood": 2, "shuriken": 1}, "zelda_boomerang", 1, True),
    ("r_pegasus_boots", 4, {"escape_rope": 1, "cape_feather": 1}, "pegasus_boots", 1, True),
    ("r_hookshot", 4, {"escape_rope": 1, "kh_mythril": 1}, "hookshot", 1, True),
    ("r_gust_jar", 4, {"capsule": 1, "deku_wood": 1, "gummi_block": 1}, "gust_jar", 1, True),
    ("r_cane_of_pacci", 5, {"deku_wood": 2, "energy_crystal": 1}, "cane_of_pacci", 1, True),
    ("r_rocs_cape", 5, {"cape_feather": 1, "tanooki_leaf": 1}, "rocs_cape", 1, True),
    ("r_four_sword", 6, {"white_sword": 1, "kinstone": 2}, "four_sword", 1, False),
    ("r_hylian_shield", 6, {"wooden_shield": 1, "kh_mythril": 2, "crystal_shard_ff": 1}, "hylian_shield", 1, True),
    ("r_master_sword", 7, {"white_sword": 1, "triforce_fragment": 1, "bright_shard": 1}, "master_sword", 1, True),
    # Naruto fieldcraft.
    ("r_substitution_log", 2, {"deku_wood": 1}, "substitution_log", 1, True),
    ("r_forehead_protector", 3, {"kunai": 1, "deku_wood": 1}, "forehead_protector", 1, False),
    ("r_summoning_scroll", 5, {"ninja_scroll": 2}, "summoning_scroll", 1, False),
    ("r_ichiraku_ticket", 3, {"ramen_bowl": 3}, "ichiraku_ticket", 1, False),
    # Dragon Ball capsule technology and training gear.
    ("r_scouter", 3, {"capsule": 1, "yellow_shard": 1}, "scouter", 1, True),
    ("r_turtle_gi", 4, {"training_weights": 1}, "turtle_gi", 1, True),
    ("r_weighted_clothing", 4, {"training_weights": 1}, "weighted_clothing", 1, False),
    ("r_dragon_radar", 5, {"scouter": 1, "capsule": 1}, "dragon_radar", 1, False),
    ("r_capsule_house", 6, {"capsule": 8, "deku_wood": 4}, "capsule_house", 1, True),
    # Pokémon supplies and held items.
    ("r_super_potion", 1, {"pkmn_potion": 1, "oran_berry": 1}, "super_potion", 1, False),
    ("r_rare_candy", 4, {"lava_cookie": 1, "sitrus_berry": 1, "paopu_fruit": 1}, "rare_candy", 1, True),
    ("r_amulet_coin", 4, {"zeni_coin": 1, "gold_coin": 5, "kinstone": 1}, "amulet_coin", 1, True),
    ("r_shell_bell", 4, {"red_koopa_shell": 1, "green_potion": 1}, "shell_bell", 1, True),
    ("r_technical_machine", 5, {"ninja_scroll": 1, "materia": 1}, "technical_machine", 1, True),
    ("r_master_ball", 7, {"ultra_ball": 1, "star_piece": 1, "technical_machine": 1}, "master_ball", 1, False),
    # Final Fantasy field supplies and forge upgrades.
    ("r_ff_tent", 2, {"deku_wood": 2, "ff_potion": 1}, "ff_tent", 1, True),
    ("r_mythril_sword", 5, {"kh_mythril": 2, "mario_hammer": 1}, "mythril_sword", 1, True),
    ("r_buster_sword", 7, {"mythril_sword": 1, "training_weights": 1}, "buster_sword", 1, True),
    # Distinct crossover keyblade paths.
    ("r_wishing_star", 3, {"starman": 1, "keychain": 1}, "wishing_star_keyblade", 1, True),
    ("r_three_wishes", 5, {"lucky_egg": 1, "keychain": 1}, "three_wishes_keyblade", 1, True),
    ("r_crabclaw", 5, {"red_koopa_shell": 1, "shell_bell": 1, "keychain": 1}, "crabclaw_keyblade", 1, True),
    ("r_olympia", 6, {"power_wrist": 1, "keychain": 1, "training_weights": 1}, "olympia_keyblade", 1, True),
    ("r_divine_rose", 7, {"paopu_charm": 1, "red_shard": 1, "keychain": 1}, "divine_rose_keyblade", 1, True),
    ("r_oblivion", 7, {"soul_eater": 1, "keychain": 1, "lucid_shard": 2}, "oblivion_keyblade", 1, True),
    ("r_gameboy", 6, {"capsule": 1, "technical_machine": 1}, "gameboy", 1, True),
]


def recipe(recipe_id: str, chapter: int, inputs: dict[str, int], output: str,
           count: int = 1, crossover: bool = False) -> dict:
    row = {
        "id": recipe_id,
        "inputs": inputs,
        "output": output,
        "fee": 0,
        "unlock_chapter": chapter,
    }
    if count != 1:
        row["count"] = count
    if crossover:
        row["crossover"] = True
    return row


def main() -> None:
    item_doc = json.loads(ITEMS_PATH.read_text(encoding="utf-8"))
    item_by_id = {str(item["id"]): item for item in item_doc["items"]}
    document = json.loads(RECIPES_PATH.read_text(encoding="utf-8"))
    rows = document["recipes"]
    by_id = {str(row["id"]): row for row in rows}

    missing_overrides = sorted(set(STRUCTURE_OVERRIDES) - set(by_id))
    if missing_overrides:
        raise SystemExit("Missing existing recipes: " + ", ".join(missing_overrides))
    for recipe_id, changes in STRUCTURE_OVERRIDES.items():
        by_id[recipe_id].update(changes)
        if int(by_id[recipe_id].get("count", 1)) == 1:
            by_id[recipe_id].pop("count", None)

    new_ids = {spec[0] for spec in NEW_RECIPES}
    rows[:] = [row for row in rows if str(row["id"]) not in new_ids]
    for spec in NEW_RECIPES:
        rows.append(recipe(*spec))

    failures: list[str] = []
    used_inputs: set[str] = set()
    for row in rows:
        output_id = str(row["output"])
        if output_id not in item_by_id:
            failures.append(f"{row['id']}: missing output {output_id}")
            continue
        input_value = 0
        for item_id, quantity in row["inputs"].items():
            if item_id not in item_by_id:
                failures.append(f"{row['id']}: missing input {item_id}")
                continue
            used_inputs.add(item_id)
            input_value += round(float(item_by_id[item_id]["price"])) * int(quantity)
        output_value = round(float(item_by_id[output_id]["price"])) * int(row.get("count", 1))
        desired_cost = output_value / TARGET_RETURN
        fee = max(10, round((desired_cost - input_value) / 10.0) * 10)
        row["fee"] = fee
        total_cost = input_value + fee
        value_return = output_value / max(1, total_cost)
        if value_return < 1.03 or value_return > 1.35:
            failures.append(
                f"{row['id']}: return {value_return:.2f} "
                f"({input_value} materials + {fee} fee -> {output_value})"
            )

    if failures:
        raise SystemExit("Workshop validation failed:\n  " + "\n  ".join(failures))

    rows.sort(key=lambda row: (int(row.get("unlock_chapter", 1)), str(row["id"])))
    RECIPES_PATH.write_text(
        json.dumps(document, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"Workshop recipes: {len(rows)}; distinct material inputs: {len(used_inputs)}")


if __name__ == "__main__":
    main()
