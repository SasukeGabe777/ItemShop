extends Node
## Stage 2 of naruto_shot: root-parented so it survives the scene change into
## the Hidden Leaf dungeon. Screenshots the start room, a combat room, an
## attack and the boss room, and reports the live music track.


func _shot(f: String) -> void:
	get_viewport().get_texture().get_image().save_png("user://screenshots/" + f)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	# the first frames come back blank white; the warmup needs to be generous
	# now that the pool/texture set is large (AGENT_GUIDE §8)
	await get_tree().create_timer(3.5).timeout
	var dungeon: Node = get_tree().get_first_node_in_group("dungeon_runtime")
	if dungeon == null:
		print("NARUTO FAIL: no dungeon_runtime")
		get_tree().quit()
		return
	var hero: CombatHero = dungeon.get("hero")
	_shot("nrd_start.png")
	dungeon.call("_enter_room", 1)
	await get_tree().create_timer(1.0).timeout
	_shot("nrd_combat.png")
	hero.facing = Vector2(1, 0)
	hero._do_basic_attack()
	await get_tree().create_timer(0.12).timeout
	_shot("nrd_attack.png")
	await get_tree().create_timer(0.5).timeout
	var layout: Array = dungeon.get("layout")
	dungeon.call("_enter_room", layout.size() - 1)
	await get_tree().create_timer(0.4).timeout
	var boss: Node2D = get_tree().get_first_node_in_group("boss")
	if boss != null:
		hero.global_position = boss.global_position + Vector2(-10, 70)
		print("NARUTO boss in room: ", boss.get("enemy_id"))
	await get_tree().create_timer(0.8).timeout
	_shot("nrd_boss.png")
	print("NARUTO music track playing: ", AudioManager.current_track)
	print("NARUTO_SHOT_DONE")
	get_tree().quit()
