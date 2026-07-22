"""Apply the shop-furniture customer-attention progression.

The update is intentionally idempotent: rerunning it replaces only the named
attention values and preserves the established sorted, one-space JSON format.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "shop_furniture.json"

ATTENTION_BY_ID = {
    # Shop level 2: the first affordable attention-focused displays.
    "basic_glass_box": 0.15,
    "window_counter": 0.25,
    # Shop level 3: premium single-item presentation; counters trade the
    # bonus for three times the display capacity.
    "premium_item_stand": 0.30,
    # Shop level 4: increasingly elaborate enclosed showcases.
    "display_case": 0.25,
    "glass_display_case": 0.40,
    "premium_glass_box": 0.50,
    # Shop level 5: the endgame attention centerpiece.
    "luxury_glass_display_case": 1.00,
}


def main() -> None:
    document = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    furniture = document.get("furniture", [])
    known_ids = {str(entry.get("id", "")) for entry in furniture}
    missing = sorted(set(ATTENTION_BY_ID) - known_ids)
    if missing:
        raise SystemExit(f"Missing furniture ids: {', '.join(missing)}")
    for entry in furniture:
        furniture_id = str(entry.get("id", ""))
        if furniture_id in ATTENTION_BY_ID:
            entry["customer_attention_modifier"] = ATTENTION_BY_ID[furniture_id]
    DATA_PATH.write_text(
        json.dumps(document, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print("Updated furniture attention: " + ", ".join(ATTENTION_BY_ID))


if __name__ == "__main__":
    main()
