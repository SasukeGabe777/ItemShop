extends Node2D
## Windowed probe for the OAM-captured Goku move set: idles (with blink),
## 4-dir walks, kick (A-tap swoosh) and punch melee, the Kamehameha charge ->
## thrust in three facings, plus a live kame beam from the real parts.


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var bg := ColorRect.new()
	bg.color = Color("#5a4632")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)

	var manifest := "res://assets/franchises/dragon_ball/manifests/goku.json"
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
		cv.position = Vector2(70 + (i % 4) * 130, 80 + (i / 4) * 90)
		cv.face(poses[i][0] as Vector2, bool(poses[i][1]))
		var tag := UIKit.label(String(poses[i][2]), 5, UIKit.COL_GOOD)
		tag.position = cv.position + Vector2(-20, 10)
		add_child(tag)

	var setups := [
		["attack_1", Vector2(0, 1), "kick dn"],
		["attack_1", Vector2(1, 0), "kick rt"],
		["attack_1", Vector2(0, -1), "kick up"],
		["attack_2", Vector2(0, 1), "punch dn"],
		["attack_2", Vector2(1, 0), "punch rt"],
		["special", Vector2(0, 1), "kame dn"],
		["special", Vector2(1, 0), "kame rt"],
		["special", Vector2(0, -1), "kame up"],
	]
	var visuals: Array = []
	for i in range(setups.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(manifest)
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(55 + i * 72, 290)
		visuals.append(cv)
		var tag2 := UIKit.label(String(setups[i][2]), 5, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-24, 8)
		add_child(tag2)

	var sp: Dictionary = {}
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	for h: Dictionary in (JSON.parse_string(f.get_as_text()) as Dictionary).get("heroes", []):
		if String(h.get("id", "")) == "goku":
			sp = h["combat"]["special"]
	var beam_label := UIKit.label("live kame ->", 5, UIKit.COL_GOOD)
	beam_label.position = Vector2(360, 350)
	add_child(beam_label)

	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(0.4).timeout
	for i in range(setups.size()):
		(visuals[i] as CharacterVisual).play_action(String(setups[i][0]), setups[i][1] as Vector2)
	var beam := Beam.new()
	beam.setup({"damage": 0, "knockback": 0.0, "source": null}, Vector2.RIGHT, sp, 0)
	beam.position = Vector2(420, 345)
	add_child(beam)
	await get_tree().create_timer(0.1).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/gk_a.png")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/gk_b.png")
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/gk_c.png")
	print("GOKU_MOVES_DONE")
	get_tree().quit()
