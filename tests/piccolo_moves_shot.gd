extends Node2D
## Windowed visual probe for the OAM-captured Piccolo move set: idles (with
## blink), 4-facing walks, melee (incl. the recaptured up swing), the SBC
## special (charge shimmer -> firing thrust) with a live Beam, and the fly
## dodge flips. Saves screenshots, quits.


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var bg := ColorRect.new()
	bg.color = Color("#3b3355")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)

	var manifest := "res://assets/franchises/dragon_ball/manifests/piccolo.json"
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
		["attack_1", Vector2(0, 1), "atk1 dn"],
		["attack_1", Vector2(1, 0), "atk1 side"],
		["attack_1", Vector2(0, -1), "atk1 up"],
		["attack_2", Vector2(0, 1), "atk2 dn"],
		["special", Vector2(0, 1), "sbc dn"],
		["special", Vector2(1, 0), "sbc side"],
		["special", Vector2(0, -1), "sbc up"],
		["fly", Vector2(0, 1), "fly dn"],
		["fly", Vector2(1, 0), "fly side"],
		["fly", Vector2(-1, 0), "fly lf"],
	]
	var visuals: Array = []
	for i in range(setups.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(manifest)
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(50 + i * 60, 290)
		visuals.append(cv)
		var tag2 := UIKit.label(String(setups[i][2]), 5, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-24, 8)
		add_child(tag2)

	# live beam: real SBC textures growing to full range, aimed right
	var sp: Dictionary = {}
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	for h: Dictionary in (JSON.parse_string(f.get_as_text()) as Dictionary).get("heroes", []):
		if String(h.get("id", "")) == "piccolo":
			sp = h["combat"]["special"]
	var beam_label := UIKit.label("live beam ->", 5, UIKit.COL_GOOD)
	beam_label.position = Vector2(380, 350)
	add_child(beam_label)

	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(0.4).timeout
	for i in range(setups.size()):
		(visuals[i] as CharacterVisual).play_action(String(setups[i][0]), setups[i][1] as Vector2)
	var beam := Beam.new()
	beam.setup({"damage": 0, "knockback": 0.0, "source": null}, Vector2.RIGHT, sp, 0)
	beam.position = Vector2(430, 340)
	add_child(beam)
	await get_tree().create_timer(0.08).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/pm_a.png")
	await get_tree().create_timer(0.14).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/pm_b.png")
	# specials reach the firing thrust after the 0.4 s charge shimmer
	await get_tree().create_timer(0.33).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/pm_c.png")
	# idle blink: 2 s loop, blink pose in the last 200 ms
	await get_tree().create_timer(1.25).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/pm_blink_a.png")
	await get_tree().create_timer(0.12).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/pm_blink_b.png")
	print("PICCOLO_MOVES_DONE")
	get_tree().quit()
