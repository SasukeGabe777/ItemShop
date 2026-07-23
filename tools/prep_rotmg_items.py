"""Downscale ROTMG item art into shop icons (<=22px) at processed/items/<id>.png.

ContentDatabase.live_items only surfaces items whose icon file exists here, so
this gates which items circulate. id -> raw source path below is the record of
which official sprite backs each shop item. Never touches raw/.
"""
import os
from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets/franchises/rotmg/raw/Items")
OUT = os.path.join(ROOT, "assets/franchises/rotmg/processed/items")
MAX = 22

# item id -> source png (relative to raw/Items)
ICONS = {
    # consumables
    "hp_potion": "Potions/Life Pot.png",
    "mp_potion": "Potions/Mana Pot.png",
    "life_potion": "Potions/G Life Pot.png",
    "atk_potion": "Potions/Atk Pot.png",
    "def_potion": "Potions/Def Pot.png",
    "spd_potion": "Potions/Spd Pot.png",
    "dex_potion": "Potions/Dex Pot.png",
    "vit_potion": "Potions/Vit Pot.png",
    "wis_potion": "Potions/Wis Pot.png",
    # weapons
    "leaf_bow": "Weapons/UT/Leaf Bow.png",
    "coral_bow": "Weapons/UT/Coral Bow.png",
    "doom_bow": "Weapons/UT/Doom Bow.png",
    "cosmic_staff": "Weapons/UT/t12 staff.png",
    "recompense_wand": "Weapons/UT/t12 wand.png",
    "sword_splendor": "Weapons/UT/t13 sword.png",
    "foul_dagger": "Weapons/UT/t12 dagger.png",
    "doku_katana": "Weapons/UT/Doku.png",
    # armor
    "hydra_armor": "Armors/Tiered/t13 Leather.png",
    "acropolis_armor": "Armors/Tiered/t12 Heavy.png",
    "sorcerer_robe": "Armors/Tiered/t12 Robe.png",
    "leviathan_armor": "Armors/UT/Leviathan Armor.png",
    # abilities
    "golden_quiver": "Abilities/Tiered/t7 quiver.png",
    "ghostly_cloak": "Abilities/Tiered/t7 cloak.png",
    "soul_skull": "Abilities/Tiered/t7 skull.png",
    # rings
    "attack_ring": "Rings/Tiered/Unbound Attack.png",
    "defense_ring": "Rings/Tiered/Unbound Defense.png",
    "speed_ring": "Rings/Tiered/Unbound Speed.png",
    "unbound_health": "Rings/Tiered/Ring of Decades.png",
    # completion token (display icon; stays out of the live catalog via sellable=false)
    "world_shard_rotmg": "Portals/Realm Portal.png",
}


def trim(im):
    a = np.array(im.convert("RGBA"))
    m = a[:, :, 3] > 16
    if not m.any():
        return im
    ys, xs = np.where(m)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def main():
    os.makedirs(OUT, exist_ok=True)
    for iid, rel in ICONS.items():
        src = os.path.join(RAW, rel)
        if not os.path.exists(src):
            print(f"  !! MISSING {iid}: {rel}")
            continue
        im = trim(Image.open(src).convert("RGBA"))
        scale = MAX / max(im.width, im.height)
        w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
        im = im.resize((w, h), Image.LANCZOS)
        a = np.array(im).astype(np.int16)
        a[:, :, 3] = np.where(a[:, :, 3] < 90, 0, np.where(a[:, :, 3] > 150, 255, a[:, :, 3]))
        Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, f"{iid}.png"))
        print(f"  icon {iid:18s} {w}x{h}  <- {rel}")


if __name__ == "__main__":
    main()
