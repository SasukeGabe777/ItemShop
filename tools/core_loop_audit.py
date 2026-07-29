"""Crossroads core-loop content audit.

Read-only against gameplay data. It writes a machine-readable JSON report and
a concise Markdown report so content/progression mistakes can be reviewed,
fixed, and regression-tested without relying on a complete manual campaign.
"""

from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
REPORT_DIR = ROOT / "docs" / "audits"
REPORT_JSON = REPORT_DIR / "core_loop_baseline.json"
REPORT_MD = REPORT_DIR / "core_loop_baseline.md"
VALID_CATEGORIES = {
    "weapon", "armor", "accessory", "consumable", "food", "material",
    "treasure", "key",
}
VALID_RARITIES = {"Common", "Uncommon", "Rare", "Legendary"}


def load(name: str) -> dict[str, Any]:
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def item_icon_exists(item: dict[str, Any]) -> bool:
    return (
        ROOT
        / "assets"
        / "franchises"
        / str(item.get("asset_world", item.get("world", "crossroads")))
        / "processed"
        / "items"
        / f"{item['id']}.png"
    ).exists()


def item_matches_key(item: dict[str, Any], key: str) -> bool:
    if key.startswith("tag:"):
        return key[4:] in item.get("tags", [])
    if key.startswith("cat:"):
        return key[4:] == item.get("category")
    if key.startswith("world:"):
        return key[6:] == item.get("world")
    return False


def boom_match(item: dict[str, Any], boom: dict[str, Any], world_id: str = "") -> bool:
    if item.get("category") in boom.get("preferred_categories", []):
        return True
    tags = set(item.get("tags", []))
    if tags.intersection(boom.get("preferred_tags", [])):
        return True
    preferred_worlds = set(boom.get("preferred_worlds", []))
    if world_id:
        preferred_worlds.add(world_id)
    item_worlds = {str(item.get("world", "")), *item.get("world_affinities", [])}
    return bool(item_worlds.intersection(preferred_worlds))


def main() -> None:
    items_doc = load("items.json")
    worlds_doc = load("worlds.json")
    enemies_doc = load("enemies.json")
    recipes_doc = load("recipes.json")
    booms_doc = load("booms.json")
    events_doc = load("market_events.json")
    balance = load("balance.json")

    items = {item["id"]: item for item in items_doc["items"]}
    worlds = {world["id"]: world for world in worlds_doc["worlds"]}
    live = {item_id for item_id, item in items.items()
            if item.get("sellable", True) is not False and item_icon_exists(item)}
    market_goods: dict[str, set[str]] = {
        world_id: set(world.get("market_goods", []))
        for world_id, world in worlds.items()
    }
    market_ids = set().union(*market_goods.values()) if market_goods else set()
    loot_sources: dict[str, list[str]] = defaultdict(list)
    for enemy in [*enemies_doc.get("enemies", []), *enemies_doc.get("bosses", [])]:
        for drop in enemy.get("loot", []):
            if isinstance(drop, list) and drop:
                loot_sources[str(drop[0])].append(str(enemy["id"]))
    recipe_outputs = {
        str(recipe.get("output", "")): str(recipe["id"])
        for recipe in recipes_doc.get("recipes", [])
        if recipe.get("output")
    }
    starting = set(balance.get("starting_inventory", {}).keys())

    base_cap = float(balance.get("market_unlock", {}).get("base_cap", 800.0))
    per_chapter = float(
        balance.get("market_unlock", {}).get("per_chapter_scale", 0.85)
    )

    def price_cap(chapter: int) -> float:
        return base_cap * (1.0 + per_chapter * (chapter - 1))

    def world_chapter(item: dict[str, Any]) -> int:
        world = worlds.get(str(item.get("world", "")), {})
        return int(world.get("chapter", 99 if world.get("final", False) else 1))

    def market_accessible(item_id: str, chapter: int) -> bool:
        item = items[item_id]
        return (
            item_id in live
            and "market" in item.get("acquisition", ["market"])
            and world_chapter(item) <= chapter
            and float(item.get("price", 0)) <= price_cap(chapter)
        )

    def obtainable(item_id: str, chapter: int) -> bool:
        item = items[item_id]
        if item_id not in live or not item.get("acquisition"):
            return False
        unlock_chapter = int(item.get("unlock_chapter", 1))
        item_worlds = [
            str(item.get("world", "")), *item.get("world_affinities", [])
        ]
        source_chapters = [
            int(worlds[world_id].get("chapter", 1))
            for world_id in item_worlds if world_id in worlds
        ]
        required_world_chapter = min(source_chapters) if source_chapters else 1
        if max(unlock_chapter, required_world_chapter) > chapter:
            return False
        if "market" in item.get("acquisition", []):
            return float(item.get("price", 0)) <= price_cap(chapter)
        return True

    issues: list[dict[str, Any]] = []

    def issue(code: str, severity: str, message: str, **context: Any) -> None:
        issues.append({
            "code": code,
            "severity": severity,
            "message": message,
            "context": context,
        })

    # Fundamental item integrity and semantic tags used by trends/Booms.
    for item_id, item in sorted(items.items()):
        category = str(item.get("category", ""))
        tags = set(item.get("tags", []))
        effect = item.get("effect", {})
        world_id = str(item.get("world", ""))
        rarity = str(item.get("rarity", ""))
        if category not in VALID_CATEGORIES:
            issue("invalid_category", "error",
                  f"{item_id} has invalid category '{category}'", item_id=item_id)
        if rarity not in VALID_RARITIES:
            issue("invalid_rarity", "error",
                  f"{item_id} has missing or invalid rarity '{rarity}'",
                  item_id=item_id, rarity=rarity)
        if world_id not in worlds and not (
                world_id == "crossover" and item.get("world_affinities")):
            issue("unknown_world", "error",
                  f"{item_id} references unknown world '{world_id}'", item_id=item_id)
        if ("heal" in effect or "revive" in effect) and "healing" not in tags:
            issue("missing_healing_tag", "error",
                  f"{item_id} has a healing/revive effect but no healing tag",
                  item_id=item_id)
        if "revive" in effect and "revive" not in tags:
            issue("missing_revive_tag", "error",
                  f"{item_id} revives but has no revive tag", item_id=item_id)
        if category == "food" and "food" not in tags:
            issue("missing_food_tag", "error",
                  f"{item_id} is food but has no food tag", item_id=item_id)
        if item_id in market_ids and world_id in market_goods \
                and item_id not in market_goods[world_id]:
            listed_by = sorted(
                wid for wid, ids in market_goods.items() if item_id in ids
            )
            issue("foreign_market_listing", "warning",
                  f"{item_id} belongs to {world_id} but is listed by {listed_by}",
                  item_id=item_id, item_world=world_id, listed_by=listed_by)
        if item_id in live and not item.get("acquisition") \
                and item_id not in market_ids and item_id not in loot_sources \
                and item_id not in recipe_outputs and item_id not in starting:
            issue("unclassified_live_item", "warning",
                  f"{item_id} is live but has no authored acquisition source",
                  item_id=item_id)

    # World/chapter availability. Authored world goods must produce useful,
    # obtainable stock when that world opens.
    chapter_rows: list[dict[str, Any]] = []
    previous: set[str] = set()
    max_chapter = max(int(world.get("chapter", 0)) for world in worlds.values())
    for chapter in range(1, max_chapter + 1):
        current = {item_id for item_id in live if obtainable(item_id, chapter)}
        market_current = {
            item_id for item_id in live if market_accessible(item_id, chapter)
        }
        newly = current - previous
        chapter_worlds = [
            world_id for world_id, world in worlds.items()
            if int(world.get("chapter", 0)) == chapter
        ]
        row = {
            "chapter": chapter,
            "price_cap": round(price_cap(chapter), 2),
            "accessible_count": len(current),
            "market_count": len(market_current),
            "new_count": len(newly),
            "new_items": sorted(newly),
            "worlds": chapter_worlds,
        }
        chapter_rows.append(row)
        progression_worlds = [
            world_id for world_id in chapter_worlds
            if not bool(worlds[world_id].get("final", False))
        ]
        if progression_worlds and not newly:
            issue("empty_chapter_unlock", "error",
                  f"Chapter {chapter} unlocks a world but no live items",
                  chapter=chapter, worlds=progression_worlds)
        previous = current

    world_rows: list[dict[str, Any]] = []
    for world_id, world in sorted(
            worlds.items(), key=lambda pair: int(pair[1].get("chapter", 0))):
        chapter = int(world.get("chapter", 0))
        authored = market_goods[world_id]
        authored_live = {item_id for item_id in authored if item_id in live}
        affordable = {
            item_id for item_id in authored_live
            if float(items[item_id].get("price", 0)) <= price_cap(chapter)
        }
        missing = sorted(item_id for item_id in authored if item_id not in items)
        inaccessible = sorted(authored_live - affordable)
        row = {
            "world_id": world_id,
            "name": world.get("name", world_id),
            "chapter": chapter,
            "authored_market_goods": len(authored),
            "live_market_goods": len(authored_live),
            "affordable_at_unlock": len(affordable),
            "affordable_items": sorted(affordable),
            "inaccessible_by_price": inaccessible,
            "missing_item_ids": missing,
            "loot_only_live_items": sorted(
                item_id for item_id in live
                if items[item_id].get("world") == world_id
                and item_id in loot_sources and item_id not in authored
            ),
        }
        world_rows.append(row)
        if missing:
            issue("missing_market_item", "error",
                  f"{world_id} market_goods contains missing items: {missing}",
                  world_id=world_id, items=missing)
        if chapter > 0 and world_id != "null_archive" and not affordable:
            issue("empty_world_opening", "error",
                  f"{world_id} has no authored market goods affordable at unlock",
                  world_id=world_id, chapter=chapter)
        if authored and len(authored_live) < len(authored):
            no_art = sorted(authored - authored_live - set(missing))
            if no_art:
                issue("market_goods_missing_art", "warning",
                      f"{world_id} has market goods without live item art",
                      world_id=world_id, items=no_art)

    # Market events must have eligible positive/negative matches when they can
    # first roll. A min_chapter is the explicit contract.
    event_rows: list[dict[str, Any]] = []
    for event in events_doc.get("events", []):
        min_chapter = int(event.get("min_chapter", 1))
        suggested_min = 1
        keys = list(event.get("mults", {}))
        for candidate_chapter in range(1, max_chapter + 1):
            candidate_items = {
                item_id for item_id in live
                if obtainable(item_id, candidate_chapter)
            }
            if all(any(item_matches_key(items[item_id], key)
                       for item_id in candidate_items) for key in keys):
                suggested_min = candidate_chapter
                break
        if min_chapter < suggested_min:
            issue("market_event_too_early", "error",
                  f"{event['id']} can roll in Chapter {min_chapter}, but all "
                  f"advertised effects first have stock in Chapter {suggested_min}",
                  event_id=event["id"], min_chapter=min_chapter,
                  suggested_min_chapter=suggested_min)
        available = {
            item_id for item_id in live if obtainable(item_id, min_chapter)
        }
        match_by_key: dict[str, list[str]] = {}
        for key in event.get("mults", {}):
            match_by_key[key] = sorted(
                item_id for item_id in available
                if item_matches_key(items[item_id], key)
            )
            if not match_by_key[key]:
                issue("dead_market_effect", "error",
                      f"{event['id']} effect {key} matches no accessible items",
                      event_id=event["id"], key=key, min_chapter=min_chapter)
        event_rows.append({
            "id": event["id"],
            "min_chapter": min_chapter,
            "suggested_min_chapter": suggested_min,
            "matches": match_by_key,
        })

    # Shop Booms must have an honest reachable pool at their first roll.
    boom_rows: list[dict[str, Any]] = []
    for boom in booms_doc.get("booms", []):
        min_chapter = int(boom.get("min_chapter", 1))
        dynamic = str(boom.get("dynamic_world", ""))
        world_cases = [""]
        if dynamic == "latest_repaired":
            world_cases = [
                world_id for world_id, world in worlds.items()
                if 0 < int(world.get("chapter", 0)) <= min_chapter
            ]
        case_matches: dict[str, list[str]] = {}
        for world_id in world_cases:
            available = {
                item_id for item_id in live if obtainable(item_id, min_chapter)
            }
            matched = sorted(
                item_id for item_id in available
                if boom_match(items[item_id], boom, world_id)
            )
            case_matches[world_id or "global"] = matched
            if not matched and not boom.get("trigger_only", False):
                issue("dead_boom", "error",
                      f"{boom['id']} matches no accessible items",
                      boom_id=boom["id"], min_chapter=min_chapter,
                      world_id=world_id)
        boom_rows.append({
            "id": boom["id"],
            "min_chapter": min_chapter,
            "matches": case_matches,
        })

    # Duplicate display names are allowed only if IDs make the source obvious.
    by_name: dict[str, list[str]] = defaultdict(list)
    for item_id, item in items.items():
        by_name[str(item.get("name", item_id)).casefold()].append(item_id)
    for name, ids in sorted(by_name.items()):
        if len(ids) > 1:
            issue("duplicate_item_name", "warning",
                  f"Duplicate item name '{name}': {sorted(ids)}",
                  name=name, items=sorted(ids))

    counts = defaultdict(int)
    for entry in issues:
        counts[entry["severity"]] += 1
    report = {
        "generated": "deterministic from repository data",
        "summary": {
            "items": len(items),
            "live_items": len(live),
            "worlds": len(worlds),
            "errors": counts["error"],
            "warnings": counts["warning"],
            "rarities": dict(sorted(Counter(
                str(item.get("rarity", "")) for item in items.values()
            ).items())),
        },
        "chapters": chapter_rows,
        "worlds": world_rows,
        "market_events": event_rows,
        "shop_booms": boom_rows,
        "issues": issues,
    }

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_JSON.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    lines = [
        "# Crossroads Core Loop Baseline Audit",
        "",
        "Generated deterministically by `tools/core_loop_audit.py`.",
        "",
        f"- Items: {len(items)} ({len(live)} live with art)",
        "- Rarities: " + ", ".join(
            f"{name} {count}" for name, count in sorted(Counter(
                str(item.get("rarity", "")) for item in items.values()
            ).items())
        ),
        f"- Errors: {counts['error']}",
        f"- Warnings: {counts['warning']}",
        "",
        "## Chapter availability",
        "",
        "| Chapter | Price cap | Obtainable | Market | Newly obtainable | World |",
        "|---:|---:|---:|---:|---:|---|",
    ]
    for row in chapter_rows:
        lines.append(
            f"| {row['chapter']} | {row['price_cap']:.0f}g | "
            f"{row['accessible_count']} | {row['market_count']} | "
            f"{row['new_count']} | "
            f"{', '.join(row['worlds']) or '—'} |"
        )
    lines.extend(["", "## World opening stock", "",
                  "| World | Chapter | Authored | Live | Affordable at unlock |",
                  "|---|---:|---:|---:|---:|"])
    for row in world_rows:
        lines.append(
            f"| {row['name']} | {row['chapter']} | "
            f"{row['authored_market_goods']} | {row['live_market_goods']} | "
            f"{row['affordable_at_unlock']} |"
        )
    lines.extend(["", "## Findings", ""])
    if not issues:
        lines.append("_No findings._")
    else:
        for entry in issues:
            lines.append(
                f"- **{entry['severity'].upper()} · {entry['code']}** — "
                f"{entry['message']}"
            )
    lines.append("")
    REPORT_MD.write_text("\n".join(lines), encoding="utf-8", newline="\n")

    print(json.dumps(report["summary"], ensure_ascii=False))
    print(f"wrote {REPORT_MD.relative_to(ROOT)}")
    print(f"wrote {REPORT_JSON.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
