@tool
extends CCSEntityFactoryTab
## Hero Factory: build a hero's animation set from a raw sheet and upsert the
## data/heroes.json entry. Only name/world/animations are required — combat
## numbers get playable defaults and a needs_ai_balance marker for later
## balancing passes.

const WEAPON_TYPES := ["sword", "keyblade", "gunblade", "buster_sword", "staff", "bow", "spear", "fists"]

var _hp_spin: SpinBox
var _atk_spin: SpinBox
var _def_spin: SpinBox
var _spd_spin: SpinBox
var _hire_spin: SpinBox
var _weapon_option: OptionButton


func _cfg_type_label() -> String:
	return "Hero"


func _cfg_data_path() -> String:
	return CCSAssetPaths.DATA_HEROES


func _cfg_array_key() -> String:
	return "heroes"


func _cfg_schema_tag() -> String:
	return "crossroads.heroes.v1"


func _cfg_required_anims() -> Array[String]:
	return ["idle_down", "idle_up", "idle_side", "walk_down", "walk_up", "walk_side"]


func _cfg_optional_anims() -> Array[String]:
	return [
		"idle_left", "idle_right", "walk_left", "walk_right",
		"attack_down", "attack_up", "attack_side", "attack_left", "attack_right",
		"special", "hurt", "defeat", "victory",
	]


func _cfg_entries() -> Array:
	return scan.heroes_raw


func _cfg_default_entry(id: String, name: String, world: String) -> Dictionary:
	return {
		"id": id, "name": name, "world": world,
		"weapon_type": "sword", "color": "#c0c0c0",
		"base_stats": {"hp": 100, "atk": 10, "def": 5, "spd": 120},
		"combat": {
			"basic": {"hits": 2, "dmg": [8, 12], "range": 26, "arc": 100},
			"special": {"kind": "burst", "name": "Special", "dmg": 20, "radius": 60, "cost": 35},
			"dodge": {"kind": "roll", "distance": 70, "iframes": 0.35},
			"finisher": {"name": "Finisher", "dmg": 60, "radius": 90},
		},
		"default_equipment": {},
		"hire_cost": 100,
		"bio": "", "guild_line": "",
		"needs_ai_balance": true,
	}


func _build_extra_fields(box: HFlowContainer) -> void:
	_weapon_option = add_option(box, "Weapon", WEAPON_TYPES)
	_hp_spin = add_spin(box, "HP", 1, 999, 100)
	_atk_spin = add_spin(box, "ATK", 0, 99, 10)
	_def_spin = add_spin(box, "DEF", 0, 99, 5)
	_spd_spin = add_spin(box, "Move Speed", 10, 400, 120)
	_hire_spin = add_spin(box, "Hire Cost", 0, 99999, 100)


func _apply_extra_fields(entry: Dictionary) -> void:
	entry["weapon_type"] = option_value(_weapon_option)
	var stats: Dictionary = entry.get("base_stats", {})
	stats["hp"] = int(_hp_spin.value)
	stats["atk"] = int(_atk_spin.value)
	stats["def"] = int(_def_spin.value)
	stats["spd"] = int(_spd_spin.value)
	entry["base_stats"] = stats
	entry["hire_cost"] = int(_hire_spin.value)


func _load_extra_fields(entry: Dictionary) -> void:
	select_option(_weapon_option, String(entry.get("weapon_type", "sword")))
	var stats: Dictionary = entry.get("base_stats", {})
	_hp_spin.value = int(stats.get("hp", 100))
	_atk_spin.value = int(stats.get("atk", 10))
	_def_spin.value = int(stats.get("def", 5))
	_spd_spin.value = int(stats.get("spd", 120))
	_hire_spin.value = int(entry.get("hire_cost", 100))
