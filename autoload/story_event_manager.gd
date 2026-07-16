extends Node
## StoryEventManager: matches gameplay triggers to data-driven dialogue scenes
## and queues them for the scene player.

signal scene_queued(scene_id: String)

var seen: Array = []
var queue: Array = []
var repeatable_types: Array = ["chapter_failed"]


func _ready() -> void:
	TimeManager.day_started.connect(func(day: int) -> void: fire("day_start", {"day": day}))
	TimeManager.chapter_started.connect(func(chapter: int) -> void: fire("chapter_start", {"chapter": chapter}))
	TimeManager.chapter_deadline_failed.connect(func(_chapter: int) -> void: fire("chapter_failed", {}))
	BridgeManager.gate_repaired.connect(func(world_id: String) -> void:
		fire("repair_done", {"chapter": int(ContentDatabase.get_world(world_id).get("chapter", 0))}))


func reset() -> void:
	seen.clear()
	queue.clear()


## Fire a trigger; returns queued scene ids.
func fire(trigger_type: String, params: Dictionary = {}) -> Array[String]:
	var queued: Array[String] = []
	for id: String in ContentDatabase.story_scenes:
		var sc: Dictionary = ContentDatabase.story_scenes[id]
		var trig: Dictionary = sc.get("trigger", {})
		if String(trig.get("type", "")) != trigger_type:
			continue
		var match_ok := true
		for key: String in trig:
			if key == "type":
				continue
			if not params.has(key) or str(params[key]) != str(trig[key]):
				match_ok = false
				break
		if not match_ok:
			continue
		if id in seen and not (trigger_type in repeatable_types):
			continue
		seen.append(id)
		queue.append(id)
		queued.append(id)
		scene_queued.emit(id)
	return queued


func has_pending() -> bool:
	return not queue.is_empty()


func pop_next() -> Dictionary:
	if queue.is_empty():
		return {}
	var id := String(queue.pop_front())
	return ContentDatabase.get_scene_data(id)


func speaker_display_name(who: String) -> String:
	if ContentDatabase.heroes.has(who):
		return String(ContentDatabase.heroes[who].get("name", who))
	if ContentDatabase.npcs.has(who):
		return String(ContentDatabase.npcs[who].get("name", who))
	return who.capitalize()


func speaker_color(who: String) -> Color:
	var d: Dictionary = ContentDatabase.heroes.get(who, ContentDatabase.npcs.get(who, {}))
	return Color(String(d.get("color", "#c8c8d8")))


func to_save() -> Dictionary:
	return {"seen": seen, "queue": queue}


func from_save(d: Dictionary) -> void:
	seen = d.get("seen", [])
	queue = d.get("queue", [])
