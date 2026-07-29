"""Normalize item identity, semantic tags, and acquisition sources.

Idempotent migration for the Core Loop Hardening pass. The runtime uses these
fields as its single source of truth for markets, orders, Booms, trends, and
expedition-only rewards.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

# These were stored under the pseudo-world "crossover" only because their
# icons were extracted there. Their actual franchise origin is unambiguous.
ORIGIN_FIXES = {
    "blue_yoshi_egg": "mario",
    "red_yoshi_egg": "mario",
    "orange_yoshi_egg": "mario",
    "aqua_yoshi_egg": "mario",
    "chuckle_bean": "mario",
    "hoo_bean": "mario",
    "woo_bean": "mario",
    "dk_hammer": "mario",
    "1up_mushroom": "mario",
    "1up_super_mushroom": "mario",
    "gameboy": "mario",
    "poison_mushroom": "mario",
    "three_wishes_keyblade": "kingdom_hearts",
    "crabclaw_keyblade": "kingdom_hearts",
    "oblivion_keyblade": "kingdom_hearts",
    "fairy_harp_keyblade": "kingdom_hearts",
    "wishing_star_keyblade": "kingdom_hearts",
    "olympia_keyblade": "kingdom_hearts",
    "divine_rose_keyblade": "kingdom_hearts",
}

# Authored expedition exclusives. Darkside is the third Kingdom Hearts boss,
# so Oblivion only enters the reward pool after the original three-run arc.
FORCED_SOURCES = {
    "kingdom_key": ["expedition_boss"],
    "soul_eater": ["expedition_boss"],
    "oblivion_keyblade": ["expedition_boss"],
    "gameboy": ["expedition_chest"],
    "blue_yoshi_egg": ["expedition_chest"],
    "red_yoshi_egg": ["expedition_chest"],
    "orange_yoshi_egg": ["expedition_chest"],
    "aqua_yoshi_egg": ["expedition_chest"],
    "1up_mushroom": ["expedition_chest"],
    "1up_super_mushroom": ["expedition_chest"],
}

EVENT_MIN_CHAPTERS = {
    "healing_shortage": 2,
    "weapon_boom": 2,
    "food_festival": 2,
    "collector_convention": 2,
    "mushroom_oversupply": 2,
    "materia_shortage": 1,
    "ninja_tool_demand": 5,
    "capsule_craze": 6,
    "evolution_rush": 7,
    "shard_glut": 1,
    "explosive_regulations": 4,
    "sweet_tooth_epidemic": 6,
    "bottle_deposit": 1,
    "quiet_day": 1,
}


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: dict) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=1, ensure_ascii=False)
        stream.write("\n")


def repair_display_text(value: str) -> str:
    """Repair the one surviving UTF-8-as-Latin-1 franchise spelling."""
    return value.replace("PokÃ©", "Poké")


def main() -> None:
    item_path = ROOT / "data" / "items.json"
    world_path = ROOT / "data" / "worlds.json"
    enemy_path = ROOT / "data" / "enemies.json"
    recipe_path = ROOT / "data" / "recipes.json"
    event_path = ROOT / "data" / "market_events.json"
    items_doc = read_json(item_path)
    worlds_doc = read_json(world_path)
    enemies_doc = read_json(enemy_path)
    recipes_doc = read_json(recipe_path)
    events_doc = read_json(event_path)

    items = {item["id"]: item for item in items_doc["items"]}
    worlds = {world["id"]: world for world in worlds_doc["worlds"]}

    for item in items.values():
        for field in ("name", "desc"):
            if field in item:
                item[field] = repair_display_text(str(item[field]))
    for world in worlds.values():
        if "name" in world:
            world["name"] = repair_display_text(str(world["name"]))

    # Correct franchise identity without moving established art assets.
    for item_id, origin in ORIGIN_FIXES.items():
        item = items[item_id]
        if item.get("world") != origin:
            item["asset_world"] = str(item.get("asset_world", item["world"]))
            item["world"] = origin

    # Trend/Boom semantics must follow actual behavior, not hand-maintained
    # partial tags. An Elixir or edible healing item is always healing.
    for item in items.values():
        tags = list(dict.fromkeys(str(tag) for tag in item.get("tags", [])))
        effect = item.get("effect", {})
        if ("heal" in effect or "revive" in effect) and "healing" not in tags:
            tags.append("healing")
        if "revive" in effect and "revive" not in tags:
            tags.append("revive")
        if item.get("category") == "food" and "food" not in tags:
            tags.append("food")
        item["tags"] = tags

    # Oblivion is now an expedition relic instead of a workshop recipe.
    recipes_doc["recipes"] = [
        recipe for recipe in recipes_doc.get("recipes", [])
        if recipe.get("id") != "r_oblivion"
    ]
    recipe_outputs = {
        str(recipe.get("output", ""))
        for recipe in recipes_doc.get("recipes", [])
        if recipe.get("output")
    }
    recipe_by_output = {
        str(recipe.get("output", "")): recipe
        for recipe in recipes_doc.get("recipes", [])
        if recipe.get("output")
    }

    boss_ids = {
        str(boss["id"]) for boss in enemies_doc.get("bosses", [])
    }
    enemy_loot: set[str] = set()
    boss_loot: set[str] = set()
    for entity in [
        *enemies_doc.get("enemies", []),
        *enemies_doc.get("bosses", []),
    ]:
        target = boss_loot if str(entity["id"]) in boss_ids else enemy_loot
        for drop in entity.get("loot", []):
            if isinstance(drop, list) and drop:
                target.add(str(drop[0]))

    market_by_world = {
        world_id: list(dict.fromkeys(world.get("market_goods", [])))
        for world_id, world in worlds.items()
    }
    market_ids = {
        item_id for goods in market_by_world.values() for item_id in goods
    }

    # Every item has an explicit acquisition contract. Items can have several
    # sources, but crafting outputs and rare expedition relics never leak into
    # wholesale merely because they have icon art.
    for item_id, item in items.items():
        sources: list[str] = []
        if item_id in recipe_outputs:
            sources.append("crafting")
            recipe = recipe_by_output[item_id]
            item["unlock_chapter"] = int(recipe.get("unlock_chapter", 1))
            affinities = {
                str(items[input_id].get("world", ""))
                for input_id in recipe.get("inputs", {})
                if input_id in items and items[input_id].get("world")
            }
            if item.get("world") == "crossover":
                item["world_affinities"] = sorted(affinities)
        if item_id in market_ids:
            sources.append("market")
        if item_id in enemy_loot:
            sources.append("expedition_enemy")
        if item_id in boss_loot:
            sources.append("expedition_boss")
        if item_id in FORCED_SOURCES:
            sources = list(FORCED_SOURCES[item_id])
        if not sources and item.get("sellable", True) is not False:
            world_id = str(item.get("world", ""))
            if world_id in worlds:
                rare = "rare" in item.get("tags", []) \
                    or "legendary" in item.get("tags", [])
                if rare:
                    sources.append("expedition_chest")
                else:
                    sources.append("market")
                    if item_id not in market_by_world[world_id]:
                        market_by_world[world_id].append(item_id)
            elif item.get("world") == "crossover":
                sources.append("crafting")
        item["acquisition"] = list(dict.fromkeys(sources))

    # Keep world market lists aligned with the item source contract. Missing-art
    # entries remain authored and visible to the audit, but runtime still keeps
    # them out until their sprites exist.
    for world_id, world in worlds.items():
        world["market_goods"] = [
            item_id for item_id in market_by_world[world_id]
            if item_id in items and "market" in items[item_id]["acquisition"]
        ]

    # Darkside completes the original three-boss Kingdom Hearts rotation.
    # Its two relics are rare but become guaranteed under a 4x drop Boom.
    for boss in enemies_doc.get("bosses", []):
        if boss.get("id") != "darkside":
            continue
        loot = [
            drop for drop in boss.get("loot", [])
            if not (isinstance(drop, list) and drop
                    and drop[0] in {"soul_eater", "oblivion_keyblade"})
        ]
        loot.extend([
            ["soul_eater", 0.25],
            ["oblivion_keyblade", 0.25],
        ])
        boss["loot"] = loot

    write_json(item_path, items_doc)
    write_json(world_path, worlds_doc)
    write_json(enemy_path, enemies_doc)
    write_json(recipe_path, recipes_doc)
    for event in events_doc.get("events", []):
        event["min_chapter"] = EVENT_MIN_CHAPTERS[str(event["id"])]
        if event.get("id") == "food_festival":
            event["mults"] = {"cat:food": 1.5}
        elif event.get("id") == "weapon_boom":
            event["mults"] = {"cat:weapon": 1.5}
        elif event.get("id") == "materia_shortage":
            event["name"] = "Magic Supply Shortage"
            event["desc"] = "Ethers, enchanted goods, and magical supplies are scarce today."
            event["mults"] = {"tag:magic": 1.4}
    write_json(event_path, events_doc)
    print(
        f"hardened {len(items)} items; "
        f"{len(recipe_outputs)} crafting outputs; "
        f"{sum('market' in item['acquisition'] for item in items.values())} market goods"
    )


if __name__ == "__main__":
    main()
