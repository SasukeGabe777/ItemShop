extends Node
## Probe: BOTH players open separate item-stand pickers at the same time.
## Verifies the menus stay independent: P1's pad must never move P2's
## selector and vice versa, and each close only frees its own player.
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
		for i in range(4):
			InventoryManager.add_item("kh_potion")
		SceneRouter.go("shop")
		await get_tree().create_timer(1.5).timeout
		var shop: Node = get_tree().current_scene
		var vp2: Viewport = MultiplayerState.p2_viewport()
		# park each player on a different stand's interaction spot
		var spots: Array = []
		for ic: Node in get_tree().get_nodes_in_group("interactables"):
			if String(ic.get("action_id")).begins_with("slot_"):
				spots.append(ic)
		spots.sort_custom(func(a: Node, b: Node) -> bool:
			return String(a.get("action_id")) < String(b.get("action_id")))
		print("stands found: ", spots.map(func(s: Node) -> String: return String(s.get("action_id"))))
		if spots.size() < 2:
			print("DUAL_PICKER_PROBE_DONE (not enough stands)")
			get_tree().quit()
			return
		shop.player.position = (spots[0] as Node2D).position
		shop.player2.position = (spots[1] as Node2D).position
		await get_tree().create_timer(0.3).timeout
		# both pickers open on the SAME frame — the user's repro
		shop._activate("slot_0", 1)
		shop._activate("slot_1", 2)
		await get_tree().create_timer(0.6).timeout
		# headless grants no auto-focus (no pad) — give each side its start
		for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			var in_root: bool = layer.get_viewport() == get_viewport()
			var btn := UIKit._first_button_in(layer)
			print("  layer '%s' layer=%d root=%s button=%s" % [layer.name,
				int(layer.get("layer")), in_root, _desc(btn)])
		if get_viewport().gui_get_focus_owner() == null:
			for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
				if int(layer.get("layer")) == 50 and layer.get_viewport() == get_viewport():
					var b1 := UIKit._first_button_in(layer)
					if b1 != null:
						b1.grab_focus()
					break
		await get_tree().process_frame  # let the focus keeper remember P1's spot
		var b2 := UIKit._first_button_in(vp2)
		if b2 != null:
			b2.grab_focus()  # this WIPES P1's engine focus (one focus per window)
		await get_tree().process_frame
		print("busy=", shop.busy, " busy2=", shop.busy2, " owners=", shop._menu_owner)
		print("P1 engine focus after P2 grab (wiped, expected null): ",
			_desc(get_viewport().gui_get_focus_owner()),
			"  P1 remembered: ", _desc(_mem(1)))
		# P1 d-pad down: their selector must come back AND move; P2's
		# virtual selector must stay where it was
		var p2v0: Control = _mem(2)
		_pad(0, 12, true)
		await get_tree().process_frame
		_pad(0, 12, false)
		await get_tree().process_frame
		print("after P1 dpad-down: P1 selector=", _desc(get_viewport().gui_get_focus_owner()),
			"  P2 virtual unchanged=", _mem(2) == p2v0, " (", _desc(_mem(2)), ")")
		# P2 d-pad down: their selector restores and continues from its spot
		var p1v0: Control = _mem(1)
		_pad(1, 12, true)
		await get_tree().process_frame
		_pad(1, 12, false)
		await get_tree().process_frame
		print("after P2 dpad-down: P2 selector=", _desc(vp2.gui_get_focus_owner()),
			" moved-from-own-spot=", vp2.gui_get_focus_owner() != p2v0,
			"  P1 virtual unchanged=", _mem(1) == p1v0, " (", _desc(_mem(1)), ")")
		# P1 closes their picker (B jump + A) — P2's menu must survive
		_pad(0, 1, true)
		await get_tree().process_frame
		_pad(0, 1, false)
		await get_tree().process_frame
		print("P1 focus after B (must be Cancel/Close): ", _desc(get_viewport().gui_get_focus_owner()))
		_pad(0, 0, true)
		await get_tree().process_frame
		_pad(0, 0, false)
		await get_tree().create_timer(0.4).timeout
		print("after P1 closes: busy=", shop.busy, " busy2=", shop.busy2,
			" p2 modal_open=", UIKit.modal_open(vp2))
		# and P2 keeps navigating happily afterwards
		_pad(1, 12, true)
		await get_tree().process_frame
		_pad(1, 12, false)
		await get_tree().process_frame
		print("P2 selector after P1 left: ", _desc(vp2.gui_get_focus_owner()))
		print("DUAL_PICKER_PROBE_DONE")
		get_tree().quit()

	func _mem(idx: int) -> Control:
		var m: Variant = MultiplayerState._focus_mem.get(idx)
		return m if m != null and is_instance_valid(m) else null

	## Are the picker layers parented into the right viewport for each player?
	func _layer_vp_ok(shop: Node, who: int) -> bool:
		var target: Viewport = shop.get_viewport() if who == 1 else MultiplayerState.p2_viewport()
		for layer: Node in shop.get_tree().root.find_children("*", "CanvasLayer", true, false):
			if layer.get("layer") == 50 and layer.get_viewport() == target:
				return true
		return false

	func _pad(device: int, button: int, pressed: bool) -> void:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)

	func _stick(device: int, axis: int, value: float) -> void:
		var ev := InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = axis
		ev.axis_value = value
		Input.parse_input_event(ev)

	func _desc(c: Control) -> String:
		if c == null:
			return "<null>"
		return "%s '%s'" % [c.get_class(), (c as Button).text if c is Button else ""]

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
