extends Node
## Probe: does Player 2's pad actually drive menus inside their SubViewport?
## Simulates device-1 joypad events through the real input pipeline and
## reports the P2 viewport's focus owner after each step.
class Probe:
	extends Node
	func _ready() -> void:
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
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		DayBriefing.last_shown_day = TimeManager.day
		MultiplayerState.set_enabled(true)
		InventoryManager.add_item("kh_potion")
		SceneRouter.go("shop")
		await get_tree().create_timer(1.5).timeout
		var shop: Node = get_tree().current_scene
		shop._open_slot_picker(0, 2)
		await get_tree().create_timer(0.5).timeout
		var vp: Viewport = MultiplayerState.p2_viewport()
		print("P2 focus after open: ", _desc(vp.gui_get_focus_owner()))
		_pad(12, true)  # dpad down press (device 1)
		await get_tree().process_frame
		_pad(12, false)
		await get_tree().process_frame
		print("P2 focus after dpad-down: ", _desc(vp.gui_get_focus_owner()))
		_pad(12, true)
		await get_tree().process_frame
		_pad(12, false)
		await get_tree().process_frame
		print("P2 focus after dpad-down x2: ", _desc(vp.gui_get_focus_owner()))
		print("busy2 before A: ", shop.busy2)
		_pad(0, true)  # A press on focused button
		await get_tree().process_frame
		_pad(0, false)
		await get_tree().create_timer(0.3).timeout
		print("busy2 after A on focused: ", shop.busy2, "  focus: ", _desc(vp.gui_get_focus_owner()))
		print("P2_INPUT_PROBE_DONE")
		get_tree().quit()

	func _pad(button: int, pressed: bool) -> void:
		var ev := InputEventJoypadButton.new()
		ev.device = 1
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)

	func _desc(c: Control) -> String:
		if c == null:
			return "<null>"
		return "%s '%s'" % [c.get_class(), (c as Button).text if c is Button else ""]

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
