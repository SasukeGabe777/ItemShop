extends Node
## GameState: campaign-wide progress that isn't owned by a more specific system.
## Merchant level, flags, encyclopedia, met characters, unlocks, statistics.

signal merchant_level_up(new_level: int)
signal flag_set(flag: String)

var campaign_active: bool = false
var endless_mode: bool = false
var current_slot: int = 0
var game_title: String = ""

var merchant_level: int = 1
var merchant_xp: int = 0
var shop_level: int = 1

var flags: Dictionary = {}            # generic story/tutorial flags
var met_heroes: Array = []            # hero ids greeted at least once
var encyclopedia: Array = []          # item ids ever handled
var known_customers: Array = []       # customer ids served at least once
var decorations: Array = []           # cosmetic decoration ids owned
var tutorials_seen: Array = []
var stats: Dictionary = {"sales": 0, "perfect_deals": 0, "orders_done": 0, "expeditions": 0, "bosses_defeated": 0, "days_played": 0}


func _ready() -> void:
	game_title = ProjectSettings.get_setting("application/config/name", "Crossroads")


func reset_campaign() -> void:
	campaign_active = true
	endless_mode = false
	merchant_level = 1
	merchant_xp = 0
	shop_level = 1
	flags.clear()
	met_heroes.clear()
	encyclopedia.clear()
	known_customers.clear()
	decorations.clear()
	tutorials_seen.clear()
	stats = {"sales": 0, "perfect_deals": 0, "orders_done": 0, "expeditions": 0, "bosses_defeated": 0, "days_played": 0}


func add_merchant_xp(amount: int) -> void:
	merchant_xp += amount
	while merchant_xp >= xp_for_next_level():
		merchant_xp -= xp_for_next_level()
		merchant_level += 1
		merchant_level_up.emit(merchant_level)


func xp_for_next_level() -> int:
	var mx: Dictionary = ContentDatabase.bal("merchant_xp", {})
	var base := int(mx.get("level_curve_base", 100))
	var mult := float(mx.get("level_curve_mult", 1.35))
	return int(base * pow(mult, merchant_level - 1))


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_set.emit(flag)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func meet_hero(hero_id: String) -> bool:
	if hero_id in met_heroes:
		return false
	met_heroes.append(hero_id)
	return true


func learn_item(item_id: String) -> void:
	if not (item_id in encyclopedia):
		encyclopedia.append(item_id)


func know_customer(customer_id: String) -> void:
	if not (customer_id in known_customers):
		known_customers.append(customer_id)


func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


func to_save() -> Dictionary:
	return {
		"campaign_active": campaign_active, "endless_mode": endless_mode,
		"merchant_level": merchant_level, "merchant_xp": merchant_xp,
		"shop_level": shop_level, "flags": flags, "met_heroes": met_heroes,
		"encyclopedia": encyclopedia, "known_customers": known_customers,
		"decorations": decorations, "tutorials_seen": tutorials_seen, "stats": stats,
	}


func from_save(d: Dictionary) -> void:
	campaign_active = bool(d.get("campaign_active", false))
	endless_mode = bool(d.get("endless_mode", false))
	merchant_level = int(d.get("merchant_level", 1))
	merchant_xp = int(d.get("merchant_xp", 0))
	shop_level = int(d.get("shop_level", 1))
	flags = d.get("flags", {})
	met_heroes = d.get("met_heroes", [])
	encyclopedia = d.get("encyclopedia", [])
	known_customers = d.get("known_customers", [])
	decorations = d.get("decorations", [])
	tutorials_seen = d.get("tutorials_seen", [])
	stats = d.get("stats", {})
