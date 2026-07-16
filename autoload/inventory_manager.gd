extends Node
## InventoryManager: storage, shop display slots, customer orders, the personal
## collection and per-hero equipment loadouts.

signal inventory_changed()
signal display_changed()
signal orders_changed()
signal equipment_changed(hero_id: String)

var storage: Dictionary = {}          # item_id -> qty
var display: Array = []               # slot -> item_id or ""
var collection: Array = []            # item ids in Hero's personal collection
var orders: Array = []                # {id, customer_id, kind, target, qty, deadline_day, reward_each}
var hero_equipment: Dictionary = {}   # hero_id -> {weapon, armor, accessory, charm}
var _order_seq: int = 0


func reset() -> void:
	storage.clear()
	collection.clear()
	orders.clear()
	hero_equipment.clear()
	_order_seq = 0
	var start: Dictionary = ContentDatabase.bal("starting_inventory", {})
	for id: String in start:
		storage[id] = int(start[id])
	_resize_display()
	for h: String in ContentDatabase.heroes:
		var defaults: Dictionary = ContentDatabase.heroes[h].get("default_equipment", {})
		hero_equipment[h] = {"weapon": String(defaults.get("weapon", "")), "armor": String(defaults.get("armor", "")), "accessory": String(defaults.get("accessory", "")), "charm": String(defaults.get("charm", ""))}
	inventory_changed.emit()
	display_changed.emit()


func display_slot_count() -> int:
	var shop: Dictionary = ContentDatabase.bal("shop", {})
	var levels: Array = shop.get("display_slots_by_level", [8, 12, 16])
	return int(levels[clampi(GameState.shop_level - 1, 0, levels.size() - 1)])


func _resize_display() -> void:
	var n := display_slot_count()
	while display.size() < n:
		display.append("")
	while display.size() > n:
		var last := String(display.pop_back())
		if last != "":
			add_item(last)


func on_shop_expanded() -> void:
	_resize_display()
	display_changed.emit()


func count(item_id: String) -> int:
	return int(storage.get(item_id, 0))


func add_item(item_id: String, qty: int = 1) -> void:
	if item_id == "" or qty <= 0:
		return
	storage[item_id] = count(item_id) + qty
	GameState.learn_item(item_id)
	inventory_changed.emit()


func remove_item(item_id: String, qty: int = 1) -> bool:
	if count(item_id) < qty:
		return false
	storage[item_id] = count(item_id) - qty
	if storage[item_id] <= 0:
		storage.erase(item_id)
	inventory_changed.emit()
	return true


func total_items() -> int:
	var t := 0
	for id: String in storage:
		t += int(storage[id])
	return t


## Sorted item id list. mode: "name", "price", "category", "world".
func sorted_ids(mode: String = "name") -> Array[String]:
	var ids: Array[String] = []
	for id: String in storage:
		ids.append(id)
	match mode:
		"price":
			ids.sort_custom(func(a: String, b: String) -> bool: return ContentDatabase.item_price(a) > ContentDatabase.item_price(b))
		"category":
			ids.sort_custom(func(a: String, b: String) -> bool: return String(ContentDatabase.get_item(a).get("category", "")) < String(ContentDatabase.get_item(b).get("category", "")))
		"world":
			ids.sort_custom(func(a: String, b: String) -> bool: return String(ContentDatabase.get_item(a).get("world", "")) < String(ContentDatabase.get_item(b).get("world", "")))
		_:
			ids.sort_custom(func(a: String, b: String) -> bool: return ContentDatabase.item_name(a) < ContentDatabase.item_name(b))
	return ids


func place_display(slot: int, item_id: String) -> bool:
	if slot < 0 or slot >= display.size():
		return false
	if item_id != "" and not remove_item(item_id):
		return false
	var prev := String(display[slot])
	if prev != "":
		add_item(prev)
	display[slot] = item_id
	display_changed.emit()
	return true


func take_display(slot: int) -> void:
	place_display(slot, "")


func displayed_ids() -> Array[String]:
	var out: Array[String] = []
	for id in display:
		if String(id) != "":
			out.append(String(id))
	return out


func remove_from_display(item_id: String) -> bool:
	for i in range(display.size()):
		if String(display[i]) == item_id:
			display[i] = ""
			display_changed.emit()
			return true
	return false


## Shop appeal from displayed items and owned decorations.
func shop_appeal() -> Dictionary:
	var appeal := {"cozy": 0, "intense": 0, "retro": 0, "modern": 0}
	for id in displayed_ids():
		var a: Dictionary = ContentDatabase.get_item(id).get("appeal", {})
		for k: String in a:
			appeal[k] = int(appeal[k]) + int(a[k])
	for deco in GameState.decorations:
		appeal["cozy"] = int(appeal["cozy"]) + 1
	return appeal


func dominant_appeal() -> String:
	var appeal := shop_appeal()
	var best := "cozy"
	for k: String in appeal:
		if int(appeal[k]) > int(appeal[best]):
			best = k
	return best


# ---------------- Orders ----------------

func add_order(customer_id: String, kind: String, target: String, qty: int, reward_each: int) -> Dictionary:
	var cfg: Dictionary = ContentDatabase.bal("orders", {})
	if orders.size() >= int(cfg.get("max_active", 4)):
		return {}
	var dl: Array = cfg.get("deadline_days", [1, 3])
	_order_seq += 1
	var order := {
		"id": _order_seq, "customer_id": customer_id, "kind": kind, "target": target,
		"qty": qty, "deadline_day": TimeManager.day + randi_range(int(dl[0]), int(dl[1])),
		"reward_each": reward_each,
	}
	orders.append(order)
	orders_changed.emit()
	return order


func order_matches(order: Dictionary, item_id: String) -> bool:
	var it := ContentDatabase.get_item(item_id)
	match String(order["kind"]):
		"item":
			return item_id == String(order["target"])
		"category":
			return String(it.get("category", "")) == String(order["target"])
		"tag":
			return String(order["target"]) in it.get("tags", [])
		"world":
			return String(it.get("world", "")) == String(order["target"])
	return false


func try_fulfill_order(order_id: int) -> bool:
	for i in range(orders.size()):
		var o: Dictionary = orders[i]
		if int(o["id"]) != order_id:
			continue
		var matching: Array[String] = []
		for id: String in storage:
			if order_matches(o, id):
				for j in range(count(id)):
					matching.append(id)
		if matching.size() < int(o["qty"]):
			return false
		var total := 0
		for j in range(int(o["qty"])):
			remove_item(matching[j])
			total += int(o["reward_each"])
		EconomyManager.add_gold(total)
		GameState.add_stat("orders_done")
		var mx: Dictionary = ContentDatabase.bal("merchant_xp", {})
		GameState.add_merchant_xp(int(mx.get("per_order", 15)))
		RelationshipManager.change_relationship(String(o["customer_id"]), 2)
		orders.remove_at(i)
		orders_changed.emit()
		return true
	return false


func expire_orders() -> Array:
	var expired := orders.filter(func(o: Dictionary) -> bool: return TimeManager.day > int(o["deadline_day"]))
	if expired.size() > 0:
		orders = orders.filter(func(o: Dictionary) -> bool: return TimeManager.day <= int(o["deadline_day"]))
		for o: Dictionary in expired:
			RelationshipManager.change_relationship(String(o["customer_id"]), -1)
		orders_changed.emit()
	return expired


# ---------------- Collection & equipment ----------------

func add_to_collection(item_id: String) -> bool:
	if not remove_item(item_id):
		return false
	collection.append(item_id)
	return true


func equip(hero_id: String, slot: String, item_id: String) -> bool:
	if not hero_equipment.has(hero_id):
		return false
	if item_id != "":
		var it := ContentDatabase.get_item(item_id)
		var cat := String(it.get("category", ""))
		var islot := String(it.get("slot", ""))
		if slot == "weapon":
			if cat != "weapon":
				return false
			var hero := ContentDatabase.get_hero(hero_id)
			if String(it.get("weapon_type", "")) != String(hero.get("weapon_type", "")):
				return false
		elif islot != slot and not (slot in ["accessory", "charm"] and islot in ["accessory", "charm"] and cat == "accessory"):
			if not (slot == "armor" and cat == "armor"):
				return false
		if not remove_item(item_id):
			return false
	var prev := String(hero_equipment[hero_id].get(slot, ""))
	if prev != "":
		add_item(prev)
	hero_equipment[hero_id][slot] = item_id
	equipment_changed.emit(hero_id)
	return true


## Effective combat stats for a hero including equipment.
func hero_stats(hero_id: String) -> Dictionary:
	var hero := ContentDatabase.get_hero(hero_id)
	var base: Dictionary = hero.get("base_stats", {})
	var out := {
		"hp": int(base.get("hp", 100)), "atk": int(base.get("atk", 10)),
		"def": int(base.get("def", 5)), "spd": int(base.get("spd", 120)),
	}
	var eq: Dictionary = hero_equipment.get(hero_id, {})
	for slot: String in eq:
		var id := String(eq[slot])
		if id == "":
			continue
		var stats: Dictionary = ContentDatabase.get_item(id).get("stats", {})
		out["atk"] = int(out["atk"]) + int(stats.get("atk", 0))
		out["def"] = int(out["def"]) + int(stats.get("def", 0))
		out["spd"] = int(out["spd"]) + int(stats.get("spd", 0)) * 5
		out["hp"] = int(out["hp"]) + int(stats.get("hp", 0))
		var fx: Dictionary = ContentDatabase.get_item(id).get("effect", {})
		if fx.has("max_hp"):
			out["hp"] = int(out["hp"]) + int(fx["max_hp"])
	# friendship bonus: +2% atk per friendship level
	var lvl := RelationshipManager.friendship_level(hero_id)
	out["atk"] = int(round(out["atk"] * (1.0 + 0.02 * lvl)))
	return out


func to_save() -> Dictionary:
	return {"storage": storage, "display": display, "collection": collection, "orders": orders, "hero_equipment": hero_equipment, "order_seq": _order_seq}


func from_save(d: Dictionary) -> void:
	storage = d.get("storage", {})
	display = d.get("display", [])
	collection = d.get("collection", [])
	orders = d.get("orders", [])
	hero_equipment = d.get("hero_equipment", {})
	_order_seq = int(d.get("order_seq", 0))
	_resize_display()
	inventory_changed.emit()
	display_changed.emit()
	orders_changed.emit()
