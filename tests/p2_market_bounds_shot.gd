extends Node
## Proves Large two-player market modals stay inside each player's region in
## both a window and true fullscreen. Prints exact transformed panel bounds.

const SHOT_DIR := "user://screenshots/p2_market_bounds/"
const EPSILON := 1.0


class Probe:
	extends Node

	var failures: Array[String] = []

	func _ready() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().create_timer(0.8).timeout
		GameState.reset_campaign()
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		MultiplayerState.set_enabled(true)
		MultiplayerState.set_ui_scale_preset(2)
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		var town := get_tree().current_scene
		await _open_measure_close(town, 1, "01_windowed_p1_market.png")
		await _open_measure_close(town, 2, "02_windowed_p2_market.png")
		_press_f11()
		await get_tree().create_timer(1.2).timeout
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			failures.append("F11 did not enter fullscreen")
		await _open_measure_close(town, 1, "03_fullscreen_p1_market.png")
		await _open_measure_close(town, 2, "04_fullscreen_p2_market.png")
		_press_f11()
		await get_tree().create_timer(0.4).timeout
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			failures.append("F11 did not return to windowed mode")
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await get_tree().process_frame
		MultiplayerState.set_ui_scale_preset(1)
		MultiplayerState.set_enabled(false)
		if failures.is_empty():
			print("P2_MARKET_BOUNDS PASS folder=",
				ProjectSettings.globalize_path(SHOT_DIR))
		else:
			for failure in failures:
				print("P2_MARKET_BOUNDS FAIL: ", failure)
		get_tree().quit(0 if failures.is_empty() else 1)

	func _open_measure_close(town: Node, who: int, filename: String) -> void:
		town.call("_activate", "market", who)
		await get_tree().create_timer(0.7).timeout
		var root: Node = town if who == 1 else MultiplayerState.p2_viewport()
		var markets := root.find_children("*", "MarketPanel", true, false)
		if markets.is_empty():
			failures.append("%s: market panel was not created" % filename)
			return
		var market := markets[0]
		var panels := market.find_children("*", "PanelContainer", true, false)
		if panels.is_empty():
			failures.append("%s: ornate panel was not created" % filename)
			market.queue_free()
			await get_tree().process_frame
			return
		if filename == "01_windowed_p1_market.png":
			var sort_button := _find_button(market, "Sort: Hot →")
			if sort_button == null:
				failures.append("Large market did not use the compact Sort control")
			else:
				sort_button.pressed.emit()
				await get_tree().create_timer(0.1).timeout
				if sort_button.text != "Sort: Name →":
					failures.append("compact Sort control did not cycle to Name")
		var panel := panels[0] as PanelContainer
		var smallest_font := 1000
		for node in market.find_children("*", "Control", true, false):
			var control := node as Control
			if control.has_theme_font_size_override("font_size"):
				smallest_font = mini(
					smallest_font, control.get_theme_font_size("font_size"))
		if smallest_font < 13:
			failures.append("%s: Large modal font remained %dpx" % [
				filename, smallest_font])
		var bounds := _screen_bounds(panel)
		var available := _available_rect(who, panel.get_viewport())
		var fits := available.grow(EPSILON).encloses(bounds)
		print("P2_MARKET_RECT ", filename, " panel=", bounds,
			" available=", available, " min_font=", smallest_font,
			" fits=", fits)
		if not fits:
			failures.append("%s: %s exceeds %s" % [filename, bounds, available])
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)
		var close := _find_button(market, "Close")
		if close != null:
			close.pressed.emit()
		else:
			market.queue_free()
		await get_tree().create_timer(0.25).timeout

	func _press_f11() -> void:
		var event := InputEventKey.new()
		event.keycode = KEY_F11
		event.physical_keycode = KEY_F11
		event.pressed = true
		Input.parse_input_event(event)
		var release := event.duplicate()
		release.pressed = false
		Input.parse_input_event(release)

	func _find_button(root: Node, text: String) -> Button:
		for node in root.find_children("*", "Button", true, false):
			if (node as Button).text == text:
				return node as Button
		return null

	func _screen_bounds(control: Control) -> Rect2:
		var xform := control.get_global_transform_with_canvas()
		var points := [
			xform * Vector2.ZERO,
			xform * Vector2(control.size.x, 0),
			xform * control.size,
			xform * Vector2(0, control.size.y),
		]
		var lo: Vector2 = points[0]
		var hi: Vector2 = points[0]
		for point: Vector2 in points:
			lo = lo.min(point)
			hi = hi.max(point)
		return Rect2(lo, hi - lo)

	func _available_rect(who: int, vp: Viewport) -> Rect2:
		var size := Vector2(vp.get_visible_rect().size)
		if who == 1:
			return Rect2(Vector2.ZERO, Vector2(size.x * 0.5, size.y))
		return Rect2(Vector2.ZERO, size)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
