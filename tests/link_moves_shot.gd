extends Node2D
## Windowed visual probe for the OAM-captured Link move set: idles (with the
## blink), full 10-frame walks in all facings, and both attacks per direction.
## Lays out inside the 640x360 logical viewport, saves four screenshots, quits.


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var bg := ColorRect.new()
	bg.color = Color("#2f5d33")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)

	var manifest := "res://assets/franchises/zelda/manifests/link.json"
	# --- idles + walks, all four facings (side-left must flip) ---------------
	var poses := [
		[Vector2(0, 1), false, "idle dn"], [Vector2(0, -1), false, "idle up"],
		[Vector2(1, 0), false, "idle rt"], [Vector2(-1, 0), false, "idle lf"],
		[Vector2(0, 1), true, "walk dn"], [Vector2(0, -1), true, "walk up"],
		[Vector2(1, 0), true, "walk rt"], [Vector2(-1, 0), true, "walk lf"],
	]
	for i in range(poses.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(manifest)
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(80 + (i % 4) * 150, 90 + (i / 4) * 110)
		cv.face(poses[i][0] as Vector2, bool(poses[i][1]))
		var tag := UIKit.label(String(poses[i][2]), 5, UIKit.COL_GOOD)
		tag.position = cv.position + Vector2(-20, 10)
		add_child(tag)
	# --- attacks, fired fresh before each capture ----------------------------
	var setups := [
		["attack_1", Vector2(0, 1), "atk1 dn"],
		["attack_1", Vector2(1, 0), "atk1 side"],
		["attack_1", Vector2(0, -1), "atk1 up"],
		["attack_2", Vector2(0, 1), "atk2 dn"],
		["attack_2", Vector2(1, 0), "atk2 side"],
		["roll", Vector2(1, 0), "roll side"],
	]
	var visuals: Array = []
	for i in range(setups.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(manifest)
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(70 + i * 100, 330)
		visuals.append(cv)
		var tag2 := UIKit.label(String(setups[i][2]), 5, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-22, 8)
		add_child(tag2)

	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(0.4).timeout
	for i in range(setups.size()):
		(visuals[i] as CharacterVisual).play_action(String(setups[i][0]), setups[i][1] as Vector2)
	await get_tree().create_timer(0.08).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/lm_a.png")
	await get_tree().create_timer(0.14).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/lm_b.png")
	# walks advance ~2 frames between shots; attacks land mid/late swing.
	# now wait for the idle blink: cycle is 2 s, blink in the last 200 ms.
	await get_tree().create_timer(1.35).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/lm_blink_a.png")
	await get_tree().create_timer(0.1).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/lm_blink_b.png")
	print("LINK_MOVES_DONE")
	get_tree().quit()
