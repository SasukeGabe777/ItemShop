@tool
extends CCSEntityFactoryTab
## Enemy Factory: assign idle/move/attack/defeat animations from a sheet and
## upsert data/enemies.json. AI comes from the existing reusable behavior
## vocabulary (chaser, shooter, ...) — never a per-enemy script. The Boss
## checkbox routes the entry into the bosses array instead.

## Reusable AI behaviors implemented by scripts/entities/enemy.gd.
const BEHAVIORS := [
	"chaser", "tank", "lunger", "shooter", "skitter_shooter", "bomber",
	"shy_ghost", "swooper", "creeper", "ambusher", "splitter", "teleporter", "shell",
]

var _hp_spin: SpinBox
var _atk_spin: SpinBox
var _spd_spin: SpinBox
var _size_spin: SpinBox
var _behavior_option: OptionButton
var _boss_check: CheckBox


func _cfg_type_label() -> String:
	return "Enemy"


func _cfg_data_path() -> String:
	return CCSAssetPaths.DATA_ENEMIES


func _cfg_array_key() -> String:
	return "bosses" if _boss_check != null and _boss_check.button_pressed else "enemies"


func _cfg_schema_tag() -> String:
	return "crossroads.enemies.v1"


func _cfg_required_anims() -> Array[String]:
	return ["idle", "move", "attack", "defeat"]


func _cfg_optional_anims() -> Array[String]:
	return [
		"hurt", "idle_down", "idle_up", "idle_side", "walk_down", "walk_up",
		"walk_side", "attack_1",
	]


func _cfg_entries() -> Array:
	var out: Array = []
	out.append_array(scan.enemies_raw)
	out.append_array(scan.bosses_raw)
	return out


func _cfg_default_entry(id: String, name: String, world: String) -> Dictionary:
	var entry := {
		"id": id, "name": name, "world": world,
		"hp": 10, "atk": 1, "spd": 50,
		"behavior": "chaser", "size": 14, "color": "#888888",
		"loot": [], "gold": [1, 5],
		"needs_ai_balance": true,
	}
	if _boss_check != null and _boss_check.button_pressed:
		entry["attacks"] = ["slam"]
		entry["telegraph"] = 0.8
	return entry


func _build_extra_fields(box: HFlowContainer) -> void:
	_behavior_option = add_option(box, "Behavior (AI)", BEHAVIORS)
	_hp_spin = add_spin(box, "HP", 1, 9999, 10)
	_atk_spin = add_spin(box, "Damage", 0, 999, 1)
	_spd_spin = add_spin(box, "Speed", 0, 400, 50)
	_size_spin = add_spin(box, "Size", 6, 64, 14)
	_boss_check = CheckBox.new()
	_boss_check.text = "Boss"
	box.add_child(_boss_check)


func _apply_extra_fields(entry: Dictionary) -> void:
	entry["behavior"] = option_value(_behavior_option)
	entry["hp"] = int(_hp_spin.value)
	entry["atk"] = int(_atk_spin.value)
	entry["spd"] = int(_spd_spin.value)
	entry["size"] = int(_size_spin.value)
	if _boss_check.button_pressed and not entry.has("attacks"):
		entry["attacks"] = ["slam"]
		entry["telegraph"] = 0.8


func _load_extra_fields(entry: Dictionary) -> void:
	select_option(_behavior_option, String(entry.get("behavior", "chaser")))
	_hp_spin.value = int(entry.get("hp", 10))
	_atk_spin.value = int(entry.get("atk", 1))
	_spd_spin.value = int(entry.get("spd", 50))
	_size_spin.value = int(entry.get("size", 14))
	_boss_check.button_pressed = scan.bosses.has(String(entry.get("id", "")))
