extends Node2D
## Probe: line up a squad of newly wired CoM enemies (plus the rotation
## bosses), screenshot them, then kill one to capture the death effect.

const IDS := ["shadow_heartless", "soldier_heartless", "neoshadow", "defender",
	"wight_knight", "blue_rhapsody", "wizard_kh", "wyvern", "bouncywild",
	"white_mushroom"]  # guard_armor/darkside are bosses now (KH rotation)


func _ready() -> void:
	await get_tree().process_frame
	var bg := ColorRect.new()
	bg.color = Color("#2c3050")
	bg.size = Vector2(1300, 700)
	bg.z_index = -50
	add_child(bg)
	var target := Node2D.new()
	target.position = Vector2(640, 600)
	add_child(target)
	var victims: Array = []
	for i in range(IDS.size()):
		var e := Enemy.new()
		add_child(e)
		e.setup(IDS[i], target)
		e.position = Vector2(60 + (i % 6) * 104, 130 + (i / 6) * 170)
		e.set_physics_process(false)
		victims.append(e)
		var tag := UIKit.label(IDS[i], 6, UIKit.COL_ACCENT)
		tag.position = e.position + Vector2(-30, 8)
		add_child(tag)
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	get_viewport().get_texture().get_image().save_png("user://screenshots/enemy_lineup.png")
	victims[2].health.take_damage(99999, null)
	victims[4].health.take_damage(99999, null)
	await get_tree().create_timer(0.28).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/enemy_death_fx.png")
	print("ENEMY_SHOT_DONE")
	get_tree().quit()
