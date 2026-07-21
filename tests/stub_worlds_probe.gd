extends Node
## Headless probe: what actually happens if a player reaches the data-only
## stub worlds (dragon_ball, pokemon)? Checks everything a dungeon run needs
## and prints a factual readiness report (NEXT_TASKS P3).


func _ready() -> void:
	await get_tree().process_frame
	for wid in ["dragon_ball", "pokemon"]:
		var w := ContentDatabase.get_world(wid)
		print("=== ", wid, " ===")
		if w.is_empty():
			print("  world def MISSING")
			continue
		var hero_id := String(w.get("hero", ""))
		var hero_def := ContentDatabase.get_hero(hero_id)
		var manifest := "res://assets/franchises/%s/manifests/%s.json" % [wid, hero_id]
		print("  hero: ", hero_id, " def=", not hero_def.is_empty(),
			" manifest=", ResourceLoader.exists(manifest))
		print("  enemies in pool: ", (w.get("enemies", []) as Array).size())
		var missing_defs := 0
		var missing_manifests := 0
		for eid in w.get("enemies", []):
			if ContentDatabase.get_enemy(String(eid)).is_empty():
				missing_defs += 1
			if not ResourceLoader.exists("res://assets/franchises/%s/manifests/%s.json" % [wid, eid]):
				missing_manifests += 1
		print("  enemy defs missing: ", missing_defs, " | enemy manifests missing: ", missing_manifests)
		print("  boss_rotation: ", w.get("boss_rotation", []))
		for bid in w.get("boss_rotation", []):
			print("    boss ", bid, " filed=", ContentDatabase.bosses.has(String(bid)))
		print("  room_backgrounds: ", not (w.get("room_backgrounds", {}) as Dictionary).is_empty(),
			" | obstacle_props: ", (w.get("obstacle_props", []) as Array).size(),
			" | barriers: ", not (w.get("barriers", {}) as Dictionary).is_empty())
		var layout := DungeonManager.generate_layout(wid, 42, false)
		print("  generate_layout: ", layout.size(), " rooms, boss room enemies: ",
			layout[layout.size() - 1].get("enemies") if not layout.is_empty() else "n/a")
	print("STUB_WORLDS_PROBE_DONE")
	get_tree().quit()
