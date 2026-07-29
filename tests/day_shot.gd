extends Node
## Probe: screenshot the decluttered plaza with nameplates, the gates panel
## plank strip, and the end-of-day transition (skies + summary panel).
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
		DayBriefing.last_shown_day = TimeManager.day
		SceneRouter.go("town")
		await get_tree().create_timer(1.5).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		var town: Node = get_tree().current_scene
		town.player.position = Vector2(320, 250)
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/day_plaza.png")
		var gates := GatesPanel.new()
		town.add_child(gates)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/day_gates.png")
		gates.queue_free()
		await get_tree().create_timer(0.3).timeout
		var summary := {"sales": 3, "revenue": 420, "perfect": 1, "left": 1, "orders": 1,
			"sold": [{"item": "kh_potion", "price": 60}, {"item": "kh_potion", "price": 70},
				{"item": "kh_ether", "price": 290}]}
		TimeManager.day = 2
		DayTransition.show_transition(town, 1, summary, func() -> void: pass)
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/day_skies.png")
		await get_tree().create_timer(3.2).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/day_panel.png")
		# shop slot picker, market-style
		InventoryManager.add_item("kh_potion")
		InventoryManager.add_item("kh_ether")
		SceneRouter.go("shop")
		await get_tree().create_timer(1.5).timeout
		var shop: Node = get_tree().current_scene
		shop._open_slot_picker(0)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/day_picker.png")
		var picker := _top_modal(shop)
		var sort_button := _button_named(picker, "Sort:")
		if sort_button != null:
			sort_button.pressed.emit()
			await get_tree().create_timer(0.04).timeout
			get_viewport().get_texture().get_image().save_png(
				"user://screenshots/day_picker_pressed.png")
		shop._close_modal(_top_modal(shop))
		await get_tree().create_timer(0.3).timeout
		# mid-day period panel
		var psum := {"sales": 2, "revenue": 210, "perfect": 1, "left": 0, "orders": 0,
			"sold": [{"item": "kh_potion", "price": 90}, {"item": "kh_ether", "price": 120}]}
		DayTransition.show_period(shop, psum, func() -> void: pass)
		await get_tree().create_timer(1.4).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/day_period.png")
		for child in shop.get_children():
			if child is DayTransition:
				(child as DayTransition)._finish()
		await get_tree().create_timer(0.3).timeout
		# market with locked rows (scrolled to the bottom)
		var market := MarketPanel.new()
		shop.add_child(market)
		await get_tree().create_timer(0.6).timeout
		# A fresh save can schedule the first-session guide over the Market.
		# Close that unrelated modal so the focus-column screenshot is legible.
		var guide_overlay := _top_modal(shop)
		if guide_overlay != null:
			guide_overlay.queue_free()
			await get_tree().process_frame
		var market_buys: Array[Button] = []
		for child: Node in market._list.get_children():
			if child.has_meta("buy_button"):
				var buy := child.get_meta("buy_button") as Button
				if buy != null and not buy.disabled:
					market_buys.append(buy)
		if market_buys.size() >= 2:
			market_buys[0].grab_focus()
			await get_tree().process_frame
			_press("ui_down")
			await get_tree().process_frame
			print("DAY_SHOT_MARKET_FOCUS: ", get_viewport().gui_get_focus_owner().name)
			get_viewport().get_texture().get_image().save_png(
				"user://screenshots/day_market_focus_down.png")
		(market._list.get_parent() as ScrollContainer).scroll_vertical = 999999
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/day_market_locked.png")
		print("DAY_SHOT_DONE")
		get_tree().quit()

	func _top_modal(shop: Node) -> CanvasLayer:
		var best: CanvasLayer = null
		for layer: Node in shop.find_children("*", "CanvasLayer", false, false):
			if (layer as CanvasLayer).layer == 50:
				best = layer
		return best

	func _button_named(root: Node, prefix: String) -> Button:
		for node: Node in root.find_children("*", "Button", true, false):
			var button := node as Button
			if button.text.begins_with(prefix):
				return button
		return null

	func _press(action: String) -> void:
		for pressed: bool in [true, false]:
			var event := InputEventAction.new()
			event.action = action
			event.pressed = pressed
			Input.parse_input_event(event)

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
