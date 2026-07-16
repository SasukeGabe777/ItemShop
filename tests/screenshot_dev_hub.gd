extends Node2D
## Windowed visual smoke tour for the Live Developer Hub's responsive overlay.

var frame_count := 0
var output_dir := "user://screenshots"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	DirAccess.make_dir_recursive_absolute(output_dir)
	DevHubManager.select_development_world("kingdom_hearts")
	if DevHubManager.selected_location == "":
		DevHubManager.select_location("crossroads_shop")
	DevHubManager.open_hub("Today")


func _process(_delta: float) -> void:
	frame_count += 1
	match frame_count:
		30:
			_capture("dev_hub_today.png")
			DevHubManager.hub.call("open_hub", "Location")
		90:
			_capture("dev_hub_location.png")
			DevHubManager.hub.call("open_hub", "Spawn")
		150:
			_capture("dev_hub_spawn.png")
		180:
			print("DEV_HUB_SCREENSHOT_PASS")
			get_tree().paused = false
			get_tree().quit()


func _capture(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture " + file_name)
		return
	image.save_png(output_dir.path_join(file_name))
