extends Node
## Stage 2 of walls_shot: root-parented so it survives scene changes. Walks
## the four prop worlds, screenshotting start + combat rooms of each.

const RUNS := [
	["kingdom_hearts", "sora"],
	["mario", "mario"],
	["final_fantasy", "cloud"],
	["zelda", "link"],
]
var run_idx := -1


func next_world() -> void:
	run_idx += 1
	if run_idx >= RUNS.size():
		print("WALLS_SHOT_DONE")
		get_tree().quit()
		return
	DungeonManager.plan_expedition(String(RUNS[run_idx][0]), String(RUNS[run_idx][1]), [], false)
	SceneRouter.go("dungeon")
	_probe_world.call_deferred()


func _probe_world() -> void:
	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	var wid := String(RUNS[run_idx][0])
	var dungeon: Node = get_tree().get_first_node_in_group("dungeon_runtime")
	if dungeon == null:
		print("WALLS FAIL: no dungeon for ", wid)
		next_world()
		return
	get_viewport().get_texture().get_image().save_png("user://screenshots/walls_%s_start.png" % wid)
	dungeon.call("_enter_room", 1)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/walls_%s_room1.png" % wid)
	print("WALLS OK: ", wid)
	next_world()
