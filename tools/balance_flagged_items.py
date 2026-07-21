"""Balance pass for the 25 needs_ai_balance items (NEXT_TASKS P1 #4).

Prices set relative to unflagged neighbors (kingdom_key 1200, mythril 2200,
buster 4500, courage_keyblade 7500, master_sword 8000, yoshi_egg 450,
senzu_bean 800) and KH1 keyblade progression: early blades cheap, Oblivion/
Divine Rose top-tier, cursed variants priced as damaged curios. Revive
consumables were the clearest placeholder bug: 1up (revive) at 120 and
1up_super (revive+heal) at 90 — the deluxe was CHEAPER than the basic.

Idempotent: sets price by id and strips the needs_ai_balance marker.
"""
import json

PATH = "data/items.json"

PRICES = {
    # KH1 keyblade progression
    "wishing_star_keyblade": 1800,   # early (Traverse Town)
    "three_wishes_keyblade": 2400,   # Agrabah
    "crabclaw_keyblade": 2500,       # Atlantica
    "lady_luck_keyblade": 2600,      # Wonderland
    "olympia_keyblade": 2800,        # Coliseum champion
    "fairy_harp_keyblade": 3000,     # Neverland
    "divine_rose_keyblade": 5500,    # Hollow Bastion, late
    "oblivion_keyblade": 7000,       # top-tier, tagged rare
    "soul_eater": 3500,              # Riku's blade
    "poison_kingdom_key": 900,       # cursed kingdom_key (1200) — damaged curio
    # Yoshi egg color variants: a notch above the base yoshi_egg (450)
    "pink_yoshi_egg": 550, "blue_yoshi_egg": 550, "red_yoshi_egg": 550,
    "orange_yoshi_egg": 550, "aqua_yoshi_egg": 550,
    # Beanbean commodity crops, mildly differentiated (Chuckola input tops)
    "hoo_bean": 100, "hee_bean": 110, "woo_bean": 130, "chuckle_bean": 140,
    # gear & curios
    "dk_hammer": 1400,
    "gameboy": 1800,                 # legendary collector curio
    # revive consumables: strong dungeon effect, priced near senzu (800)
    "1up_mushroom": 950,
    "1up_super_mushroom": 1500,      # revive + full heal, must cost MORE
    # reviewed, kept as-is
    "peach_s_dress": 10000,          # showcase royal piece above master_sword
    "poison_mushroom": 60,           # prank item, cheap on purpose
}

def main():
    doc = json.load(open(PATH, encoding="utf-8"))
    items = doc["items"] if isinstance(doc, dict) and "items" in doc else doc
    changed = 0
    for i in items:
        if i["id"] in PRICES:
            i["price"] = PRICES[i["id"]]
            if i.pop("needs_ai_balance", None) is not None:
                changed += 1
    print(f"priced {changed} flagged items")
    left = [i["id"] for i in items if i.get("needs_ai_balance")]
    print("still flagged:", left or "none")
    with open(PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write("\n")

if __name__ == "__main__":
    main()
