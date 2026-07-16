extends Node
## BridgeManager: the seven World Bridge gates — shards, payments and repairs.

signal shard_recovered(world_id: String)
signal gate_repaired(world_id: String)
signal all_gates_repaired()

var gates: Dictionary = {}  # world_id -> {shard: bool, paid: bool, repaired: bool}
var fade_defeated: bool = false


func reset() -> void:
	gates.clear()
	fade_defeated = false
	for id: String in ContentDatabase.worlds:
		if not bool(ContentDatabase.worlds[id].get("final", false)):
			gates[id] = {"shard": false, "paid": false, "repaired": false}


func gate(world_id: String) -> Dictionary:
	return gates.get(world_id, {})


func has_shard(world_id: String) -> bool:
	return bool(gate(world_id).get("shard", false))


func is_repaired(world_id: String) -> bool:
	return bool(gate(world_id).get("repaired", false))


func repaired_count() -> int:
	var n := 0
	for id: String in gates:
		if is_repaired(id):
			n += 1
	return n


func repair_cost(world_id: String) -> int:
	return int(ContentDatabase.get_world(world_id).get("repair_cost", 0))


func collect_shard(world_id: String) -> void:
	if not gates.has(world_id) or has_shard(world_id):
		return
	gates[world_id]["shard"] = true
	var shard_item := String(ContentDatabase.get_world(world_id).get("world_shard", ""))
	if shard_item != "":
		InventoryManager.add_item(shard_item)
	GameState.add_stat("bosses_defeated")
	shard_recovered.emit(world_id)


## Pay for and complete a gate repair. Requires the shard and the gold.
func pay_repair(world_id: String) -> bool:
	if not gates.has(world_id) or is_repaired(world_id) or not has_shard(world_id):
		return false
	var cost := repair_cost(world_id)
	if not EconomyManager.spend_gold(cost):
		return false
	gates[world_id]["paid"] = true
	gates[world_id]["repaired"] = true
	gate_repaired.emit(world_id)
	# Advance to the next chapter when the current chapter's gate is repaired.
	var w := ContentDatabase.get_world(world_id)
	var chap := int(w.get("chapter", 0))
	if chap == TimeManager.chapter and TimeManager.chapter <= 7:
		TimeManager.begin_chapter(chap + 1)
	if repaired_count() >= 7:
		all_gates_repaired.emit()
	return true


func is_chapter_complete(chapter: int) -> bool:
	if chapter >= 8:
		return fade_defeated
	var w := ContentDatabase.world_for_chapter(chapter)
	if w.is_empty():
		return false
	return is_repaired(String(w["id"]))


## Worlds the player can currently travel to (repaired gates + current chapter's world).
func accessible_worlds() -> Array[String]:
	var out: Array[String] = []
	for id: String in ContentDatabase.world_order:
		var w: Dictionary = ContentDatabase.worlds[id]
		if bool(w.get("final", false)):
			if TimeManager.chapter >= 8:
				out.append(id)
			continue
		if is_repaired(id) or int(w.get("chapter", 99)) <= TimeManager.chapter:
			out.append(id)
	return out


func defeat_fade() -> void:
	fade_defeated = true


func to_save() -> Dictionary:
	return {"gates": gates, "fade_defeated": fade_defeated}


func from_save(d: Dictionary) -> void:
	gates = d.get("gates", {})
	fade_defeated = bool(d.get("fade_defeated", false))
