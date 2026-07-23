"""Idempotent wiring for the Realm of the Mad God (rotmg) world.

Strips every rotmg-owned entry from data/*.json and re-adds them, so it is safe
to edit + re-run. This is the permanent record of what the world contains and how
it is balanced. Matches each file's indent (heroes/enemies/items/worlds = 1,
customer_visuals = 2) and always writes LF.

ROTMG design notes baked in below:
- Every hero is a SHOOTER: combat.basic.kind == "ranged" (hold-to-fire, auto-aim
  at nearest enemy) with per-weapon shots/spread/pierce/speed/range/fire_rate.
- Weapon feel: bow = 1 long piercing shot; sword = fast short bolt; staff =
  2-shot spread; dagger = very fast short shot; katana = 2-shot tight spread.
- Oryx_boss_1 is always the debut boss (world flag boss_random_after_first),
  then a random boss from the rest of the pool.
"""
import json, io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
WORLD = "rotmg"


def load(name):
    return json.load(io.open(os.path.join(DATA, name), encoding="utf-8"))


def save(name, obj, indent):
    with io.open(os.path.join(DATA, name), "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, indent=indent, ensure_ascii=False)
        f.write("\n")


# ---------------------------------------------------------------- heroes
# color = projectile / FX tint. All shooters. dmg arrays are per-shot (x/10 mult).
HEROES = [
 {"id":"archer","name":"Archer","world":WORLD,"weapon_type":"bow","color":"#5bbf4c",
  "base_stats":{"hp":110,"atk":12,"def":5,"spd":125},
  "combat":{
   "basic":{"kind":"ranged","shots":1,"spread":0,"pierce":2,"speed":360,"range":320,"fire_rate":0.40,"dmg":[12]},
   "special":{"kind":"projectile","name":"Piercing Shot","dmg":30,"speed":420,"cost":30},
   "dodge":{"kind":"roll","distance":72,"iframes":0.35},
   "finisher":{"name":"Arrow Storm","dmg":90,"radius":120,"beam":True}},
  "hire_cost":150,
  "bio":"Loosens arrows from the tree line and never, ever haggles up front.",
  "guild_line":"One quiver, one price. Don't make me count them."},

 {"id":"knight","name":"Knight","world":WORLD,"weapon_type":"sword","color":"#c2c6d6",
  "base_stats":{"hp":170,"atk":11,"def":11,"spd":110},
  "combat":{
   "basic":{"kind":"ranged","shots":1,"spread":0,"pierce":0,"speed":330,"range":150,"fire_rate":0.22,"dmg":[9]},
   "special":{"kind":"burst","name":"Shield Bash","dmg":22,"radius":72,"cost":35},
   "dodge":{"kind":"guard","reduction":0.75},
   "finisher":{"name":"Bulwark","dmg":80,"radius":100}},
  "hire_cost":400,
  "bio":"Heavy plate, heavier stubbornness. Stands in the front and takes the hits.",
  "guild_line":"Behind me. Coin talk later."},

 {"id":"wizard","name":"Wizard","world":WORLD,"weapon_type":"staff","color":"#4a80e0",
  "base_stats":{"hp":90,"atk":16,"def":3,"spd":120},
  "combat":{
   "basic":{"kind":"ranged","shots":2,"spread":14,"pierce":0,"speed":320,"range":280,"fire_rate":0.30,"dmg":[8]},
   "special":{"kind":"burst","name":"Spell Bomb","dmg":40,"radius":96,"cost":40},
   "dodge":{"kind":"roll","distance":68,"iframes":0.32},
   "finisher":{"name":"Arcane Nova","dmg":95,"radius":130}},
  "hire_cost":500,
  "bio":"A glass cannon in a pointy hat. Enormous damage, papery constitution.",
  "guild_line":"I could vaporize your inventory. I'd rather buy it."},

 {"id":"rogue","name":"Rogue","world":WORLD,"weapon_type":"dagger","color":"#d0503a",
  "base_stats":{"hp":100,"atk":10,"def":4,"spd":142},
  "combat":{
   "basic":{"kind":"ranged","shots":1,"spread":0,"pierce":0,"speed":340,"range":180,"fire_rate":0.18,"dmg":[7]},
   "special":{"kind":"dash","name":"Cloak Strike","dmg":24,"distance":100,"cost":30},
   "dodge":{"kind":"vanish","distance":80,"iframes":0.40},
   "finisher":{"name":"Backstab Flurry","dmg":85,"radius":90}},
  "hire_cost":350,
  "bio":"Cloak on, prices memorized, gone before you finish the sentence.",
  "guild_line":"You didn't see me take the discount."},

 {"id":"necromancer","name":"Necromancer","world":WORLD,"weapon_type":"staff","color":"#9b59b6",
  "base_stats":{"hp":95,"atk":15,"def":4,"spd":120},
  "combat":{
   "basic":{"kind":"ranged","shots":2,"spread":10,"pierce":0,"speed":320,"range":270,"fire_rate":0.32,"dmg":[8]},
   "special":{"kind":"burst","name":"Soul Harvest","dmg":34,"radius":104,"cost":38},
   "dodge":{"kind":"roll","distance":66,"iframes":0.32},
   "finisher":{"name":"Grave Bloom","dmg":90,"radius":120}},
  "hire_cost":500,
  "bio":"Sells you a plushie, harvests the ambient dread. Fair trade.",
  "guild_line":"The dead don't tip. You, however..."},

 {"id":"ninja","name":"Ninja","world":WORLD,"weapon_type":"katana","color":"#5aa0ff",
  "base_stats":{"hp":108,"atk":12,"def":5,"spd":136},
  "combat":{
   "basic":{"kind":"ranged","shots":2,"spread":8,"pierce":0,"speed":340,"range":200,"fire_rate":0.24,"dmg":[9]},
   "special":{"kind":"projectile","name":"Star Toss","dmg":26,"speed":460,"cost":28},
   "dodge":{"kind":"vanish","distance":84,"iframes":0.40},
   "finisher":{"name":"Shadow Barrage","dmg":88,"radius":100,"beam":True}},
  "hire_cost":450,
  "bio":"Throws stars, keeps secrets, refuses to explain the katana on a shooter.",
  "guild_line":"Swift blade. Swifter refund policy."},
]

# ---------------------------------------------------------------- enemies
# Realm/godland horde: shooter-heavy for the ROTMG bullet feel. size = collision
# floor (the sprite measures its own hurtbox). loot ids resolve in items step.
def _en(id, name, hp, atk, spd, behavior, size, color, loot, gold):
    return {"id": id, "name": name, "world": WORLD, "hp": hp, "atk": atk, "spd": spd,
            "behavior": behavior, "size": size, "color": color, "loot": loot, "gold": gold}

ENEMIES = [
 _en("red_demon","Red Demon",95,16,72,"shooter",34,"#e03a2a",
     [["hp_potion",0.18],["atk_potion",0.05],["doom_bow",0.02]],[24,46]),
 _en("crystal_scorpion","Crystal Scorpion",70,18,98,"lunger",30,"#4aa0e0",
     [["hp_potion",0.14],["def_potion",0.04]],[18,34]),
 _en("crystal_cyclops","Crystal Cyclops",165,20,54,"tank",42,"#b060d0",
     [["hp_potion",0.2],["life_potion",0.02],["acropolis_armor",0.02]],[30,55]),
 _en("crystal_lizard","Crystal Lizard",80,14,122,"chaser",30,"#5bbf4c",
     [["hp_potion",0.12],["spd_potion",0.04]],[16,30]),
 _en("megamoth_larva","Megamoth Larva",45,10,42,"creeper",22,"#4a80e0",
     [["hp_potion",0.1]],[8,18]),
 _en("swoll_fairy","Swoll Fairy",60,12,92,"skitter_shooter",26,"#f0d040",
     [["hp_potion",0.14],["wis_potion",0.04]],[14,28]),
 _en("snake_sentry","Snake Sentry",78,15,58,"shooter",32,"#d04040",
     [["hp_potion",0.16],["dex_potion",0.04]],[18,34]),
 _en("ent_ancient","Ent Ancient",150,16,46,"shooter",42,"#8a6a3a",
     [["hp_potion",0.18],["vit_potion",0.04],["leaf_bow",0.03]],[26,48]),
 _en("queen_bee","Queen Bee",85,14,112,"swooper",28,"#f0c020",
     [["hp_potion",0.14],["spd_potion",0.05]],[16,32]),
 _en("spider_queen","Spider Queen",115,15,80,"skitter_shooter",38,"#6abf6a",
     [["hp_potion",0.18],["ghostly_cloak",0.02]],[24,44]),
 _en("corruption_phantom","Corruption Phantom",90,17,86,"teleporter",34,"#d03060",
     [["hp_potion",0.16],["mp_potion",0.12]],[20,40]),
 _en("spoiled_creampuff","Spoiled Creampuff",60,10,70,"splitter",24,"#f0d8e0",
     [["hp_potion",0.12]],[10,22]),
]
# ---------------------------------------------------------------- bosses
# attacks: position in the list -> archetype (idx%4): 0 slam, 1 radial volley,
# 2 charge, 3 summon/storm. 4 themed names per boss = the full varied kit. Every
# boss drops world_shard_rotmg @1.0 (any boss clears the expedition).
def _boss(id, name, hp, atk, spd, size, color, attacks, phases, sig, sig_chance, gold, telegraph=0.6):
    return {"id": id, "name": name, "world": WORLD, "hp": hp, "atk": atk, "spd": spd,
            "behavior": "boss_ranged", "size": size, "color": color,
            "loot": [["world_shard_rotmg", 1.0], [sig, sig_chance], ["life_potion", 0.25]],
            "gold": gold, "attacks": attacks, "telegraph": telegraph, "phases": phases}

BOSSES = [
 _boss("oryx","Oryx the Mad God",2200,30,72,60,"#3a3444",
   ["ground_pound","fire_shotgun","oryx_charge","summon_minions"],3,"doom_bow",0.5,[3600,5000],0.55),
 _boss("cube_god","Cube God",1600,26,56,52,"#2b6cf0",
   ["cube_slam","blue_burst","cube_charge","spawn_overseers"],2,"cosmic_staff",0.5,[3000,4200]),
 _boss("rock_dragon","Rock Dragon",1750,28,66,54,"#e0862a",
   ["tail_slam","ember_ring","rock_charge","summon_sparks"],2,"attack_ring",0.5,[3000,4400]),
 _boss("avatar","Avatar of the Forgotten King",1850,28,60,54,"#c8ccd8",
   ["forgotten_slam","soul_volley","avatar_dash","raise_dead"],3,"hydra_armor",0.5,[3400,4800]),
 _boss("grand_sphinx","Grand Sphinx",1500,25,62,50,"#e0b840",
   ["sand_slam","spiral_burst","sphinx_charge","summon_scarabs"],2,"recompense_wand",0.5,[2800,4000]),
 _boss("ghost_ship","Ghost Ship",1600,26,50,56,"#b8a06a",
   ["broadside_slam","cannon_volley","ghost_ram","spawn_crew"],2,"coral_bow",0.5,[3000,4200]),
 _boss("lord_lost_lands","Lord of the Lost Lands",1900,30,60,56,"#7a4ca0",
   ["quake_slam","bolt_volley","lord_charge","summon_beasts"],2,"acropolis_armor",0.5,[3400,4800]),
 _boss("oryx_2","Oryx the Mad God 2",2000,30,76,52,"#222028",
   ["star_slam","stasis_volley","o2_charge","henchmen"],3,"sword_splendor",0.5,[3600,5000],0.55),
 _boss("oryx_3","Oryx, Exalted",2400,32,72,56,"#d24040",
   ["exalt_slam","blade_volley","o3_dash","summon_guards"],3,"foul_dagger",0.5,[4000,5400],0.5),
]
# ---------------------------------------------------------------- items
# items.json sorts each object's keys alphabetically -> build them that way so the
# appended block matches the file convention. Effects use only keys combat_hero
# actually handles (heal/meter/buff_atk/buff_def/ranged_damage).
def _it(id, name, category, price, desc, tags, appeal=None, stats=None, effect=None,
        slot=None, sellable=None):
    d = {"category": category, "desc": desc, "id": id, "name": name,
         "price": float(price), "tags": tags, "world": WORLD}
    if appeal is not None: d["appeal"] = appeal
    if stats is not None: d["stats"] = stats
    if effect is not None: d["effect"] = effect
    if slot is not None: d["slot"] = slot
    if sellable is not None: d["sellable"] = sellable
    return dict(sorted(d.items()))

ITEMS = [
 # --- consumables (the ROTMG potions) ---
 _it("hp_potion","Health Potion","consumable",60,"The little red bottle every realm run leans on. Down it, live.",["potion","healing"],appeal={"cozy":1.0},effect={"heal":80.0}),
 _it("mp_potion","Magic Potion","consumable",60,"Blue and bracing. Tops off the mana you were about to need.",["potion","mana"],appeal={"modern":1.0},effect={"meter":60.0}),
 _it("life_potion","Potion of Life","consumable",900,"The grind in a bottle. A permanent +5 to the faithful; a full heal to the desperate.",["potion","life","rare"],appeal={"intense":2.0},effect={"heal":999.0}),
 _it("atk_potion","Potion of Attack","consumable",250,"Liquid aggression. Your shots hit noticeably harder for a while.",["potion","attack"],appeal={"intense":1.0},effect={"buff_atk":4.0}),
 _it("def_potion","Potion of Defense","consumable",250,"Drink to shrug off the bullet hell a little longer.",["potion","defense"],appeal={"intense":1.0},effect={"buff_def":4.0}),
 _it("spd_potion","Potion of Speed","consumable",200,"Kiting fuel. The realm rewards the fleet of foot.",["potion","speed"],appeal={"modern":1.0},effect={"meter":40.0}),
 _it("dex_potion","Potion of Dexterity","consumable",220,"Steadier hands, faster fire — loose an extra shot on the house.",["potion","dexterity"],appeal={"modern":1.0},effect={"ranged_damage":30.0}),
 _it("vit_potion","Potion of Vitality","consumable",180,"Knits wounds closed between waves. Modest, reliable.",["potion","vitality"],appeal={"cozy":1.0},effect={"heal":50.0}),
 _it("wis_potion","Potion of Wisdom","consumable",200,"Sharpens the mind and hurries your ability back.",["potion","wisdom"],appeal={"modern":1.0},effect={"meter":50.0}),
 # --- weapons ---
 _it("leaf_bow","Leaf Bow","weapon",300,"A humble starter bow. Fires true; asks little.",["weapon","bow"],appeal={"retro":1.0},stats={"atk":3.0},slot="weapon"),
 _it("coral_bow","Coral Bow","weapon",1400,"Three reef-bright arrows at once. A realm-runner's workhorse.",["weapon","bow"],appeal={"intense":1.0},stats={"atk":6.0},slot="weapon"),
 _it("doom_bow","Doom Bow","weapon",3200,"One enormous piercing shot. Ghost King's gift, coveted realm-wide.",["weapon","bow","ut"],appeal={"intense":2.0},stats={"atk":9.0},slot="weapon"),
 _it("cosmic_staff","Staff of the Cosmic Whole","weapon",1800,"Twin bolts of the void. The Cube God's parting insult.",["weapon","staff"],appeal={"intense":1.0},stats={"atk":7.0},slot="weapon"),
 _it("recompense_wand","Wand of Recompense","weapon",1200,"A single piercing lance of light. Long reach, no waste.",["weapon","wand"],appeal={"retro":1.0},stats={"atk":6.0},slot="weapon"),
 _it("sword_splendor","Sword of Splendor","weapon",1600,"Close, fast, relentless. For the shopkeeper who leads with the chin.",["weapon","sword"],appeal={"intense":1.0},stats={"atk":7.0},slot="weapon"),
 _it("foul_dagger","Dagger of Foul Malevolence","weapon",1300,"Wicked and quick. Rude to the customers, ruder to the horde.",["weapon","dagger"],appeal={"intense":1.0},stats={"atk":6.0},slot="weapon"),
 _it("doku_katana","Doku no Ken","weapon",1700,"A poison-edged katana that throws a tight double arc.",["weapon","katana"],appeal={"intense":1.0},stats={"atk":7.0},slot="weapon"),
 # --- armor ---
 _it("hydra_armor","Hydra Skin Armor","armor",1500,"Supple scaled leather. Light on the shoulders, heavy on survival.",["armor","leather"],appeal={"retro":1.0},stats={"def":7.0},slot="armor"),
 _it("acropolis_armor","Acropolis Armor","armor",1900,"Columns of plate. Stands where lesser shopkeepers fall.",["armor","heavy"],appeal={"intense":1.0},stats={"def":9.0},slot="armor"),
 _it("sorcerer_robe","Robe of the Grand Sorcerer","armor",1600,"Thin cloth, enormous power. Glass-cannon chic.",["armor","robe"],appeal={"modern":1.0},stats={"def":4.0,"atk":2.0},slot="armor"),
 _it("leviathan_armor","Leviathan Armor","armor",2600,"The heaviest plate in the realm. Practically a walking wall.",["armor","heavy","ut"],appeal={"intense":2.0},stats={"def":10.0},slot="armor"),
 # --- abilities ---
 _it("golden_quiver","Quiver of Thunder","accessory",900,"Looses a shocking bolt that paralyzes. Standard-issue for archers.",["ability","quiver"],appeal={"intense":1.0},stats={"atk":3.0},slot="charm"),
 _it("ghostly_cloak","Cloak of Ghostly Concealment","accessory",900,"Slip out of sight when the bullets get personal.",["ability","cloak"],appeal={"modern":1.0},stats={"spd":3.0},slot="charm"),
 _it("soul_skull","Skull of Corrupted Souls","accessory",950,"Drains the fallen to mend the wielder. The necromancer's staple.",["ability","skull"],appeal={"intense":1.0},stats={"atk":3.0},slot="charm"),
 # --- rings ---
 _it("attack_ring","Ring of Unbound Attack","accessory",1100,"Raw offense on a band. Simple, effective, always in demand.",["ring","attack"],appeal={"modern":1.0},stats={"atk":4.0},slot="accessory"),
 _it("defense_ring","Ring of Unbound Defense","accessory",1100,"A band of solid warding against the worst of the spread.",["ring","defense"],appeal={"modern":1.0},stats={"def":4.0},slot="accessory"),
 _it("speed_ring","Ring of Unbound Speed","accessory",1000,"For the kiter who is never quite where the bullets expect.",["ring","speed"],appeal={"modern":1.0},stats={"spd":3.0},slot="accessory"),
 _it("unbound_health","Ring of Decades","accessory",1800,"Ten years of vitality poured into one band. +60 to the health bar.",["ring","life","rare"],appeal={"intense":1.0},stats={"hp":60.0},slot="accessory"),
 # --- completion token (kept out of the live catalog; drops from any boss) ---
 _it("world_shard_rotmg","World Shard: The Realm","key",0,"A splinter of the Realm sky, still humming with Oryx's madness.",["world_shard"],sellable=False),
]
# ---------------------------------------------------------------- customers
# Every ROTMG class doubles as a shop customer (fellow adventurers browsing).
_CUST = ["archer","assassin","bard","huntress","kensei","knight","mystic","necromancer",
         "ninja","paladin","priest","rogue","samurai","sorcerer","summoner","trickster",
         "warrior","wizard","void_huntsman"]
_CUST_NAMES = {"void_huntsman": "Void Huntsman"}
CUSTOMERS = [{
    "slug": s, "name": _CUST_NAMES.get(s, s.capitalize()), "world": WORLD,
    "static": f"res://assets/franchises/rotmg/processed/customers/{s}.png", "manifest": ""
} for s in _CUST]

# ---------------------------------------------------------------- world entry
_LOC = "res://assets/locations/rotmgdungeon/processed"
_SALEABLE = [i["id"] for i in ITEMS if i.get("sellable") is not False and i["category"] != "key"]
WORLD_ENTRY = {
 "id": WORLD,
 "chapter": 9,
 "name": "Realm of the Mad God",
 "location": "The Realm",
 "hero": "archer",
 "boss": "oryx",
 "boss_rotation": ["oryx", "cube_god", "rock_dragon", "avatar", "grand_sphinx",
                   "ghost_ship", "lord_lost_lands", "oryx_2", "oryx_3"],
 "boss_random_after_first": True,
 "enemies": ["red_demon", "crystal_scorpion", "crystal_cyclops", "crystal_lizard",
             "megamoth_larva", "swoll_fairy", "snake_sentry", "ent_ancient",
             "queen_bee", "spider_queen", "corruption_phantom", "spoiled_creampuff"],
 "repair_cost": 400000,
 "world_shard": "world_shard_rotmg",
 "rooms": 7,
 "floor_color": "#3c6a34",
 "wall_color": "#241f30",
 "accent_color": "#c8a848",
 "dungeon_desc": "Open godlands under a mad god's gaze: swarming shooters, bullet "
                 "storms, and Oryx waiting at the end of every run.",
 "market_goods": _SALEABLE,
 "heroes": ["archer", "knight", "wizard", "rogue", "necromancer", "ninja"],
 "obstacle_props": [
   f"{_LOC}/prop_tree.png", f"{_LOC}/prop_tree_small.png",
   f"{_LOC}/prop_bush.png", f"{_LOC}/prop_bush2.png"],
 "room_backgrounds": {
   "start":    [f"{_LOC}/start_grass.png"],
   "combat":   [f"{_LOC}/combat_grass.png", f"{_LOC}/combat_godland.png",
                f"{_LOC}/combat_desert.png", f"{_LOC}/combat_forest.png"],
   "treasure": [f"{_LOC}/treasure_marble.png"],
   "boss":     [f"{_LOC}/boss_abyss.png", f"{_LOC}/boss_lava.png"],
 },
}


# --- 2026-07-23 playtest feedback -----------------------------------------
# All heroes roll (no block); every hero bullet + enemy shot uses the shared
# move_VFX shot strips (directional 8-row sheets); every enemy is a shooter.
_FLAME = "res://assets/shared/effects/processed/shot_flame.png"    # 16x16, 4 frames x 8 dirs
_BUBBLE = "res://assets/shared/effects/processed/shot_bubble.png"  # 32x24, 2 frames x 8 dirs
for _h in HEROES:
    _h["combat"]["dodge"] = {"kind": "roll", "distance": 74, "iframes": 0.35}
    _b = _h["combat"]["basic"]
    _b["sprite"], _b["sprite_frames"], _b["sprite_dirs"], _b["sprite_fps"] = _FLAME, 4, 8, 18
# mobile creatures strafe-and-shoot; the big ones plant and shoot — all fire bullets
_SKITTER = {"crystal_scorpion", "crystal_lizard", "queen_bee", "swoll_fairy",
            "corruption_phantom", "megamoth_larva"}
for _e in ENEMIES:
    _e["behavior"] = "skitter_shooter" if _e["id"] in _SKITTER else "shooter"
    _e["shot_vfx"], _e["shot_frames"], _e["shot_dirs"], _e["shot_fps"] = _BUBBLE, 2, 8, 10


def wire_heroes():
    h = load("heroes.json")
    h["heroes"] = [x for x in h["heroes"] if x.get("world") != WORLD] + HEROES
    save("heroes.json", h, 1)
    print(f"heroes: wired {len(HEROES)}")


def wire_enemies():
    if not ENEMIES and not BOSSES:
        return
    e = load("enemies.json")
    e["enemies"] = [x for x in e["enemies"] if x.get("world") != WORLD] + ENEMIES
    e["bosses"] = [x for x in e.get("bosses", []) if x.get("world") != WORLD] + BOSSES
    save("enemies.json", e, 1)
    print(f"enemies: wired {len(ENEMIES)} enemies + {len(BOSSES)} bosses")


def wire_items():
    if not ITEMS:
        return
    it = load("items.json")
    it["items"] = [x for x in it["items"] if x.get("world") != WORLD] + ITEMS
    save("items.json", it, 1)
    print(f"items: wired {len(ITEMS)}")


def wire_customers():
    if not CUSTOMERS:
        return
    cv = load("customer_visuals.json")
    cv["pool"] = [x for x in cv["pool"] if x.get("world") != WORLD] + CUSTOMERS
    save("customer_visuals.json", cv, 2)
    print(f"customers: wired {len(CUSTOMERS)}")


def wire_world():
    if WORLD_ENTRY is None:
        return
    w = load("worlds.json")
    w["worlds"] = [x for x in w["worlds"] if x.get("id") != WORLD] + [WORLD_ENTRY]
    save("worlds.json", w, 1)
    print("world: wired rotmg entry")


if __name__ == "__main__":
    wire_heroes()
    wire_enemies()
    wire_items()
    wire_customers()
    wire_world()
    print("done.")
