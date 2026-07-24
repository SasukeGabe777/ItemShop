extends Node
## M4 windowed screenshot probe: host enters the online lobby, a second
## (headless) instance joins and readies up, and the host screenshots the
## populated roster. Run WINDOWED — headless captures return null textures.


class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/net_lobby/"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		await _save_shot("00_main_menu_with_online_button.png")
		SceneRouter.go("online_lobby")
		await get_tree().create_timer(1.2).timeout
		await _save_shot("00b_choose_panel.png")
		_expect(Net.host_game("Gabe") == OK, "host_game failed")
		var scene := get_tree().current_scene
		_expect(scene != null and scene.scene_file_path.ends_with("online_lobby.tscn"),
			"did not land in the lobby scene")
		if scene != null and scene.has_method("_enter_lobby"):
			scene._enter_lobby()
		await get_tree().create_timer(0.6).timeout
		await _save_shot("01_host_lobby_alone.png")

		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_lobby_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")

		var readied := await _wait_for(func() -> bool:
			return PartyState.players.has(2) \
				and bool(PartyState.player(2).get("ready", false)), 20.0)
		_expect(readied, "client never joined+readied")
		await get_tree().create_timer(0.6).timeout
		await _save_shot("02_host_lobby_with_client_ready.png")

		Net.leave()
		if failures.is_empty():
			print("NET_LOBBY_SHOT_PASS shots=%s" % ProjectSettings.globalize_path(SHOT_DIR))
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_LOBBY_SHOT_FAIL: ", failure)
			get_tree().quit(1)


	func _save_shot(filename: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(SHOT_DIR + filename)
		_expect(error == OK, "could not save screenshot %s" % filename)


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _expect(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
