extends Node2D
## Windowed probe for the pass-2 hero sheet fixes: Sora's rescaled attack
## combo + stance-shuffle special, Mario's cleaned walk cycles (no back-turned
## or celebration frames). Two timed screenshots catch different cycle frames.


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var bg := ColorRect.new()
	bg.color = Color("#2c3e50")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)

	var sora := "res://assets/franchises/kingdom_hearts/manifests/sora.json"
	var mario := "res://assets/franchises/mario/manifests/mario.json"
	var walkers := [
		[sora, Vector2(0, 1), "s walk dn"], [sora, Vector2(1, 0), "s walk rt"],
		[sora, Vector2(-1, 0), "s walk lf"], [sora, Vector2(0, -1), "s walk up"],
		[mario, Vector2(0, 1), "m walk dn"], [mario, Vector2(1, 0), "m walk rt"],
		[mario, Vector2(-1, 0), "m walk lf"], [mario, Vector2(0, -1), "m walk up"],
	]
	for i in range(walkers.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(String(walkers[i][0]))
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(75 + (i % 4) * 150, 90 + (i / 4) * 100)
		cv.face(walkers[i][1] as Vector2, true)
		var tag := UIKit.label(String(walkers[i][2]), 5, UIKit.COL_GOOD)
		tag.position = cv.position + Vector2(-24, 10)
		add_child(tag)

	var actions := [
		[sora, "attack_1", Vector2(1, 0), "s atk1"],
		[sora, "attack_2", Vector2(1, 0), "s atk2"],
		[sora, "attack_3", Vector2(1, 0), "s atk3"],
		[sora, "attack_1", Vector2(0, 1), "s atk dn"],
		[sora, "special", Vector2(1, 0), "s special"],
		[sora, "roll", Vector2(1, 0), "s roll"],
		[mario, "attack_1", Vector2(1, 0), "m atk1"],
		[mario, "attack_1", Vector2(0, 1), "m atk dn"],
	]
	var visuals: Array = []
	for i in range(actions.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(String(actions[i][0]))
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(60 + i * 75, 310)
		visuals.append(cv)
		var tag2 := UIKit.label(String(actions[i][3]), 5, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-26, 8)
		add_child(tag2)

	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(0.4).timeout
	for i in range(actions.size()):
		(visuals[i] as CharacterVisual).play_action(String(actions[i][1]), actions[i][2] as Vector2)
	await get_tree().create_timer(0.1).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/sm_a.png")
	await get_tree().create_timer(0.15).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/sm_b.png")
	await get_tree().create_timer(0.2).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/sm_c.png")
	print("SORA_MARIO_FIX_DONE")
	get_tree().quit()
