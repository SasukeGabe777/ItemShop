"""Catalog audit: normalize categories to the game's real set, fill missing
tags on Content-Studio items, and report anything still suspicious."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VALID_CATEGORIES = {"weapon", "armor", "consumable", "food", "treasure", "material", "accessory", "key"}

FIXES = {
    # Content-Studio "misc" items -> real categories + tags
    "blue_yoshi_egg": dict(category="treasure", tags=["egg", "cute", "rare"]),
    "red_yoshi_egg": dict(category="treasure", tags=["egg", "cute", "rare"]),
    "orange_yoshi_egg": dict(category="treasure", tags=["egg", "cute", "rare"]),
    "aqua_yoshi_egg": dict(category="treasure", tags=["egg", "cute", "rare"]),
    "pink_yoshi_egg": dict(tags=["egg", "cute", "rare"]),
    "chuckle_bean": dict(category="material", tags=["bean", "plant"]),
    "hoo_bean": dict(category="material", tags=["bean", "plant"]),
    "woo_bean": dict(category="material", tags=["bean", "plant"]),
    "hee_bean": dict(category="material", tags=["bean", "plant"]),
    "dk_hammer": dict(category="weapon", tags=["hammer", "huge"]),
    "1up_mushroom": dict(category="consumable", tags=["mushroom", "rare", "revive"]),
    "1up_super_mushroom": dict(tags=["mushroom", "rare", "revive"]),
    "poison_mushroom": dict(tags=["mushroom", "weird"]),
    "gameboy": dict(tags=["technology", "rare"]),
    "peach_s_dress": dict(tags=["clothing", "royal", "rare"]),
    # untagged studio keyblades
    "three_wishes_keyblade": dict(tags=["sword", "key"]),
    "crabclaw_keyblade": dict(tags=["sword", "key"]),
    "oblivion_keyblade": dict(tags=["sword", "key", "rare"]),
    "fairy_harp_keyblade": dict(tags=["sword", "key"]),
    "wishing_star_keyblade": dict(tags=["sword", "key"]),
    "olympia_keyblade": dict(tags=["sword", "key"]),
    "divine_rose_keyblade": dict(tags=["sword", "key"]),
    "lady_luck_keyblade": dict(tags=["sword", "key"]),
    "poison_kingdom_key": dict(tags=["sword", "key", "weird"]),
    "soul_eater": dict(tags=["sword", "creepy"]),
    # name collision with KH "Ether"
    "pkmn_ether": dict(name="Pokémon Ether"),
}

DESCS = {
    "lady_luck_keyblade": "A keyblade of hearts and dice. Fortune favors whoever holds it.",
    "pink_yoshi_egg": "A spotted pink egg that wobbles hopefully when you hum.",
    "blue_yoshi_egg": "A spotted blue egg. Something inside is practicing its flutter jump.",
    "red_yoshi_egg": "A spotted red egg, warm to the touch and faintly impatient.",
    "orange_yoshi_egg": "A spotted orange egg that smells vaguely of melon.",
    "aqua_yoshi_egg": "A spotted aqua egg cool as sea glass.",
    "hee_bean": "A giggling bean from the Beanbean fields. It knows something you don't.",
    "chuckle_bean": "A chuckling bean prized for brewing Chuckola Cola.",
    "hoo_bean": "A hooting bean that whistles softly in a breeze.",
    "woo_bean": "A whooping bean. Baristas fight over sacks of these.",
    "dk_hammer": "A barrel-sized mallet on a stick. Swing with both hands and an apology ready.",
    "1up_mushroom": "A green-capped mushroom that hands out second chances.",
    "1up_super_mushroom": "A deluxe green mushroom. Comes with a second chance and a growth spurt.",
    "gameboy": "A legendary gray handheld from another world. Still has batteries.",
    "peach_s_dress": "An immaculate royal gown. Somehow never wrinkles, even mid-kidnapping.",
    "poison_mushroom": "A purple-capped mushroom. Absolutely do not garnish anything with it.",
    "poison_kingdom_key": "A kingdom key gone sickly violet. It hums a wrong note.",
    "three_wishes_keyblade": "A golden lamp-themed keyblade. The third wish is always freedom.",
    "crabclaw_keyblade": "A coral keyblade smelling faintly of the tide.",
    "oblivion_keyblade": "A pitch-black keyblade heavy with memories better left closed.",
    "fairy_harp_keyblade": "A harp-strung keyblade that chimes with pixie laughter.",
    "wishing_star_keyblade": "A keyblade carved from wooden toys and stardust.",
    "olympia_keyblade": "A coliseum-champion keyblade. Smells of laurels and sweat.",
    "divine_rose_keyblade": "A rose-wound keyblade. Every petal is a promise.",
    "soul_eater": "A bat-winged blade with a baleful eye. It is definitely watching you.",
}


def main() -> None:
    path = ROOT / "data/items.json"
    doc = json.loads(path.read_text(encoding="utf-8"))
    fixed = 0
    for item in doc["items"]:
        fix = FIXES.get(item["id"])
        if fix:
            item.update(fix)
            fixed += 1
        if not str(item.get("desc", "")).strip() and item["id"] in DESCS:
            item["desc"] = DESCS[item["id"]]
            fixed += 1
    path.write_text(json.dumps(doc, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"fixed {fixed}")
    for item in doc["items"]:
        cat = item.get("category", "")
        if cat not in VALID_CATEGORIES:
            print("BAD CATEGORY:", item["id"], cat)
        if not str(item.get("desc", "")).strip():
            print("NO DESC:", item["id"])
        if not item.get("tags") and cat != "key":
            print("NO TAGS:", item["id"])
        if not str(item.get("name", "")).strip():
            print("NO NAME:", item["id"])


if __name__ == "__main__":
    main()
