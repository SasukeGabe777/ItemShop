extends Node
## MarketManager: rolling market events that multiply prices by item tag or
## category, plus wholesale stock offered by connected worlds.

signal events_changed()

var active_events: Array[Dictionary] = []  # {id, days_left}
var rng := RandomNumberGenerator.new()


func reset() -> void:
	active_events.clear()
	rng.randomize()
	on_new_day()


func on_new_day() -> void:
	var changed := false
	for ev in active_events:
		ev["days_left"] = int(ev["days_left"]) - 1
	var before := active_events.size()
	active_events = active_events.filter(func(e: Dictionary) -> bool: return int(e["days_left"]) > 0)
	changed = before != active_events.size()
	while active_events.size() < 2:
		var ev := _roll_event()
		if ev.is_empty():
			break
		active_events.append(ev)
		changed = true
	if changed:
		events_changed.emit()


func force_event(event_id: String, days: int = 2) -> bool:
	if not ContentDatabase.market_events.has(event_id):
		return false
	active_events = active_events.filter(func(entry: Dictionary) -> bool:
		return String(entry.get("id", "")) != event_id)
	active_events.append({"id": event_id, "days_left": maxi(1, days)})
	events_changed.emit()
	return true


func _roll_event() -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0
	var event_ids: Array[String] = []
	event_ids.assign(ContentDatabase.market_events.keys())
	event_ids.sort()
	for id: String in event_ids:
		if active_events.any(func(a: Dictionary) -> bool: return String(a["id"]) == id):
			continue
		var ev: Dictionary = ContentDatabase.market_events[id]
		if int(ev.get("min_chapter", 1)) > TimeManager.chapter:
			continue
		total += int(ev.get("weight", 5))
		pool.append(ev)
	if pool.is_empty():
		return {}
	var pick := rng.randi_range(1, total)
	for ev in pool:
		pick -= int(ev.get("weight", 5))
		if pick <= 0:
			var dur: Array = ev.get("duration", [1, 2])
			return {"id": ev["id"], "days_left": rng.randi_range(int(dur[0]), int(dur[1]))}
	return {}


## Combined multiplier for an item from all active events.
func price_multiplier(item_id: String) -> float:
	var it := ContentDatabase.get_item(item_id)
	if it.is_empty():
		return 1.0
	var mult := 1.0
	var tags: Array = it.get("tags", [])
	var cat := String(it.get("category", ""))
	for ev_ref in active_events:
		var ev: Dictionary = ContentDatabase.market_events.get(String(ev_ref["id"]), {})
		var mults: Dictionary = ev.get("mults", {})
		for key: String in mults:
			if key.begins_with("tag:") and key.trim_prefix("tag:") in tags:
				mult *= float(mults[key])
			elif key.begins_with("cat:") and key.trim_prefix("cat:") == cat:
				mult *= float(mults[key])
	return mult


## Crossroads prosperity: every repaired gate brings more worlds into the
## market and lifts all prices; merchant fame adds a little on top. This is the
## main late-game economic growth curve (repairs get costlier, so does trade).
func prosperity() -> float:
	var per_gate := float(ContentDatabase.bal("prosperity_gate_growth", 1.4))
	var per_level := float(ContentDatabase.bal("prosperity_per_merchant_level", 0.02))
	return pow(per_gate, BridgeManager.repaired_count()) * (1.0 + per_level * (GameState.merchant_level - 1))


## Current fair market value a customer perceives.
func market_value(item_id: String) -> int:
	return maxi(1, int(round(ContentDatabase.item_price(item_id) * price_multiplier(item_id) * prosperity())))


## Price the shop pays when buying wholesale stock.
func wholesale_cost(item_id: String) -> int:
	var shop: Dictionary = ContentDatabase.bal("shop", {})
	var ratio := float(shop.get("wholesale_ratio", 0.55))
	return maxi(1, int(round(market_value(item_id) * ratio)))


## Wholesale goods: the full live catalog (every sellable item with real
## icon art), available from day 1 — no franchise/chapter boundary.
func wholesale_catalog() -> Array[String]:
	return ContentDatabase.live_items_for_source("market")


## Goods a player can actually buy in the current chapter. Customer orders
## draw only from this pool, so nobody requests future-world merchandise.
func accessible_wholesale_catalog() -> Array[String]:
	var out: Array[String] = []
	for id in wholesale_catalog():
		if is_item_accessible(id):
			out.append(id)
	return out


func is_item_accessible(item_id: String) -> bool:
	return item_locked_reason(item_id) == ""


func is_item_obtainable_now(item_id: String) -> bool:
	if not ContentDatabase.is_item_unlocked(item_id):
		return false
	var sources := ContentDatabase.item_sources(item_id)
	if sources.is_empty():
		return false
	if sources.size() == 1 and sources[0] == "market":
		return is_item_accessible(item_id)
	return true


func item_locked_reason(item_id: String) -> String:
	var item := ContentDatabase.get_item(item_id)
	if item.is_empty():
		return "unavailable"
	if not ContentDatabase.item_has_source(item_id, "market"):
		return "expedition or workshop exclusive"
	var world := ContentDatabase.get_world(String(item.get("world", "")))
	var world_chapter := int(world.get(
		"chapter", 99 if bool(world.get("final", false)) else 1))
	if world_chapter > TimeManager.chapter:
		return "world sealed until Ch.%d" % world_chapter
	var price := ContentDatabase.item_price(item_id)
	if float(price) > price_cap(TimeManager.chapter):
		return "customers can't afford this until Ch.%d" % chapter_for_price(price)
	return ""


## Customer budgets scale ~0.85x per chapter (see CustomerGen); the cap keeps
## market stock and order requests inside what those purses can actually pay.
func price_cap(chapter: int) -> float:
	var cfg: Dictionary = ContentDatabase.bal("market_unlock", {})
	return float(cfg.get("base_cap", 800.0)) * (
		1.0 + float(cfg.get("per_chapter_scale", 0.85)) * (chapter - 1))


func chapter_for_price(price: int) -> int:
	for chapter in range(1, 9):
		if float(price) <= price_cap(chapter):
			return chapter
	return 8


func sellback_value(item_id: String) -> int:
	var ratio := float(ContentDatabase.bal("shop", {}).get(
		"market_sellback_ratio", 0.35))
	return maxi(1, int(round(market_value(item_id) * ratio)))


func sell_back(item_id: String, qty: int = 1) -> bool:
	if qty <= 0 or not ContentDatabase.items.has(item_id):
		return false
	if not InventoryManager.remove_item(item_id, qty):
		return false
	EconomyManager.add_gold(sellback_value(item_id) * qty)
	return true


## Exact items affected by an event in the current chapter. Pricing, briefing,
## Hot sorting, and Admin audits all share this matcher.
func event_affected_items(event_id: String, accessible_only: bool = true) -> Array[String]:
	var event: Dictionary = ContentDatabase.market_events.get(event_id, {})
	var out: Array[String] = []
	var pool := ContentDatabase.unlocked_live_items() \
		if accessible_only else ContentDatabase.live_items
	for item_id: String in pool:
		if accessible_only and not is_item_obtainable_now(item_id):
			continue
		var item := ContentDatabase.get_item(item_id)
		var tags: Array = item.get("tags", [])
		var category := String(item.get("category", ""))
		for key: String in event.get("mults", {}):
			if key.begins_with("tag:") and key.trim_prefix("tag:") in tags:
				out.append(item_id)
				break
			if key.begins_with("cat:") and key.trim_prefix("cat:") == category:
				out.append(item_id)
				break
	out.sort_custom(func(a: String, b: String) -> bool:
		return ContentDatabase.item_name(a).nocasecmp_to(
			ContentDatabase.item_name(b)) < 0)
	return out


## Combined key -> multiplier map from all active events, e.g.
## {"tag:healing": 1.6, "cat:weapon": 1.5}. Drives the day briefing,
## market-row trend colors and walk-in customer bias.
func event_effects() -> Dictionary:
	var out: Dictionary = {}
	for ev_ref in active_events:
		var ev: Dictionary = ContentDatabase.market_events.get(String(ev_ref["id"]), {})
		var mults: Dictionary = ev.get("mults", {})
		for key: String in mults:
			out[key] = float(out.get(key, 1.0)) * float(mults[key])
	return out


## Full data for each active event: {id, name, desc, days_left, mults}.
func active_event_details() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev_ref in active_events:
		var ev: Dictionary = ContentDatabase.market_events.get(String(ev_ref["id"]), {})
		if ev.is_empty():
			continue
		out.append({
			"id": String(ev["id"]), "name": String(ev.get("name", ev["id"])),
			"desc": String(ev.get("desc", "")), "days_left": int(ev_ref["days_left"]),
			"mults": ev.get("mults", {}),
		})
	return out


func active_event_names() -> Array[String]:
	var out: Array[String] = []
	for ev_ref in active_events:
		var ev: Dictionary = ContentDatabase.market_events.get(String(ev_ref["id"]), {})
		out.append(String(ev.get("name", ev_ref["id"])))
	return out


func to_save() -> Dictionary:
	return {"active_events": active_events}


func from_save(d: Dictionary) -> void:
	active_events.clear()
	for ev in d.get("active_events", []):
		active_events.append(ev)
	events_changed.emit()
