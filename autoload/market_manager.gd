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


func _roll_event() -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0
	for id: String in ContentDatabase.market_events:
		if active_events.any(func(a: Dictionary) -> bool: return String(a["id"]) == id):
			continue
		var ev: Dictionary = ContentDatabase.market_events[id]
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
	var out: Array[String] = []
	out.append_array(ContentDatabase.live_items)
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
