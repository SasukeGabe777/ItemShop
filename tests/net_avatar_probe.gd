extends Node
## Character select: the host picks "aubrey", the client picks "mari", and in
## town each machine's OWN body and the remote puppet render the chosen
## avatar's manifest. Also screenshots the two distinct characters (windowed).


class Probe:
	extends Node

	const REPORT_PATH := "user://net_avatar_client.json"
	const SHOT_DIR := "user://screenshots/net_avatar/"

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		if FileAccess.file_exists(REPORT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_PATH))
		GameState.reset_campaign()
		GameState.campaign_active = true
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day

		_expect(Net.host_game("HostGabe") == OK, "host_game failed")
		Net.request("lobby.set_avatar", {"avatar": "aubrey"})
		var exe := OS.get_executable_path()
		var proj := ProjectSettings.globalize_path("res://")
		var pid := OS.create_process(exe,
			["--headless", "--path", proj, "res://tests/net_avatar_client.tscn"])
		_expect(pid > 0, "could not spawn client instance")
		var picked := await _wait_for(func() -> bool:
			return PartyState.players.has(2) \
				and String(PartyState.player(2).get("avatar", "")) == "mari", 20.0)
		_expect(picked, "client avatar pick never reached the host")

		SceneRouter.go("town")
		await get_tree().create_timer(2.0).timeout
		var town := get_tree().current_scene
		_expect(town != null and town.scene_file_path.ends_with("town.tscn"),
			"host did not reach town")

		# host's own body = aubrey
		var host_sheet := _sheet_of(town.get("player"))
		_expect(host_sheet.ends_with("aubrey.png"),
			"host body sheet wrong: %s" % host_sheet)

		# client's puppet on the host = mari
		var pupped := await _wait_for(func() -> bool:
			return (town.get("_net_puppets") as Dictionary).has(2), 20.0)
		_expect(pupped, "client puppet never appeared")
		if pupped:
			var pup_sheet := _sheet_of((town.get("_net_puppets") as Dictionary)[2])
			_expect(pup_sheet.ends_with("mari.png"),
				"client puppet sheet wrong: %s" % pup_sheet)
			# space them out and screenshot
			(town.get("player") as Node2D).global_position = Vector2(270, 300)
			var pup: Node2D = (town.get("_net_puppets") as Dictionary)[2]
			pup.global_position = Vector2(360, 300)
			await get_tree().create_timer(0.8).timeout
			await _save_shot("01_two_avatars.png")

		var reported := await _wait_for(func() -> bool:
			return FileAccess.file_exists(REPORT_PATH), 20.0)
		_expect(reported, "client never wrote its report")
		await get_tree().create_timer(0.5).timeout
		if reported:
			var f := FileAccess.open(REPORT_PATH, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f = null
			var report: Dictionary = parsed if parsed is Dictionary else {}
			_expect(String(report.get("error", "x")) == "", "client error: %s" % report.get("error"))
			_expect(String(report.get("my_sheet", "")).ends_with("mari.png"),
				"client's own body sheet wrong: %s" % report.get("my_sheet"))

		Net.leave()
		if failures.is_empty():
			print("NET_AVATAR_PROBE_PASS shots=%s" % ProjectSettings.globalize_path(SHOT_DIR))
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("NET_AVATAR_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	func _sheet_of(body: TownPlayer) -> String:
		if body == null or body.visual == null or body.visual.animated == null:
			return ""
		var frames := body.visual.animated.sprite_frames
		var anim := frames.get_animation_names()[0]
		var tex := frames.get_frame_texture(anim, 0)
		if tex is AtlasTexture:
			return (tex as AtlasTexture).atlas.resource_path
		return tex.resource_path if tex != null else ""


	func _save_shot(filename: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		var err := get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)
		_expect(err == OK, "could not save %s" % filename)


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
