extends Node
## RelationshipManager: customer relationships, hero friendship levels and moods.

signal relationship_changed(customer_id: String, level: int)
signal relationship_points_changed(customer_id: String, points: int, delta: int)

var relationships: Dictionary = {}  # id -> points (customers & heroes share the scale)
var moods: Dictionary = {}          # id -> today's mood offset (-1.0 .. 1.0)
var rng := RandomNumberGenerator.new()


func reset() -> void:
	relationships.clear()
	moods.clear()
	rng.randomize()


func points(id: String) -> int:
	return int(relationships.get(id, 0))


func level(id: String) -> int:
	var fr: Dictionary = ContentDatabase.bal("friendship", {})
	var per := int(fr.get("points_per_level", 10))
	var mx := int(fr.get("max_level", 10))
	return clampi(points(id) / per, 0, mx)


func friendship_level(hero_id: String) -> int:
	return level(hero_id)


func can_equip_directly(hero_id: String) -> bool:
	var fr: Dictionary = ContentDatabase.bal("friendship", {})
	return level(hero_id) >= int(fr.get("equip_unlock_level", 3))


func change_relationship(id: String, delta: int) -> void:
	if id == "":
		return
	relationships[id] = points(id) + delta
	relationship_changed.emit(id, level(id))
	relationship_points_changed.emit(id, points(id), delta)


func progress_text(id: String) -> String:
	var fr: Dictionary = ContentDatabase.bal("friendship", {})
	var per := int(fr.get("points_per_level", 10))
	var current := points(id)
	var current_level := level(id)
	var max_level := int(fr.get("max_level", 10))
	if current_level >= max_level:
		return "Lv.%d MAX (%d pts)" % [current_level, current]
	return "Lv.%d · %d/%d to Lv.%d (%d total)" % [
		current_level, current - current_level * per, per,
		current_level + 1, current]


func mood(id: String) -> float:
	if not moods.has(id):
		moods[id] = rng.randf_range(-1.0, 1.0)
	return float(moods[id])


func new_day_moods() -> void:
	moods.clear()


func to_save() -> Dictionary:
	return {"relationships": relationships}


func from_save(d: Dictionary) -> void:
	relationships = d.get("relationships", {})
	moods.clear()
