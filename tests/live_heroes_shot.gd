extends Node2D
## Windowed probe for the live-capture hero rebuilds: Sora's field-swing
## attacks (4 facings) + Strike Raid throw & blade projectile, Mario's
## hammer/flame attacks, Luigi's full live rebuild (idles/walks/hammers).


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var bg := ColorRect.new()
	bg.color = Color("#274156")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)

	var sora := "res://assets/franchises/kingdom_hearts/manifests/sora.json"
	var mario := "res://assets/franchises/mario/manifests/mario.json"
	var luigi := "res://assets/franchises/mario/manifests/luigi.json"
	var walkers := [
		[luigi, Vector2(0, 1), "L walk dn"], [luigi, Vector2(1, 0), "L walk rt"],
		[luigi, Vector2(-1, 0), "L walk lf"], [luigi, Vector2(0, -1), "L walk up"],
		[luigi, Vector2.ZERO, "L idle"], [sora, Vector2(0, 1), "S walk dn"],
		[mario, Vector2(0, 1), "M walk dn"], [mario, Vector2(1, 0), "M walk rt"],
	]
	for i in range(walkers.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(String(walkers[i][0]))
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(70 + (i % 4) * 150, 80 + (i / 4) * 95)
		cv.face(walkers[i][1] as Vector2, walkers[i][1] != Vector2.ZERO)
		var tag := UIKit.label(String(walkers[i][2]), 5, UIKit.COL_GOOD)
		tag.position = cv.position + Vector2(-24, 10)
		add_child(tag)

	var actions := [
		[sora, "attack_1", Vector2(1, 0), "S a1"],
		[sora, "attack_2", Vector2(1, 0), "S a2"],
		[sora, "attack_3", Vector2(1, 0), "S a3"],
		[sora, "attack_1", Vector2(0, 1), "S a1dn"],
		[sora, "attack_1", Vector2(0, -1), "S a1up"],
		[sora, "special", Vector2(1, 0), "S raid"],
		[mario, "attack_1", Vector2(0, 1), "M ham dn"],
		[mario, "attack_1", Vector2(1, 0), "M ham rt"],
		[mario, "attack_2", Vector2(1, 0), "M fire"],
		[luigi, "attack_1", Vector2(1, 0), "L ham1"],
		[luigi, "attack_2", Vector2(1, 0), "L ham2"],
	]
	var visuals: Array = []
	for i in range(actions.size()):
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest(String(actions[i][0]))
		cv.scale = Vector2(2, 2)
		cv.position = Vector2(45 + i * 55, 300)
		visuals.append(cv)
		var tag2 := UIKit.label(String(actions[i][3]), 5, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-22, 8)
		add_child(tag2)

	# live Strike Raid blade projectile flying right
	var p := Projectile.new()
	var tex: Texture2D = load("res://assets/franchises/kingdom_hearts/processed/strike_raid_blade.png")
	p.setup({"damage": 0, "knockback": 0.0, "source": null}, Vector2.RIGHT, 120.0,
		Color.WHITE, 0, tex)
	p.position = Vector2(430, 355)
	p.lifetime = 3.0
	add_child(p)
	var bl := UIKit.label("blade ->", 5, UIKit.COL_GOOD)
	bl.position = Vector2(390, 348)
	add_child(bl)

	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(0.4).timeout
	for i in range(actions.size()):
		(visuals[i] as CharacterVisual).play_action(String(actions[i][1]), actions[i][2] as Vector2)
	await get_tree().create_timer(0.1).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/lh_a.png")
	await get_tree().create_timer(0.15).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/lh_b.png")
	await get_tree().create_timer(0.2).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/lh_c.png")
	print("LIVE_HEROES_DONE")
	get_tree().quit()
