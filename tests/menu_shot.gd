extends Node
class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(1.4).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		get_viewport().get_texture().get_image().save_png("user://screenshots/menu_new.png")
		# simulate pressing Down twice to verify keyboard nav + cursor tracking
		for i in range(2):
			var ev := InputEventAction.new()
			ev.action = "ui_down"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/menu_new_nav.png")
		print("MENU_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
