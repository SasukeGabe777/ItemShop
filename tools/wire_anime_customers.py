"""Add the Jump Ultimate Stars cast to the shop customer pool.

The pool is world-agnostic at runtime (ContentDatabase.customer_pool_entry
hashes across the whole pool), so these show up as walk-in shoppers in every
world's shop day. Idempotent: existing jus_* entries are refreshed, not
duplicated.

customer_visuals.json is indent=2 and LF — see docs/AGENT_GUIDE.md §6.

Run: .venv312/Scripts/python tools/wire_anime_customers.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
NAMES = json.loads((ROOT / "assets/franchises/anime/customers.json").read_text(encoding="utf-8"))


def main() -> None:
    p = DATA / "customer_visuals.json"
    d = json.loads(p.read_text(encoding="utf-8"))
    pool = [e for e in d["pool"] if not str(e.get("slug", "")).startswith("jus_")]
    for slug, name in NAMES.items():
        pool.append({
            "slug": slug, "name": name, "world": "anime",
            "static": f"res://assets/franchises/anime/processed/customers/{slug}.png",
        })
    d["pool"] = pool
    with open(p, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
    print(f"  anime customers: {len(NAMES)} (pool now {len(pool)})")


if __name__ == "__main__":
    main()
