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

const DEFAULT_MIDDLE_TYPES := ["wooden_shelf", "round_pedestal", "display_case"]


func reset() -> void:
	layout.clear()
	_uid_seq = 0


func window_slots() -> Array[int]:
	var out: Array[int] = []
	for v in ContentDatabase.bal("shop", {}).get("window_slots", [0, 1, 2, 3]):
		out.append(int(v))
	return out


## The classic pre-furniture-system arrangement: one single-slot stand per
## display slot, laid out on the original 4-column grid, counters in front.
func default_instance_for_slot(slot: int) -> Dictionary:
	var col := slot % 4
	var row := slot / 4
	var type_id: String = "window_counter" if slot in window_slots() else DEFAULT_MIDDLE_TYPES[slot % DEFAULT_MIDDLE_TYPES.size()]
	_uid_seq += 1
	return {"uid": _uid_seq, "type": type_id, "pos": [190.0 + col * 88.0, 170.0 + row * 76.0]}


## Guarantees the layout offers at least InventoryManager.display_slot_count()
## slots, appending classic-position stands for any missing indices (covers
## new campaigns, old saves without a layout section, and shop expansions).
func ensure_layout() -> void:
	var needed := InventoryManager.display_slot_count()
	var have := total_slot_count()
	var changed := false
	while have < needed:
		# find the first display index the new stand will own
		layout.append(default_instance_for_slot(have))
		have = total_slot_count()
		changed = true
	if changed:
		layout_changed.emit()


func type_def(instance: Dictionary) -> Dictionary:
	return ContentDatabase.get_furniture(String(instance.get("type", "")))


func slots_per_instance(instance: Dictionary) -> int:
	return maxi(1, (type_def(instance).get("display_slots", [[0, -12]]) as Array).size())


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
	var r := instance_rect(inst, at)
	if not room.encloses(r.grow(2.0)):
		return false
	for other: Dictionary in layout:
		if int(other.get("uid", 0)) == uid:
			continue
		if r.grow(2.0).intersects(instance_rect(other)):
			return false
	return true


func to_save() -> Dictionary:
	return {"layout": layout.duplicate(true), "uid_seq": _uid_seq}


func from_save(d: Dictionary) -> void:
	layout = d.get("layout", [])
	_uid_seq = int(d.get("uid_seq", 0))
	# drop instances whose furniture type no longer exists in the data files
	layout = layout.filter(func(inst: Dictionary) -> bool:
		return not ContentDatabase.get_furniture(String(inst.get("type", ""))).is_empty())
	for inst: Dictionary in layout:
		_uid_seq = maxi(_uid_seq, int(inst.get("uid", 0)))
	layout_changed.emit()
