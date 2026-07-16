extends Node
## SaveManager: three manual slots, an autosave at the start of each day, and a
## chapter checkpoint used for failure restarts with retention rules.

signal saved(slot_name: String)
signal loaded(slot_name: String)

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	TimeManager.day_started.connect(_on_day_started)


func _on_day_started(_day: int) -> void:
	if GameState.campaign_active:
		autosave()
	RelationshipManager.new_day_moods()
	InventoryManager.expire_orders()


func _collect() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"title": GameState.game_title,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": GameState.to_save(),
		"time": TimeManager.to_save(),
		"economy": EconomyManager.to_save(),
		"market": MarketManager.to_save(),
		"inventory": InventoryManager.to_save(),
		"relationships": RelationshipManager.to_save(),
		"bridge": BridgeManager.to_save(),
		"story": StoryEventManager.to_save(),
	}


func _apply(d: Dictionary) -> void:
	GameState.from_save(d.get("game_state", {}))
	TimeManager.from_save(d.get("time", {}))
	EconomyManager.from_save(d.get("economy", {}))
	MarketManager.from_save(d.get("market", {}))
	InventoryManager.from_save(d.get("inventory", {}))
	RelationshipManager.from_save(d.get("relationships", {}))
	BridgeManager.from_save(d.get("bridge", {}))
	StoryEventManager.from_save(d.get("story", {}))


func _write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


func save_to_slot(slot: int) -> bool:
	var ok := _write(slot_path(slot), _collect())
	if ok:
		GameState.current_slot = slot
		saved.emit("slot_%d" % slot)
	return ok


func load_from_slot(slot: int) -> bool:
	var d := _read(slot_path(slot))
	if d.is_empty():
		return false
	_apply(d)
	GameState.current_slot = slot
	loaded.emit("slot_%d" % slot)
	return true


func slot_summary(slot: int) -> Dictionary:
	var d := _read(slot_path(slot))
	if d.is_empty():
		return {}
	var t: Dictionary = d.get("time", {})
	var e: Dictionary = d.get("economy", {})
	return {
		"day": int(t.get("day", 1)), "chapter": int(t.get("chapter", 1)),
		"gold": int(e.get("gold", 0)), "timestamp": String(d.get("timestamp", "")),
		"endless": bool(d.get("game_state", {}).get("endless_mode", false)),
	}


func autosave() -> void:
	_write(SAVE_DIR + "autosave.json", _collect())
	saved.emit("autosave")


func load_autosave() -> bool:
	var d := _read(SAVE_DIR + "autosave.json")
	if d.is_empty():
		return false
	_apply(d)
	loaded.emit("autosave")
	return true


## Snapshot taken at the start of every chapter, for deadline-failure restarts.
func checkpoint_chapter() -> void:
	_write(SAVE_DIR + "checkpoint.json", _collect())


## Restart the current chapter after a failure. Retains merchant progression,
## customer knowledge, encyclopedia, tutorials, decorations and up to N chosen
## inventory items (per data/balance.json chapter_failure rules).
func restart_chapter(kept_item_ids: Array = []) -> bool:
	var checkpoint := _read(SAVE_DIR + "checkpoint.json")
	if checkpoint.is_empty():
		return false
	var rules: Dictionary = ContentDatabase.bal("chapter_failure", {})
	var max_keep := int(rules.get("keep_inventory_items", 10))
	# capture retained state from the failed run
	var retained_gs := GameState.to_save()
	var retained_rel := RelationshipManager.to_save()
	var kept: Dictionary = {}
	var budget := max_keep
	for id in kept_item_ids:
		var sid := String(id)
		if budget <= 0:
			break
		var have := InventoryManager.count(sid)
		if have > 0:
			var take := mini(have, budget)
			kept[sid] = take
			budget -= take
	_apply(checkpoint)
	# retention: merchant levels, customer knowledge, encyclopedia, tutorials, decorations
	GameState.merchant_level = int(retained_gs.get("merchant_level", GameState.merchant_level))
	GameState.merchant_xp = int(retained_gs.get("merchant_xp", GameState.merchant_xp))
	GameState.encyclopedia = retained_gs.get("encyclopedia", GameState.encyclopedia)
	GameState.known_customers = retained_gs.get("known_customers", GameState.known_customers)
	GameState.tutorials_seen = retained_gs.get("tutorials_seen", GameState.tutorials_seen)
	GameState.decorations = retained_gs.get("decorations", GameState.decorations)
	RelationshipManager.from_save(retained_rel)
	for sid: String in kept:
		InventoryManager.add_item(sid, int(kept[sid]))
	autosave()
	return true


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))
