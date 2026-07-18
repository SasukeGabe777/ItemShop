extends Node
## Probe: start a new campaign on slot 3, screenshot the intro story scene,
## report music/voice stream resolution, then delete the probe save.
class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		SceneRouter.start_new_campaign(3)
		await get_tree().create_timer(2.0).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		get_viewport().get_texture().get_image().save_png("user://screenshots/story_intro.png")
		print("TRACK=", AudioManager.current_track, " music_stream=", AudioManager.music_player.stream != null)
		print("VOICE_stream=", AudioManager.sfx_player.stream != null)
		for pressed in [true, false]:
			var ev := InputEventAction.new()
			ev.action = "interact"
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await get_tree().process_frame
		await get_tree().create_timer(1.6).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/story_intro2.png")
		SaveManager.delete_slot(3)
		print("STORY_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
