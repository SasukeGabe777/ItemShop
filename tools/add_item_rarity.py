"""Assign an explicit rarity to every Crossroads item.

The rules are intentionally deterministic and source-aware so rerunning this
script is idempotent. `OVERRIDES` is the review surface for authored exceptions
when a playtest/admin audit identifies an item whose franchise importance does
not match its price or acquisition route.
"""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
ITEMS_PATH = ROOT / "data" / "items.json"
VALID = {"Common", "Uncommon", "Rare", "Legendary"}

# Authored exceptions belong here instead of being hand-edited into data.
OVERRIDES: dict[str, str] = {
    "oblivion_keyblade": "Legendary",
    "soul_eater": "Legendary",
    "peach_s_dress": "Legendary",
    "dragon_ball_set": "Legendary",
}


def classify(item: dict) -> str:
    item_id = str(item["id"])
    if item_id in OVERRIDES:
        return OVERRIDES[item_id]
    tags = {str(tag) for tag in item.get("tags", [])}
    sources = {str(source) for source in item.get("acquisition", ["market"])}
    price = float(item.get("price", 0))
    if (
        "legendary" in tags
        or "world_shard" in tags
        or sources == {"expedition_boss"}
        or price >= 7000
    ):
        return "Legendary"
    if (
        "rare" in tags
        or "expedition_boss" in sources
        or sources == {"expedition_chest"}
        or price >= 2500
    ):
        return "Rare"
    if (
        sources.intersection({"crafting", "expedition_chest"})
        or price >= 500
    ):
        return "Uncommon"
    return "Common"


def main() -> None:
    document = json.loads(ITEMS_PATH.read_text(encoding="utf-8"))
    counts: Counter[str] = Counter()
    for item in document["items"]:
        rarity = classify(item)
        if rarity not in VALID:
            raise ValueError(f"{item['id']}: invalid rarity {rarity!r}")
        item["rarity"] = rarity
        counts[rarity] += 1
    ITEMS_PATH.write_text(
        json.dumps(document, indent=1, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print("ITEM_RARITY_PASS", dict(sorted(counts.items())))


if __name__ == "__main__":
    main()
