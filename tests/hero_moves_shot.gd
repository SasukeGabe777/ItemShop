extends Node2D
## Windowed visual probe for the merged Sora + Mario move sets: real-game
## idles/walks/roll alongside the grafted attack rows. Two screenshots.

const HEROES := [
	["res://assets/franchises/kingdom_hearts/manifests/sora.json", 90],
	["res://assets/franchises/mario/manifests/mario.json", 250],
]


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var bg := ColorRect.new()
	bg.color = Color("#31435a")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)
	for h in HEROES:
		var manifest := String(h[0])
		var y := int(h[1])
		var poses := [
			[Vector2(0, 1), false, "idle dn"], [Vector2(0, -1), false, "idle up"],
			[Vector2(1, 0), true, "walk rt"], [Vector2(-1, 0), true, "walk lf"],
		]
		for i in range(poses.size()):
			var cv := CharacterVisual.new()
			add_child(cv)
			cv.setup_from_manifest(manifest)
			cv.position = Vector2(60 + i * 80, y)
			cv.face(poses[i][0] as Vector2, bool(poses[i][1]))
			var tag := UIKit.label(String(poses[i][2]), 5, UIKit.COL_GOOD)
			tag.position = cv.position + Vector2(-20, 6)
			add_child(tag)
		var actions := [
			["attack_1", Vector2(1, 0), "atk1"],
			["attack_2", Vector2(0, 1), "atk2 dn"],
			["attack_3", Vector2(1, 0), "atk3"],
			["roll", Vector2(1, 0), "roll"],
		]
		for i in range(actions.size()):
			var cv2 := CharacterVisual.new()
			add_child(cv2)
			cv2.setup_from_manifest(manifest)
			cv2.position = Vector2(400 + i * 70, y)
			cv2.set_meta("act", actions[i])
			var tag2 := UIKit.label(String(actions[i][2]), 5, UIKit.COL_ACCENT)
			tag2.position = cv2.position + Vector2(-16, 6)
			add_child(tag2)
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(0.4).timeout
	for cv3 in get_children():
		if cv3 is CharacterVisual and cv3.has_meta("act"):
			var a: Array = cv3.get_meta("act")
			(cv3 as CharacterVisual).play_action(String(a[0]), a[1] as Vector2)
	await get_tree().create_timer(0.1).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/hm_a.png")
	await get_tree().create_timer(0.15).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/hm_b.png")
	print("HERO_MOVES_DONE")
	get_tree().quit()
