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
var orders: Array = []                # accepted requests; customers return on return_day
var hero_equipment: Dictionary = {}   # hero_id -> {weapon, armor, accessory, charm}
var _order_seq: int = 0
var last_order_request_day: int = -1


func reset() -> void:
	storage.clear()
	collection.clear()
	orders.clear()
	hero_equipment.clear()
	_order_seq = 0
	last_order_request_day = -1
	var start: Dictionary = ContentDatabase.bal("starting_inventory", {})
	for id: String in start:
		var live_id := ContentDatabase.live_substitute(id)
		storage[live_id] = int(storage.get(live_id, 0)) + int(start[id])
	# slots follow the furniture layout; make sure a fresh state has the
	# starting arrangement even before the shop scene is ever opened
	ShopFurnitureManager.ensure_layout()
	for h: String in ContentDatabase.heroes:
		var defaults: Dictionary = ContentDatabase.heroes[h].get("default_equipment", {})
		hero_equipment[h] = {"weapon": String(defaults.get("weapon", "")), "armor": String(defaults.get("armor", "")), "accessory": String(defaults.get("accessory", "")), "charm": String(defaults.get("charm", ""))}
	inventory_changed.emit()
	display_changed.emit()


## Display slots come from the furniture on the floor — the shop level only
## caps how many pieces fit (see balance.json shop.furniture_caps).
func display_slot_count() -> int:
	return ShopFurnitureManager.total_slot_count()


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


## Development/runtime layout adapter. Normal shop progression still uses
## display_slot_count(); the Live Developer Hub may temporarily add or remove
## furniture and needs the backing array to match that layout.
func resize_display_slots(count: int) -> void:
	var target := maxi(0, count)
	while display.size() < target:
		display.append("")
	while display.size() > target:
		var id := String(display.pop_back())
		if id != "":
			add_item(id)
	display_changed.emit()


func remove_display_range(start: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		var idx := start + i
		if idx < 0 or idx >= display.size():
			continue
		var id := String(display[idx])
		display.remove_at(idx)
		if id != "":
			add_item(id)
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
	# placed furniture and decor contribute their appeal_modifiers
	for inst: Dictionary in ShopFurnitureManager.layout:
		var mods: Dictionary = ShopFurnitureManager.type_def(inst).get("appeal_modifiers", {})
		for k: String in mods:
			if k in appeal:
				appeal[k] = int(appeal[k]) + int(mods[k])
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

func order_capacity() -> int:
	var cfg: Dictionary = ContentDatabase.bal("orders", {})
	var capacities: Array = cfg.get("capacity_by_shop_level", [4, 6, 8, 10, 12])
	if capacities.is_empty():
		return int(cfg.get("max_active", 12))
	var index := clampi(GameState.shop_level - 1, 0, capacities.size() - 1)
	return mini(int(capacities[index]), int(cfg.get("max_active", 12)))


func can_request_order() -> bool:
	return orders.size() < order_capacity() and last_order_request_day != TimeManager.day


func mark_order_requested() -> void:
	last_order_request_day = TimeManager.day

func add_order(customer_id: String, kind: String, target: String, qty: int, reward_each: int,
		return_in_days: int = -1, customer: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = ContentDatabase.bal("orders", {})
	if orders.size() >= order_capacity():
		return {}
	var dl: Array = cfg.get("return_days", cfg.get("deadline_days", [1, 3]))
	var days := return_in_days
	if days < 1:
		days = randi_range(int(dl[0]), int(dl[1]))
	_order_seq += 1
	var order := {
		"id": _order_seq, "customer_id": customer_id, "kind": kind, "target": target,
		"qty": qty, "return_day": TimeManager.day + days,
		# Retain the old key so existing saves and any older UI remain readable.
		"deadline_day": TimeManager.day + days, "reward_each": reward_each,
		"order_type": "special" if qty <= 1 else "bulk",
		"customer": customer.duplicate(true),
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
		var cfg: Dictionary = ContentDatabase.bal("orders", {})
		RelationshipManager.change_relationship(String(o["customer_id"]), int(cfg.get("bond_gain_complete", 8)))
		orders.remove_at(i)
		orders_changed.emit()
		return true
	return false


func fail_order(order_id: int) -> bool:
	for i in range(orders.size()):
		var o: Dictionary = orders[i]
		if int(o.get("id", -1)) != order_id:
			continue
		var cfg: Dictionary = ContentDatabase.bal("orders", {})
		RelationshipManager.change_relationship(String(o.get("customer_id", "")),
			int(cfg.get("bond_loss_failed", -6)))
		GameState.add_stat("orders_failed")
		orders.remove_at(i)
		orders_changed.emit()
		return true
	return false


func due_orders(day: int = TimeManager.day) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for o: Dictionary in orders:
		var return_day := int(o.get("return_day", o.get("deadline_day", day)))
		if day >= return_day:
			due.append(o)
	return due


func order_by_id(order_id: int) -> Dictionary:
	for o: Dictionary in orders:
		if int(o.get("id", -1)) == order_id:
			return o
	return {}


func matching_stock(order: Dictionary) -> int:
	var total := 0
	for item_id: String in storage:
		if order_matches(order, item_id):
			total += count(item_id)
	return total


func order_target_label(order: Dictionary) -> String:
	match String(order.get("kind", "item")):
		"item": return ContentDatabase.item_name(String(order.get("target", "")))
		"category": return "any %s" % String(order.get("target", "item")).capitalize()
		"tag": return "anything tagged %s" % String(order.get("target", ""))
		"world":
			var world := ContentDatabase.get_world(String(order.get("target", "")))
			return "goods from %s" % String(world.get("name", order.get("target", "")))
	return String(order.get("target", "Unknown item"))


func expire_orders() -> Array:
	# Orders no longer disappear silently at dawn. Once their return day is
	# reached, that customer visits the next shop session and asks in person.
	return []


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
	return {"storage": storage, "display": display, "collection": collection,
		"orders": orders, "hero_equipment": hero_equipment, "order_seq": _order_seq,
		"last_order_request_day": last_order_request_day}


func from_save(d: Dictionary) -> void:
	storage = d.get("storage", {})
	display = d.get("display", [])
	collection = d.get("collection", [])
	orders = d.get("orders", [])
	for o: Dictionary in orders:
		if not o.has("return_day"):
			o["return_day"] = int(o.get("deadline_day", TimeManager.day))
		if not o.has("deadline_day"):
			o["deadline_day"] = int(o["return_day"])
		if not o.has("customer"):
			o["customer"] = {}
	hero_equipment = d.get("hero_equipment", {})
	_order_seq = int(d.get("order_seq", 0))
	last_order_request_day = int(d.get("last_order_request_day", -1))
	_resize_display()
	inventory_changed.emit()
	display_changed.emit()
	orders_changed.emit()
