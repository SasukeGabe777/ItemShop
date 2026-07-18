"""Add the newly-sliced items.png items to data/items.json (idempotent:
existing ids are updated in place, so re-running after edits is safe)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

NEW_ITEMS = [
    # ---- pokemon ----
    dict(id="super_potion", name="Super Potion", world="pokemon", category="consumable", price=250,
         tags=["healing", "spray"], desc="A stronger spray-on medicine. Stings for exactly one second."),
    dict(id="hyper_potion", name="Hyper Potion", world="pokemon", category="consumable", price=550,
         tags=["healing", "spray"], desc="Hospital-grade healing in a convenient purple spray."),
    dict(id="pkmn_ether", name="Ether", world="pokemon", category="consumable", price=600,
         tags=["magic", "healing"], desc="Restores a move's energy. Tastes like static."),
    dict(id="lava_cookie", name="Lava Cookie", world="pokemon", category="food", price=200,
         tags=["food", "sweet"], desc="A Lavaridge specialty baked over volcanic heat. Cures every ailment known."),
    dict(id="leaf_stone", name="Leaf Stone", world="pokemon", category="material", price=850,
         tags=["stone", "evolution", "plant"], desc="A peculiar stone with a leaf pattern. Certain creatures adore it."),
    dict(id="tiny_mushroom", name="Tiny Mushroom", world="pokemon", category="material", price=120,
         tags=["mushroom", "plant"], desc="A small, rather popular mushroom. Collectors buy them by the crate."),
    dict(id="big_mushroom", name="Big Mushroom", world="pokemon", category="material", price=500,
         tags=["mushroom", "plant", "rare"], desc="A rare, large mushroom. Smells like money and soil."),
    dict(id="pecha_berry", name="Pecha Berry", world="pokemon", category="food", price=80,
         tags=["food", "berry", "sweet", "plant"], desc="Sweet as syrup. Cures poison on the way down."),
    dict(id="cheri_berry", name="Cheri Berry", world="pokemon", category="food", price=80,
         tags=["food", "berry", "plant"], desc="A fiery little berry that loosens stiff joints."),
    dict(id="oran_berry", name="Oran Berry", world="pokemon", category="food", price=100,
         tags=["food", "berry", "healing", "plant"], desc="A juicy blue berry. The classic trail snack of trainers."),
    dict(id="sitrus_berry", name="Sitrus Berry", world="pokemon", category="food", price=300,
         tags=["food", "berry", "healing", "rare", "plant"], desc="A big citrus berry that restores strength remarkably well."),
    dict(id="star_piece", name="Star Piece", world="pokemon", category="treasure", price=1900,
         tags=["rare", "valuable", "stone"], desc="A shard of pink gemstone that sparkles like a night sky."),
    dict(id="red_shard", name="Red Shard", world="pokemon", category="material", price=450,
         tags=["shard", "stone"], desc="An ancient red shard. Hobbyists trade whole collections for one."),
    dict(id="blue_shard", name="Blue Shard", world="pokemon", category="material", price=450,
         tags=["shard", "stone"], desc="An ancient blue shard washed up from the seafloor."),
    dict(id="yellow_shard", name="Yellow Shard", world="pokemon", category="material", price=450,
         tags=["shard", "stone"], desc="An ancient yellow shard that glints like old amber."),
    dict(id="green_shard", name="Green Shard", world="pokemon", category="material", price=450,
         tags=["shard", "stone"], desc="An ancient green shard. Divers swear they bring luck."),
    dict(id="nugget", name="Nugget", world="pokemon", category="treasure", price=2500,
         tags=["valuable", "rare"], desc="A solid lump of pure gold. Why do so many people just hand these out?"),
    dict(id="twisted_spoon", name="Twisted Spoon", world="pokemon", category="accessory", price=700,
         tags=["magic", "psychic"], desc="A spoon bent by sheer willpower. Useless for soup, priceless for psychics."),
    dict(id="black_glasses", name="Black Glasses", world="pokemon", category="accessory", price=650,
         tags=["glasses", "creepy"], desc="Shady-looking shades that make dark deeds 10% darker."),
    dict(id="root_fossil", name="Root Fossil", world="pokemon", category="treasure", price=1800,
         tags=["fossil", "rare", "stone"], desc="A fossilized root of an ancient sea plant. Museums pay handsomely."),
    dict(id="red_orb", name="Red Orb", world="pokemon", category="treasure", price=4200,
         tags=["orb", "legendary", "rare"], desc="A deep-red orb said to stir the continent-maker from its slumber."),
    dict(id="blue_orb", name="Blue Orb", world="pokemon", category="treasure", price=4200,
         tags=["orb", "legendary", "rare"], desc="A deep-blue orb said to call the sea-bringer. Keep it dry."),
    dict(id="technical_machine", name="Technical Machine", world="pokemon", category="material", price=1400,
         tags=["technology", "rare"], desc="A disc holding a battle technique. Single use, endless arguments."),
    dict(id="leftovers", name="Leftovers", world="pokemon", category="food", price=900,
         tags=["food", "healing", "rare"], desc="Somebody's unfinished meal that somehow never runs out."),
    dict(id="amulet_coin", name="Amulet Coin", world="pokemon", category="accessory", price=1200,
         tags=["coin", "lucky"], desc="A charm that doubles any payday. Merchants pretend not to want one."),
    dict(id="shell_bell", name="Shell Bell", world="pokemon", category="accessory", price=950,
         tags=["shell", "healing"], desc="A chime of pink shells that soothes wounds with every ring."),
    dict(id="soda_pop", name="Soda Pop", world="pokemon", category="food", price=120,
         tags=["food", "cold", "sweet"], desc="A fizzy drink best served ice-cold at a bicycle race."),
    dict(id="lemonade", name="Lemonade", world="pokemon", category="food", price=180,
         tags=["food", "cold", "sweet"], desc="A very sweet can of lemonade from a rooftop vending machine."),
    # ---- dragon_ball ----
    dict(id="hearty_ramen", name="Hearty Ramen", world="dragon_ball", category="food", price=110,
         tags=["food", "noodles", "hot"], desc="A steaming bowl big enough to satisfy... well, not a Saiyan."),
    dict(id="dino_drumstick", name="Dino Drumstick", world="dragon_ball", category="food", price=260,
         tags=["food", "meat", "huge"], desc="A roast drumstick the size of a small child. Serves one Saiyan."),
    dict(id="mega_burger", name="Mega Burger", world="dragon_ball", category="food", price=140,
         tags=["food", "meat"], desc="A double-stacked burger from West City's finest drive-through."),
    dict(id="marbled_beef", name="Marbled Beef", world="dragon_ball", category="food", price=420,
         tags=["food", "meat", "rare"], desc="Premium marbled beef. Ox King insists it be grilled, never boiled."),
    dict(id="fresh_milk", name="Fresh Milk", world="dragon_ball", category="food", price=70,
         tags=["food", "healing"], desc="Delivered door to door by a very fast paper boy in training."),
    dict(id="chilled_soda", name="Chilled Soda", world="dragon_ball", category="food", price=90,
         tags=["food", "cold", "sweet"], desc="An ice-cold can of soda. The official drink of tournament spectators."),
    dict(id="giant_river_fish", name="Giant River Fish", world="dragon_ball", category="food", price=380,
         tags=["food", "fish", "huge"], desc="Caught bare-handed by tail-fishing. Feeds a village or one hungry boy."),
    dict(id="zeni_coin", name="Zeni Coin", world="dragon_ball", category="treasure", price=600,
         tags=["coin", "valuable"], desc="A gleaming gold zeni. Capsule Corp pocket change."),
    dict(id="ancient_idol", name="Ancient Idol", world="dragon_ball", category="treasure", price=2600,
         tags=["rare", "valuable", "gold"], desc="A golden idol looted from a desert vault. Pilaf wants it back."),
    # ---- naruto ----
    dict(id="fuma_shuriken", name="Fuma Shuriken", world="naruto", category="weapon", price=950,
         tags=["ninja", "throwing", "blade", "huge"], stats={"atk": 6},
         desc="A folding windmill shuriken. Demon wind included at no extra cost."),
    dict(id="makibishi_spikes", name="Makibishi Spikes", world="naruto", category="consumable", price=90,
         tags=["ninja", "trap"], desc="Scatter behind you and listen for the footsteps to stop."),
    dict(id="substitution_log", name="Substitution Log", world="naruto", category="consumable", price=150,
         tags=["ninja", "escape", "wood"], desc="Guaranteed to take exactly one hit for you. The log understands."),
    dict(id="field_medkit", name="Field Medkit", world="naruto", category="consumable", price=240,
         tags=["healing", "medical"], desc="Bandages, salves and a stern note about not overdoing it."),
    dict(id="gama_wallet", name="Gama-chan Wallet", world="naruto", category="accessory", price=750,
         tags=["lucky", "cute"], desc="A plump frog purse that guards its coins jealously."),
    dict(id="dango_skewer", name="Dango Skewer", world="naruto", category="food", price=60,
         tags=["food", "sweet"], desc="Three colorful rice dumplings on a stick. A certain jonin's favorite."),
    dict(id="ryo_pouch", name="Ryo Pouch", world="naruto", category="treasure", price=800,
         tags=["coin", "valuable"], desc="A mission-reward pouch heavy with ryo. Don't let Naruto borrow it."),
]


def main() -> None:
    path = ROOT / "data/items.json"
    doc = json.loads(path.read_text(encoding="utf-8"))
    by_id = {i["id"]: i for i in doc["items"]}
    added, updated = 0, 0
    for item in NEW_ITEMS:
        if item["id"] in by_id:
            by_id[item["id"]].update(item)
            updated += 1
        else:
            doc["items"].append(item)
            added += 1
    path.write_text(json.dumps(doc, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"added {added}, updated {updated}, total {len(doc['items'])}")


if __name__ == "__main__":
    main()
