extends Node
## ShopFurnitureManager: owns the shop's furniture layout — which display
## furniture pieces exist, where they sit, and how their display slots map to
## InventoryManager.display indices. The layout is persisted in the save file;
## displayed items stay in InventoryManager.display exactly as before, so old
## saves keep working (a missing layout section just regenerates the classic
## default arrangement).

signal layout_changed()

## Furniture instances in slot order:
## {uid: int, type: String (id in data/shop_furniture.json), pos: [x, y]}
var layout: Array = []
var _uid_seq: int = 0

## Starting shop: two window counters up front, two basic stands behind —
## 4 pieces against a level-1 cap of 5, so there's room to buy more.
const STARTING_LAYOUT := [
	["window_counter", 190.0, 170.0],
	["window_counter", 278.0, 170.0],
	["basic_item_stand", 190.0, 246.0],
	["basic_item_stand", 278.0, 246.0],
]

## Furniture types put away in storage during rearrange mode (type ids;
## duplicates allowed). They can be placed again from the catalog for free.
var stored: Array = []


func reset() -> void:
	layout.clear()
	stored.clear()
	_uid_seq = 0
	ensure_layout()


func window_slots() -> Array[int]:
	var out: Array[int] = []
	for v in ContentDatabase.bal("shop", {}).get("window_slots", [0, 1, 2, 3]):
		out.append(int(v))
	return out


## Builds the starting arrangement for an empty layout (new campaigns and old
## saves without a layout section) and keeps the display array sized to what
## the furniture actually offers. Display slots come FROM furniture now —
## buying, storing, or selling pieces changes the slot count.
func ensure_layout() -> void:
	if layout.is_empty():
		for entry: Array in STARTING_LAYOUT:
			_uid_seq += 1
			layout.append({"uid": _uid_seq, "type": String(entry[0]), "pos": [float(entry[1]), float(entry[2])]})
		layout_changed.emit()
	InventoryManager.resize_display_slots(total_slot_count())


func type_def(instance: Dictionary) -> Dictionary:
	return ContentDatabase.get_furniture(String(instance.get("type", "")))


func slots_per_instance(instance: Dictionary) -> int:
	var def := type_def(instance)
	if bool(def.get("decor", false)):
		return 0
	return maxi(1, (def.get("display_slots", [[0, -12]]) as Array).size())


## Pieces that count against the shop-level furniture cap (decor doesn't).
func stand_count() -> int:
	var n := 0
	for inst: Dictionary in layout:
		if not bool(type_def(inst).get("decor", false)):
			n += 1
	return n


func total_slot_count() -> int:
	var n := 0
	for inst: Dictionary in layout:
		n += slots_per_instance(inst)
	return n


## Every display slot the furniture offers, in InventoryManager.display index
## order: {index, position: Vector2, furniture_uid, type, allowed_categories}.
func get_all_available_display_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var idx := 0
	for inst: Dictionary in layout:
		var def := type_def(inst)
		var pos_arr: Array = inst.get("pos", [0, 0])
		var base := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		for offset in def.get("display_slots", [[0, -12]]):
			out.append({
				"index": idx,
				"position": base + Vector2(float(offset[0]), float(offset[1])),
				"furniture_uid": int(inst.get("uid", 0)),
				"type": String(inst.get("type", "")),
				"allowed_categories": def.get("allowed_categories", []),
				"item_id": String(InventoryManager.display[idx]) if idx < InventoryManager.display.size() else "",
			})
			idx += 1
	return out


## Customers reach every slot today (no walls between them and stands); kept
## separate so pathing constraints can slot in later without touching callers.
func get_reachable_display_slots() -> Array[Dictionary]:
	return get_all_available_display_slots()


## Attention bonus a display index earns from placement: the classic window
## bonus for the front slots plus whatever the furniture piece itself adds.
func slot_attention_bonus(index: int) -> float:
	var bonus := 0.0
	if index in window_slots():
		bonus += float(ContentDatabase.bal("shop", {}).get("window_attention_bonus", 0.25))
	var seen := 0
	for inst: Dictionary in layout:
		var n := slots_per_instance(inst)
		if index < seen + n:
			bonus += float(type_def(inst).get("customer_attention_modifier", 0.0))
			break
		seen += n
	return bonus


## Convenience adapter for customer AI: returns {slot, item_id} for the item
## this customer would inspect, or {} when nothing on display interests them.
func choose_display_slot_for_customer(cust: Dictionary) -> Dictionary:
	var item_id := CustomerGen.pick_interest(cust)
	if item_id == "":
		return {}
	for slot: Dictionary in get_all_available_display_slots():
		if String(slot.get("item_id", "")) == item_id:
			return {"slot": int(slot["index"]), "item_id": item_id}
	return {"slot": -1, "item_id": item_id}


func instance_by_uid(uid: int) -> Dictionary:
	for inst: Dictionary in layout:
		if int(inst.get("uid", 0)) == uid:
			return inst
	return {}


func move_instance(uid: int, new_pos: Vector2) -> bool:
	var inst := instance_by_uid(uid)
	if inst.is_empty():
		return false
	inst["pos"] = [new_pos.x, new_pos.y]
	layout_changed.emit()
	return true


func add_instance(type_id: String, at: Vector2) -> Dictionary:
	if ContentDatabase.get_furniture(type_id).is_empty():
		return {}
	_uid_seq += 1
	var inst := {"uid": _uid_seq, "type": type_id, "pos": [at.x, at.y]}
	layout.append(inst)
	layout_changed.emit()
	return inst


func remove_instance(uid: int) -> bool:
	for i in layout.size():
		if int((layout[i] as Dictionary).get("uid", 0)) == uid:
			layout.remove_at(i)
			layout_changed.emit()
			return true
	return false


func slot_range_for_uid(uid: int) -> Vector2i:
	var start := 0
	for inst: Dictionary in layout:
		var count := slots_per_instance(inst)
		if int(inst.get("uid", 0)) == uid:
			return Vector2i(start, count)
		start += count
	return Vector2i(-1, 0)


## Axis-aligned footprint of a furniture instance, for placement validation.
func instance_rect(instance: Dictionary, at: Vector2 = Vector2.INF) -> Rect2:
	var def := type_def(instance)
	var size_arr: Array = def.get("size", [40, 24])
	var size := Vector2(float(size_arr[0]), float(size_arr[1]))
	var pos := at
	if pos == Vector2.INF:
		var pos_arr: Array = instance.get("pos", [0, 0])
		pos = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	return Rect2(pos - size / 2.0, size)


## True when the instance could sit at `at` without leaving `room` or
## overlapping another furniture piece.
func placement_valid(uid: int, at: Vector2, room: Rect2) -> bool:
	var inst := instance_by_uid(uid)
	if inst.is_empty():
		return false
	# decorations (banners, plants, ...) hang anywhere — walls included — and
	# may overlap anything; only functional furniture competes for floor space
	if bool(type_def(inst).get("decor", false)):
		return true
	var r := instance_rect(inst, at)
	if not room.encloses(r.grow(2.0)):
		return false
	for other: Dictionary in layout:
		if int(other.get("uid", 0)) == uid:
			continue
		if bool(type_def(other).get("decor", false)):
			continue  # a banner behind a shelf is fine
		if r.grow(2.0).intersects(instance_rect(other)):
			return false
	return true


func to_save() -> Dictionary:
	return {"layout": layout.duplicate(true), "uid_seq": _uid_seq, "stored": stored.duplicate()}


func from_save(d: Dictionary) -> void:
	layout = d.get("layout", [])
	stored = d.get("stored", [])
	_uid_seq = int(d.get("uid_seq", 0))
	# drop instances whose furniture type no longer exists in the data files
	layout = layout.filter(func(inst: Dictionary) -> bool:
		return not ContentDatabase.get_furniture(String(inst.get("type", ""))).is_empty())
	for inst: Dictionary in layout:
		_uid_seq = maxi(_uid_seq, int(inst.get("uid", 0)))
	layout_changed.emit()
