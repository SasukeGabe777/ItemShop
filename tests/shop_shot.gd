extends Node
## Probe: fresh state -> shop. Screenshot the first-time guide + corner
## buttons, then reload with the tutorial seen, stock stands, open a session
## and screenshot the FF-pool customers browsing.
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
		SceneRouter.go("shop")
		await get_tree().create_timer(2.0).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_guide.png")
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		ZoomCamera.preferred_zoom = 1.0
		SceneRouter.go("shop")
		await get_tree().create_timer(1.5).timeout
		var shop: Node = get_tree().current_scene
		for i in range(6):
			shop.dev_set_display_item(i, ["kh_potion", "kh_ether", "ff_potion", "super_mushroom", "rupee", "senzu_bean"][i])
		shop.dev_open_shop()
		await get_tree().create_timer(3.2).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_browse.png")
		await get_tree().create_timer(3.8).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_session.png")
		print("CUSTOMERS=", shop.live_customers.size())
		for c: Node in shop.live_customers:
			print("CUST_NAME=", c.data.get("name", "?"), " arch=", c.data.get("archetype", ""))
		var goku_frames := SpriteFramesBuilder.from_manifest_path("res://assets/franchises/dragon_ball/manifests/pool_goku.json")
		print("GOKU_ANIMS=", goku_frames.get_animation_names() if goku_frames != null else "null")
		print("NEGO_stream=", AudioManager._resolve_stream("negotiation") != null)
		# freeze the live session so its own negotiations can't stack on top of
		# the forced panel below
		shop.session_active = false
		shop.busy = true
		for child in shop.get_children():
			if child is NegotiationPanel:
				child.queue_free()
		await get_tree().create_timer(0.3).timeout
		# tiny budget on purpose: exercises the purse indicator + budget-capped
		# counteroffer notes in the negotiation screenshot
		var cust := {"id": "probe_cust", "name": "Kakashi", "archetype": "adventurer",
			"budget": 25, "world": "naruto", "named": true, "line": "Yo. Nice shop."}
		var nego_panel := NegotiationPanel.new()
		nego_panel.setup(cust, "kh_potion", load("res://assets/franchises/naruto/processed/customers/kakashi.png"))
		shop.add_child(nego_panel)
		await get_tree().create_timer(0.5).timeout
		nego_panel.price_spin.value = 240
		nego_panel._propose()
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_nego.png")
		print("NEGO_track=", AudioManager.current_track)
		nego_panel.queue_free()
		shop.dev_close_shop()
		for child in shop.get_children():
			if child is NegotiationPanel:
				child.queue_free()
		# storage chest area: walk the player up-left so the chest is on screen
		shop.player.position = Vector2(210, 190)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_storage.png")
		# decor pieces + y-sort: player standing BEHIND the trophy must draw
		# behind it, stands must never draw over the player
		shop.dev_spawn_furniture("dragon_trophy", Vector2(440, 250))
		shop.dev_spawn_furniture("crystal_cluster", Vector2(150, 280))
		shop.dev_spawn_furniture("woven_rug", Vector2(320, 330))
		shop.player.position = Vector2(440, 235)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_decor_placed.png")
		shop._open_decor_catalog()
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_decor_catalog.png")
		for child in shop.get_children():
			if child is CanvasLayer and child.layer == 50:
				child.queue_free()
		shop.busy = false
		shop.player.frozen = false
		await get_tree().create_timer(0.2).timeout
		print("APPEAL=", InventoryManager.shop_appeal())
		# Patch's end-of-session debrief
		PatchDebrief.show_debrief(shop, {"sales": 3, "revenue": 460, "perfect": 2, "left": 1, "orders": 0}, Callable())
		await get_tree().create_timer(0.7).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_debrief.png")
		for child in shop.get_children():
			if child is PatchDebrief:
				child._finish()
		await get_tree().create_timer(0.2).timeout
		# level-gated furniture catalog
		shop._open_furniture_catalog()
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_catalog.png")
		for child in shop.get_children():
			if child is CanvasLayer and child.layer == 50:
				child.queue_free()
		shop.busy = false
		shop.player.frozen = false
		# walking past the bottom entrance auto-exits to the Crossroads
		shop.player.position = Vector2(320, 430)
		await get_tree().create_timer(1.4).timeout
		print("EXIT_SCENE=", get_tree().current_scene.scene_file_path)
		print("SHOP_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
