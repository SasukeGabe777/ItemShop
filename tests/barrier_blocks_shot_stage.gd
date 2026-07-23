extends Node
## Root-parented stage survives dungeon scene changes and captures a real
## combat room for every supplied world-specific barrier block.

const SHOT_DIR := "user://screenshots/barrier_blocks/"
const RUNS := [
	["mario", "mario"],
	["final_fantasy", "cloud"],
	["zelda", "link"],
	["naruto", "naruto"],
	["dragon_ball", "goku"],
]

var run_idx := -1


func next_world() -> void:
	run_idx += 1
	if run_idx >= RUNS.size():
		print("BARRIER_BLOCKS_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
		get_tree().quit()
		return
	DungeonManager.plan_expedition(String(RUNS[run_idx][0]), String(RUNS[run_idx][1]), [], false)
	SceneRouter.go("dungeon")
	_probe_world.call_deferred()


func _probe_world() -> void:
	await get_tree().create_timer(2.0).timeout
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var world_id := String(RUNS[run_idx][0])
	var dungeon: Node = get_tree().get_first_node_in_group("dungeon_runtime")
	if dungeon == null:
		printerr("BARRIER_BLOCKS_SHOT_FAIL no dungeon for ", world_id)
		next_world()
		return
	dungeon.call("_enter_room", 1)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + world_id + ".png")
	print("BARRIER_BLOCKS_SHOT_OK ", world_id)
	next_world()
