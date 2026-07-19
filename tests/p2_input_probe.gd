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
		# an UNTAGGED event (what container-forwarding of P1's pad looks like)
		# must be swallowed by the gate and move nothing
		var intruder := InputEventJoypadButton.new()
		intruder.device = 0
		intruder.button_index = 11  # dpad up
		intruder.pressed = true
		vp.push_input(intruder)
		await get_tree().process_frame
		print("P2 focus after P1-style intruder (must be unchanged): ", _desc(vp.gui_get_focus_owner()))
		print("busy2 before A: ", shop.busy2)
		_pad(0, true)  # A press on focused button
		await get_tree().process_frame
		_pad(0, false)
		await get_tree().create_timer(0.3).timeout
		print("busy2 after A on focused: ", shop.busy2, "  focus: ", _desc(vp.gui_get_focus_owner()))
		# ---- the market-stuck repro: stick nav, focus recovery, B-to-close
		DayBriefing.last_shown_day = TimeManager.day
		SceneRouter.go("town")
		await get_tree().create_timer(1.2).timeout
		var town: Node = get_tree().current_scene
		vp = MultiplayerState.p2_viewport()
		town._activate("market", 2)
		await get_tree().create_timer(0.5).timeout
		if vp.gui_get_focus_owner() == null:
			# headless has no pad, so the auto-focus-on-open never ran; the
			# stick test needs a starting focus like a real session has
			var first := UIKit._first_button_in(vp)
			if first != null:
				first.grab_focus()
			await get_tree().process_frame
		var f0: Control = vp.gui_get_focus_owner()
		print("P2 market focus after open: ", _desc(f0))
		_stick(1, 1.0)  # left stick pushed down
		await get_tree().create_timer(0.2).timeout
		var f1: Control = vp.gui_get_focus_owner()
		print("P2 focus after stick-down (must differ): ", _desc(f1), "  moved=", f1 != f0)
		await get_tree().create_timer(0.6).timeout
		var f2: Control = vp.gui_get_focus_owner()
		print("P2 focus after stick HELD (repeat, must differ again): ", _desc(f2), "  moved=", f2 != f1)
		_stick(1, 0.0)
		await get_tree().process_frame
		# lost focus + A must recover onto the menu instead of soft-locking
		if vp.gui_get_focus_owner() != null:
			vp.gui_get_focus_owner().release_focus()
		await get_tree().process_frame
		_pad(0, true)
		await get_tree().process_frame
		_pad(0, false)
		await get_tree().process_frame
		print("P2 focus recovered by A after loss: ", _desc(vp.gui_get_focus_owner()))
		# B jumps to the Close button, then A closes the market
		_pad(1, true)
		await get_tree().process_frame
		_pad(1, false)
		await get_tree().process_frame
		print("P2 focus after B (must be Close): ", _desc(vp.gui_get_focus_owner()))
		_pad(0, true)
		await get_tree().process_frame
		_pad(0, false)
		await get_tree().create_timer(0.3).timeout
		print("P2 market closed: modal_open=", UIKit.modal_open(vp), "  busy2=", town.busy2)
		print("P2_INPUT_PROBE_DONE")
		get_tree().quit()

	func _stick(axis: int, value: float) -> void:
		var ev := InputEventJoypadMotion.new()
		ev.device = 1
		ev.axis = axis
		ev.axis_value = value
		Input.parse_input_event(ev)

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
