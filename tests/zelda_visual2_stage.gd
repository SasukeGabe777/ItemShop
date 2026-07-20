extends Node
## Stage 2 of zelda_visual2: lives on the root, drives Link inside the real
## Hyrule dungeon and screenshots swings, the placed bomb, and the boss room.


func _shot(fname: String) -> void:
	get_viewport().get_texture().get_image().save_png("user://screenshots/" + fname)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(1.6).timeout
	var dungeon: Node = get_tree().get_first_node_in_group("dungeon_runtime")
	if dungeon == null:
		print("ZV2 FAIL: no dungeon_runtime")
		get_tree().quit()
		return
	var hero: CombatHero = dungeon.get("hero")
	_shot("zvd_start.png")
	# --- basic swing facing down --------------------------------------------
	hero.facing = Vector2(0, 1)
	hero._do_basic_attack()
	await get_tree().create_timer(0.1).timeout
	_shot("zvd_atk_down.png")
	await get_tree().create_timer(0.5).timeout
	# --- swing facing right ---------------------------------------------------
	hero.facing = Vector2(1, 0)
	hero._do_basic_attack()
	await get_tree().create_timer(0.1).timeout
	_shot("zvd_atk_side.png")
	await get_tree().create_timer(0.5).timeout
	# --- bomb special ----------------------------------------------------------
	hero.meter = 100.0
	hero._do_special()
	await get_tree().create_timer(0.25).timeout
	_shot("zvd_bomb.png")
	# --- jump to the boss room -------------------------------------------------
	var layout: Array = dungeon.get("layout")
	dungeon.call("_enter_room", layout.size() - 1)
	await get_tree().create_timer(0.3).timeout
	var boss: Node2D = get_tree().get_first_node_in_group("boss")
	if boss != null:
		hero.global_position = boss.global_position + Vector2(-10, 70)
	await get_tree().create_timer(0.6).timeout
	_shot("zvd_boss_a.png")
	await get_tree().create_timer(1.4).timeout
	_shot("zvd_boss_b.png")
	print("ZV2_DONE")
	get_tree().quit()
