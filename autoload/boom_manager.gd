extends Node
## BoomManager: short, announced shop events that reshape one or more selling
## sessions without replacing normal market prices, budgets, or negotiation.

signal boom_changed()

var active_boom_id := ""
var active_world_id := ""
var sessions_left := 0
var announcement_pending := false
var eligible_after_day: Dictionary = {}  # boom id -> first day it may roll again
var queued_world_celebrations: Array[String] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	TimeManager.day_started.connect(_on_day_started)
	BridgeManager.gate_repaired.connect(_on_gate_repaired)


func reset() -> void:
	active_boom_id = ""
	active_world_id = ""
	sessions_left = 0
	announcement_pending = false
	eligible_after_day.clear()
	queued_world_celebrations.clear()
	rng.randomize()
	boom_changed.emit()


func is_active() -> bool:
	return active_boom_id != "" and sessions_left > 0 and not current_definition().is_empty()


func current_definition() -> Dictionary:
	return ContentDatabase.booms.get(active_boom_id, {})


func display_name() -> String:
	var d := current_definition()
	return String(d.get("name", active_boom_id)) if not d.is_empty() else ""


func announcement() -> String:
	var text := String(current_definition().get("announcement", ""))
	return text.replace("{world_name}", context_world_name())


func context_world_name() -> String:
	if active_world_id == "":
		return "the connected worlds"
	return String(ContentDatabase.get_world(active_world_id).get("name", active_world_id.capitalize()))


func mark_announced() -> void:
	if announcement_pending:
		announcement_pending = false
		boom_changed.emit()


func force_boom(boom_id: String, world_id: String = "") -> bool:
	var definition: Dictionary = ContentDatabase.booms.get(boom_id, {})
	if definition.is_empty():
		return false
	if world_id != "" and not ContentDatabase.worlds.has(world_id):
		return false
	var resolved_world := world_id
	if resolved_world == "" and String(definition.get("dynamic_world", "")) == "latest_repaired":
		resolved_world = _latest_repaired_world()
		if resolved_world == "":
			return false
	_activate(boom_id, resolved_world)
	return true


func clear_active() -> void:
	active_boom_id = ""
	active_world_id = ""
	sessions_left = 0
	announcement_pending = false
	boom_changed.emit()


func complete_shop_session() -> void:
	if not is_active():
		return
	var finished_id := active_boom_id
	sessions_left -= 1
	if sessions_left <= 0:
		var cooldown := int(current_definition().get("cooldown_days", 0))
		eligible_after_day[finished_id] = TimeManager.day + cooldown + 1
		clear_active()
	else:
		boom_changed.emit()


func traffic_multiplier() -> float:
	if not is_active():
		return 1.0
	var d := current_definition()
	var mult := float(d.get("traffic_multiplier", 1.0))
	var per_point := float(d.get("attribute_traffic_per_point", 0.0))
	var cap := float(d.get("attribute_traffic_cap", 0.0))
	mult *= 1.0 + minf(cap, preferred_attribute_points() * per_point)
	return mult


func preferred_attribute_points() -> int:
	if not is_active():
		return 0
	var appeal := InventoryManager.shop_appeal()
	var total := 0
	for key in current_definition().get("preferred_shop_attributes", []):
		total += int(appeal.get(String(key), 0))
	return total


func negotiation_tolerance_bonus() -> float:
	if not is_active():
		return 0.0
	var d := current_definition()
	return minf(float(d.get("attribute_tolerance_cap", 0.0)),
		preferred_attribute_points() * float(d.get("attribute_tolerance_per_point", 0.0)))


func max_live_customers() -> int:
	return int(current_definition().get("max_live_customers", 4)) if is_active() else 4


func next_spawn_delay() -> float:
	if not is_active():
		return rng.randf_range(1.2, 2.6)
	var span: Array = current_definition().get("spawn_interval", [0.5, 1.0])
	return rng.randf_range(float(span[0]), float(span[1]))


func named_chance() -> float:
	return float(current_definition().get("named_chance", 0.35)) if is_active() else 0.35


func customer_weight(archetype_id: String, customer_world: String = "") -> float:
	if not is_active():
		return 1.0
	var weights: Dictionary = current_definition().get("customer_weights", {})
	var weight := float(weights.get(archetype_id, 1.0))
	if customer_world != "" and customer_world in effective_preferred_worlds():
		weight *= 4.0
	return weight


func effective_preferred_worlds() -> Array[String]:
	var out: Array[String] = []
	if not is_active():
		return out
	for world in current_definition().get("preferred_worlds", []):
		var wid := String(world)
		if ContentDatabase.worlds.has(wid) and wid not in out:
			out.append(wid)
	if active_world_id != "" and active_world_id not in out:
		out.append(active_world_id)
	return out


func item_match_score(item_id: String) -> float:
	if not is_active():
		return 0.0
	var item := ContentDatabase.get_item(item_id)
	if item.is_empty():
		return 0.0
	var d := current_definition()
	var score := 0.0
	if String(item.get("category", "")) in d.get("preferred_categories", []):
		score += 1.0
	for tag in d.get("preferred_tags", []):
		if String(tag) in item.get("tags", []):
			score += 0.75
	if String(item.get("world", "")) in effective_preferred_worlds():
		score += 1.5
	return score


func apply_to_customer(customer: Dictionary) -> Dictionary:
	if not is_active():
		return customer
	var out := customer.duplicate(true)
	var d := current_definition()
	out["budget"] = maxi(1, int(round(int(out.get("budget", 0)) * float(d.get("budget_multiplier", 1.0)))))
	out["boom_id"] = active_boom_id
	var qty: Array = d.get("purchase_quantity", [1, 1])
	out["purchase_qty"] = rng.randi_range(int(qty[0]), int(qty[1]))
	return out


func purchase_quantity(customer: Dictionary, item_id: String) -> int:
	if String(customer.get("boom_id", "")) == "" or not is_active():
		return 1
	var d := current_definition()
	if String(ContentDatabase.get_item(item_id).get("category", "")) not in d.get("bulk_categories", []):
		return 1
	var wanted := maxi(1, int(customer.get("purchase_qty", 1)))
	var available := 1 + InventoryManager.count(item_id)
	var unit_value := maxi(1, MarketManager.market_value(item_id))
	var affordable := maxi(1, int(customer.get("budget", unit_value)) / unit_value)
	return mini(wanted, mini(available, affordable))


func request_frequency() -> float:
	return float(current_definition().get("request_frequency", 0.0)) if is_active() else 0.0


func off_theme_purchase_chance() -> float:
	return float(current_definition().get("off_theme_purchase_chance", 0.2)) if is_active() else 1.0


func preferred_order_target() -> Dictionary:
	if not is_active():
		return {}
	var d := current_definition()
	var candidates: Array[Dictionary] = []
	for cat in d.get("preferred_categories", []):
		if _has_live_match("category", String(cat)):
			candidates.append({"kind": "category", "target": String(cat)})
	for tag in d.get("preferred_tags", []):
		if _has_live_match("tag", String(tag)):
			candidates.append({"kind": "tag", "target": String(tag)})
	for world in effective_preferred_worlds():
		if _has_live_match("world", world):
			candidates.append({"kind": "world", "target": world})
	if candidates.is_empty():
		return {}
	return candidates[rng.randi() % candidates.size()]


func order_label(kind: String, target: String) -> String:
	match kind:
		"category": return target.capitalize()
		"tag": return target.capitalize() + " goods"
		"world": return String(ContentDatabase.get_world(target).get("name", target.capitalize())) + " merchandise"
		"item": return ContentDatabase.item_name(target)
	return target


func summary_lines() -> Array[String]:
	var out: Array[String] = []
	if not is_active():
		return out
	var d := current_definition()
	out.append("Traffic: roughly x%.1f (%d sessions remaining)" % [traffic_multiplier(), sessions_left])
	var wants: Array[String] = []
	for cat in d.get("preferred_categories", []):
		wants.append(String(cat).capitalize())
	for tag in d.get("preferred_tags", []):
		wants.append(String(tag).capitalize())
	for world in effective_preferred_worlds():
		wants.append(String(ContentDatabase.get_world(world).get("name", world.capitalize())) + " goods")
	if not wants.is_empty():
		out.append("Strong demand: " + ", ".join(wants.slice(0, mini(8, wants.size()))))
	var attrs: Array = d.get("preferred_shop_attributes", [])
	if not attrs.is_empty():
		var labels: Array[String] = []
		for attr in attrs:
			labels.append(String(attr).capitalize())
		out.append("Shop boost: %s appeal (%d matching points now)" % [" / ".join(labels), preferred_attribute_points()])
	return out


func to_save() -> Dictionary:
	return {
		"active_boom_id": active_boom_id,
		"active_world_id": active_world_id,
		"sessions_left": sessions_left,
		"announcement_pending": announcement_pending,
		"eligible_after_day": eligible_after_day,
		"queued_world_celebrations": queued_world_celebrations,
	}


func from_save(data: Dictionary) -> void:
	active_boom_id = String(data.get("active_boom_id", ""))
	active_world_id = String(data.get("active_world_id", ""))
	sessions_left = int(data.get("sessions_left", 0))
	announcement_pending = bool(data.get("announcement_pending", false))
	eligible_after_day = data.get("eligible_after_day", {})
	queued_world_celebrations.clear()
	for world in data.get("queued_world_celebrations", []):
		queued_world_celebrations.append(String(world))
	if not ContentDatabase.booms.has(active_boom_id):
		active_boom_id = ""
		active_world_id = ""
		sessions_left = 0
		announcement_pending = false
	boom_changed.emit()


func _on_day_started(_day: int) -> void:
	if is_active():
		return
	if not queued_world_celebrations.is_empty():
		var world := String(queued_world_celebrations.pop_front())
		force_boom("new_world_celebration", world)
		return
	_roll_daily_boom()


func _on_gate_repaired(world_id: String) -> void:
	if is_active():
		if world_id not in queued_world_celebrations:
			queued_world_celebrations.append(world_id)
		boom_changed.emit()
		return
	force_boom("new_world_celebration", world_id)


func _roll_daily_boom(force: bool = false) -> void:
	if not force and rng.randf() > ContentDatabase.boom_daily_roll_chance:
		return
	var pool: Array[Dictionary] = []
	var total := 0
	for id: String in ContentDatabase.booms:
		var d: Dictionary = ContentDatabase.booms[id]
		if bool(d.get("trigger_only", false)) or int(d.get("min_chapter", 1)) > TimeManager.chapter:
			continue
		if TimeManager.day < int(eligible_after_day.get(id, 0)):
			continue
		if String(d.get("dynamic_world", "")) == "latest_repaired" and _latest_repaired_world() == "":
			continue
		var weight := int(d.get("weight", 0))
		if weight <= 0:
			continue
		total += weight
		pool.append(d)
	if pool.is_empty() or total <= 0:
		return
	var pick := rng.randi_range(1, total)
	for d in pool:
		pick -= int(d.get("weight", 0))
		if pick <= 0:
			force_boom(String(d["id"]))
			return


func _activate(boom_id: String, world_id: String) -> void:
	active_boom_id = boom_id
	active_world_id = world_id
	var duration: Variant = current_definition().get("duration_sessions", [1, 1])
	if duration is Array:
		sessions_left = rng.randi_range(int(duration[0]), int(duration[1]))
	else:
		sessions_left = int(duration)
	sessions_left = maxi(1, sessions_left)
	announcement_pending = true
	boom_changed.emit()


func _latest_repaired_world() -> String:
	var best := ""
	var best_chapter := -1
	for id: String in ContentDatabase.worlds:
		if not BridgeManager.is_repaired(id):
			continue
		var chapter := int(ContentDatabase.get_world(id).get("chapter", 0))
		if chapter > best_chapter:
			best_chapter = chapter
			best = id
	return best


func _has_live_match(kind: String, target: String) -> bool:
	for id in ContentDatabase.live_items:
		var item := ContentDatabase.get_item(id)
		match kind:
			"category":
				if String(item.get("category", "")) == target: return true
			"tag":
				if target in item.get("tags", []): return true
			"world":
				if String(item.get("world", "")) == target: return true
	return false
