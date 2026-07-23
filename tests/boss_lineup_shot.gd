extends Node
## Windowed probe: every manifested boss spawned frozen in a grid, with a
## hero (Pikachu) for scale — verifies the enemy.gd boss height cap
## (playtest 2026-07-22: bosses filled a third of the screen). One shot
## before-fix vs after-fix is compared by rerunning at the two revisions.

const BOSSES := [
	"corrupted_fat_bandit", "guard_armor", "darkside",
	"red_dragon", "kaiser_dragon", "goddess",
	"big_green_chuchu", "big_blue_chuchu", "vaati",
	"zabuza", "kidomaru", "kimimaro",
	"perfect_cell", "bowser",
	"latios", "ho_oh", "mewtwo",
]

func _ready() -> void:
	# no menu scene: its CanvasLayer UI would cover the stage in screenshots
	get_tree().root.add_child.call_deferred(Probe.new())

class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(1.0).timeout
		var stage := Node2D.new()
		get_tree().root.add_child(stage)
		var bg := ColorRect.new()
		bg.color = Color(0.25, 0.3, 0.25)
		bg.size = Vector2(640, 360)
		bg.z_index = -10
		stage.add_child(bg)
		var dummy := CharacterBody2D.new()
		dummy.global_position = Vector2(-2000, -2000)
		stage.add_child(dummy)
		var i := 0
		for id in BOSSES:
			var boss := Boss.new()
			stage.add_child(boss)
			boss.setup(String(id), dummy)
			boss.global_position = Vector2(55 + (i % 6) * 105, 105 + (i / 6) * 115)
			boss.set_physics_process(false)
			var h := boss.visual.sprite_height() * boss.visual.scale.y
			print("BOSS %s rendered_h=%.0f scale=%.2f" % [id, h, boss.visual.scale.y])
			i += 1
		# hero for scale reference, bottom-right
		var hero_vis := CharacterVisual.new()
		stage.add_child(hero_vis)
		hero_vis.setup_from_manifest("res://assets/franchises/pokemon/manifests/pikachu.json")
		hero_vis.global_position = Vector2(590, 330)
		await get_tree().create_timer(1.2).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		get_viewport().get_texture().get_image().save_png("user://screenshots/boss_lineup.png")
		print("BOSS_LINEUP_DONE")
		get_tree().quit()
