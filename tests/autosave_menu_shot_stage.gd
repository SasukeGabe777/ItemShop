extends Node
## Stage 2: opens the real Continue dialog on the main menu and screenshots it,
## so the autosave row can be read as a player would see it.


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(3.0).timeout
	var menu: Node = get_tree().current_scene
	if menu == null or not menu.has_method("_on_load"):
		print("MENU FAIL: main menu not reachable (", menu, ")")
		get_tree().quit()
		return
	menu.call("_on_load")
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/autosave_menu.png")
	print("MENU_SHOT_DONE")
	get_tree().quit()
