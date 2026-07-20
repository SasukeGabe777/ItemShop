extends Node2D
## Windowed visual probe for the Zelda fix pass: real Boss nodes for the three
## run bosses, Link attack animations captured mid-swing in every direction,
## and a placed bomb. Laid out inside the 640x360 logical viewport.
## Saves three screenshots and quits.


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var bg := ColorRect.new()
	bg.color = Color("#2f5d33")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)
	var target := Node2D.new()
	target.position = Vector2(320, 355)
	add_child(target)
	# --- the three bosses as real Boss nodes (matches the dungeon path) ------
	var boss_ids := ["big_green_chuchu", "big_blue_chuchu", "vaati"]
	for i in range(boss_ids.size()):
		var b := Boss.new()
		add_child(b)
		b.setup(boss_ids[i], target)
		b.position = Vector2(80 + i * 160, 120)
		b.set_physics_process(false)
		var tag := UIKit.label(boss_ids[i], 5, UIKit.COL_ACCENT)
		tag.position = b.position + Vector2(-30, 6)
		add_child(tag)
	# a few regular enemies for sanity
	var reg_ids := ["keese", "octorok", "darknut"]
	for i in range(reg_ids.size()):
		var e := Enemy.new()
		add_child(e)
		e.setup(reg_ids[i], target)
		e.position = Vector2(490 + i * 50, 110)
		e.set_physics_process(false)
	# --- armed bomb (sprite check) -------------------------------------------
	var bomb := Bomb.new()
	bomb.setup({"damage": 1, "knockback": 0.0, "source": self}, 60.0, 30.0, 8)
	bomb.position = Vector2(610, 170)
	add_child(bomb)
	var btag := UIKit.label("bomb", 5, UIKit.COL_GOOD)
	btag.position = bomb.position + Vector2(-10, 8)
	add_child(btag)
	# --- Link attacks: six visuals each playing a different swing ------------
	var setups := [
		["attack_1", Vector2(0, 1), "atk1 dn"],
		["attack_1", Vector2(1, 0), "atk1 side"],
		["attack_1", Vector2(0, -1), "atk1 up"],
		["attack_2", Vector2(0, 1), "atk2 dn"],
		["attack_2", Vector2(1, 0), "atk2 side"],
		["attack_2", Vector2(0, -1), "atk2 up"],
	]
	var visuals: Array = []
	for i in range(setups.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest("res://assets/franchises/zelda/manifests/link.json")
		cv.position = Vector2(60 + i * 95, 280)
		visuals.append(cv)
		var tag2 := UIKit.label(String(setups[i][2]), 5, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-18, 8)
		add_child(tag2)
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/zv_idle.png")
	# fire all attacks, screenshot early (windup) and mid-swing (blade out)
	for i in range(setups.size()):
		(visuals[i] as CharacterVisual).play_action(String(setups[i][0]), setups[i][1] as Vector2)
	await get_tree().create_timer(0.10).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/zv_swing_a.png")
	for i in range(setups.size()):
		(visuals[i] as CharacterVisual).play_action(String(setups[i][0]), setups[i][1] as Vector2)
	await get_tree().create_timer(0.19).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/zv_swing_b.png")
	print("ZELDA_VISUAL_DONE")
	get_tree().quit()
