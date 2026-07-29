extends Node
## GameState: campaign-wide progress that isn't owned by a more specific system.
## Merchant level, flags, encyclopedia, met characters, unlocks, statistics.

signal merchant_level_up(new_level: int)
signal flag_set(flag: String)
signal admin_mode_changed(enabled: bool)
signal admin_review_flags_changed()
signal admin_item_flags_changed()

var campaign_active: bool = false
var endless_mode: bool = false
var current_slot: int = 0
var game_title: String = ""
var admin_mode: bool = false
var admin_review_flags: Dictionary = {}
var admin_item_flags: Dictionary = {}  # item id -> {issues: [], note: "", context: {}}

const ADMIN_ITEM_FLAGS_PATH := "user://exports/item_audit_draft.json"

var merchant_level: int = 1
var merchant_xp: int = 0
var shop_level: int = 1

var flags: Dictionary = {}            # generic story/tutorial flags
var met_heroes: Array = []            # hero ids greeted at least once
var encyclopedia: Array = []          # item ids ever handled
var known_customers: Array = []       # customer ids served at least once
var decorations: Array = []           # cosmetic decoration ids owned
var tutorials_seen: Array = []
var stats: Dictionary = {"sales": 0, "perfect_deals": 0, "orders_done": 0, "orders_failed": 0, "expeditions": 0, "bosses_defeated": 0, "days_played": 0}


func _ready() -> void:
	game_title = ProjectSettings.get_setting("application/config/name", "Crossroads")
	_load_admin_item_flags()
	set_process_input(true)


## Secret in-game review mode. Checking unicode catches Shift+2 as the actual
## @ character regardless of the physical number-row key involved.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.unicode == 64:
		if not admin_mode:
			DebugManager.enable_admin_mode()
		get_viewport().set_input_as_handled()


func set_admin_review_flag(category: String, entry_id: String, flagged: bool) -> void:
	var key := "%s:%s" % [category, entry_id]
	if flagged:
		admin_review_flags[key] = true
	else:
		admin_review_flags.erase(key)
	admin_review_flags_changed.emit()


func is_admin_review_flagged(category: String, entry_id: String) -> bool:
	return bool(admin_review_flags.get("%s:%s" % [category, entry_id], false))


func admin_review_flag_count() -> int:
	return admin_review_flags.size()


func set_admin_item_issue(item_id: String, issue: String, flagged: bool) -> void:
	if item_id == "" or issue == "":
		return
	var entry: Dictionary = admin_item_flags.get(item_id, {
		"issues": [], "note": "", "context": {}})
	var issues: Array = entry.get("issues", [])
	if flagged and issue not in issues:
		issues.append(issue)
	elif not flagged:
		issues.erase(issue)
	entry["issues"] = issues
	entry["context"] = _admin_item_context(item_id)
	if issues.is_empty() and String(entry.get("note", "")).strip_edges() == "":
		admin_item_flags.erase(item_id)
	else:
		admin_item_flags[item_id] = entry
	_save_admin_item_flags()
	admin_item_flags_changed.emit()


func set_admin_item_note(item_id: String, note: String) -> void:
	if item_id == "":
		return
	var entry: Dictionary = admin_item_flags.get(item_id, {
		"issues": [], "note": "", "context": {}})
	entry["note"] = note.strip_edges()
	entry["context"] = _admin_item_context(item_id)
	if (entry.get("issues", []) as Array).is_empty() \
			and String(entry["note"]) == "":
		admin_item_flags.erase(item_id)
	else:
		admin_item_flags[item_id] = entry
	_save_admin_item_flags()
	admin_item_flags_changed.emit()


func admin_item_flag(item_id: String) -> Dictionary:
	return (admin_item_flags.get(item_id, {}) as Dictionary).duplicate(true)


func is_admin_item_issue_flagged(item_id: String, issue: String) -> bool:
	return issue in (admin_item_flags.get(item_id, {}) as Dictionary).get(
		"issues", [])


func admin_item_flag_count() -> int:
	return admin_item_flags.size()


func clear_admin_item_flag(item_id: String) -> void:
	admin_item_flags.erase(item_id)
	_save_admin_item_flags()
	admin_item_flags_changed.emit()


func _admin_item_context(item_id: String) -> Dictionary:
	var item := ContentDatabase.get_item(item_id)
	return {
		"captured": Time.get_datetime_string_from_system(),
		"day": TimeManager.day,
		"chapter": TimeManager.chapter,
		"active_boom": BoomManager.active_boom_id,
		"boom_world": BoomManager.active_world_id,
		"market_events": MarketManager.active_event_names(),
		"accessible_worlds": BridgeManager.accessible_worlds(),
		"owned": InventoryManager.count(item_id),
		"market_locked_reason": MarketManager.item_locked_reason(item_id),
		"item_data": item.duplicate(true),
	}


func _save_admin_item_flags() -> void:
	var absolute_dir := ProjectSettings.globalize_path("user://exports")
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file := FileAccess.open(ADMIN_ITEM_FLAGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"schema": "crossroads.item_audit.v1",
			"flags": admin_item_flags,
		}, "\t"))


func _load_admin_item_flags() -> void:
	if not FileAccess.file_exists(ADMIN_ITEM_FLAGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(ADMIN_ITEM_FLAGS_PATH))
	if parsed is Dictionary:
		admin_item_flags = (parsed as Dictionary).get("flags", {})


func reset_campaign() -> void:
	campaign_active = true
	DayBriefing.reset()
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
	stats = {"sales": 0, "perfect_deals": 0, "orders_done": 0, "orders_failed": 0, "expeditions": 0, "bosses_defeated": 0, "days_played": 0}


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
