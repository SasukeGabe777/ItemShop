extends Node
## Client half of tests/net_shop_probe. Follows the host into the shop, sees
## the customer puppet, receives a negotiation assignment, plays it out to an
## accepted sale, and confirms the synced economy afterwards.


class Worker:
	extends Node

	const OUT_PATH := "user://net_shop_client.json"
	const SHOT_PATH := "user://screenshots/net_fixes/client_live_stock.png"

	var report: Dictionary = {
		"joined": false, "in_shop": false, "customer_seen": false,
		"panel_seen": false, "remote_display_visible": false,
		"remote_furniture_visible": false,
		"gold_after": -1, "display0_after": "x", "error": "",
	}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "ShopBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true

		var in_shop := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("shop.tscn"), 25.0)
		report["in_shop"] = in_shop
		if not in_shop:
			_finish("never followed into the shop")
			return
		# Separate the local body from P1 so the windowed proof clearly shows
		# the selected character and its fairy as two independent sprites.
		(get_tree().current_scene.get("player") as TownPlayer).global_position = \
			Vector2(390, 300)

		report["remote_furniture_visible"] = await _wait_for(func() -> bool:
			if not ShopFurnitureManager.layout.any(func(inst: Dictionary) -> bool:
					return String(inst.get("type", "")) == "basic_glass_box"):
				return false
			var shop := get_tree().current_scene
			for piece: DisplayFurniture in shop.get("furniture_nodes"):
				if piece.type_id == "basic_glass_box":
					return true
			return false, 10.0)

		# P1 stocks a second stand while we remain inside. Verify the incoming
		# authoritative state redraws furniture without a scene reload.
		report["remote_display_visible"] = await _wait_for(func() -> bool:
			if InventoryManager.display.size() <= 2 \
					or String(InventoryManager.display[2]) != "kingdom_key":
				return false
			var shop := get_tree().current_scene
			for piece in shop.get("furniture_nodes"):
				var furniture := piece as DisplayFurniture
				if furniture.slot_base <= 2 \
						and 2 < furniture.slot_base + furniture.slot_count:
					var sprite := furniture.get_node_or_null(
						"ItemSprite%d" % (2 - furniture.slot_base)) as Sprite2D
					return sprite != null and sprite.texture != null
			return false, 10.0)
		if DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(
				"user://screenshots/net_fixes/")
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png(SHOT_PATH)

		# The host injects a replicated customer, then assigns it to us.
		report["customer_seen"] = await _wait_for(func() -> bool:
			for node in get_tree().get_nodes_in_group("shop_customers"):
				return true
			return _any_customer(), 20.0)

		# NB: lambda captures are by value — find the panel again after waiting
		var panel_up := await _wait_for(func() -> bool:
			return not get_tree().root.find_children("*", "NegotiationPanel", true, false).is_empty(), 25.0)
		report["panel_seen"] = panel_up
		if not panel_up:
			_finish("assignment panel never opened")
			return
		var panels := get_tree().root.find_children("*", "NegotiationPanel", true, false)
		var panel := panels[0] as NegotiationPanel
		await get_tree().create_timer(0.5).timeout
		panel._finish({"result": Negotiation.RESULT_ACCEPT, "price": 40, "quantity": 1,
			"perfect": false, "relationship_delta": 1, "message": "Deal!", "emote": "neutral"})

		# The host applies the sale and syncs it back down.
		var synced := await _wait_for(func() -> bool:
			return not (String("kh_potion") in InventoryManager.displayed_ids()), 15.0)
		report["gold_after"] = EconomyManager.gold
		report["display0_after"] = String(InventoryManager.display[0]) \
			if InventoryManager.display.size() > 0 else "?"
		_finish("" if synced else "sale never synced back")


	func _any_customer() -> bool:
		var scene := get_tree().current_scene
		if scene == null:
			return false
		for child in scene.get_children():
			if child is ShopCustomer:
				return true
		return false


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _finish(err: String) -> void:
		report["error"] = err
		var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report))
			f = null
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
