extends Node
## Windowed visual proof for the complete shop-feedback pass. Captures into a
## dedicated folder so the player can review each feature independently.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/shop_feedback/"

	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		_reset_state()
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		SceneRouter.go("shop")
		await get_tree().create_timer(1.3).timeout
		var shop = get_tree().current_scene
		shop.dev_set_display_item(0, "kh_potion")

		var source := ContentDatabase.get_named_customer("moogle_c")
		var cust := CustomerGen.runtime_named(source)
		RelationshipManager.change_relationship(String(cust["id"]), 30)
		RelationshipManager.moods[String(cust["id"])] = 0.8
		shop._spawn_customer(cust)
		var customer: ShopCustomer = shop.live_customers[-1]
		customer.position = Vector2(385, 285)
		await get_tree().create_timer(0.1).timeout
		var arrival_line := customer.get_node_or_null("SpeechBubble")
		if arrival_line != null:
			arrival_line.queue_free()
		customer.show_emote("happy", 5.0)
		UIKit.gold_popup(shop.player, 650)
		await get_tree().create_timer(0.2).timeout
		_snap("01_deal_gold_and_happy_emote.png")

		customer._paused_for_negotiation = true
		shop.busy = true
		shop.player.frozen = true
		var panel := NegotiationPanel.new()
		panel.setup(cust, "kh_potion", customer.portrait_texture())
		shop.add_child(panel)
		await get_tree().create_timer(0.45).timeout
		_snap("02_negotiation_gold_and_bond.png")
		panel.queue_free()
		await get_tree().create_timer(0.8).timeout

		customer.position = Vector2(385, 330)
		customer.show_emote("unhappy", 5.0)
		shop._speech(customer, "That's ridiculous...")
		await get_tree().create_timer(0.12).timeout
		_snap("03_absurd_price_walkaway.png")

		shop.busy = false
		shop.player.frozen = false
		shop._open_furniture_catalog()
		await get_tree().create_timer(0.35).timeout
		_snap("04_gold_furniture_menu.png")
		_close_modal_layers(shop)
		await get_tree().process_frame

		await _capture_all_emotes(shop)
		await _capture_all_bonds(shop)
		await _capture_market(shop)
		await _capture_workshop(shop)
		await _capture_drop_sizes()
		print("SHOP_FEEDBACK_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
		get_tree().quit()


	func _reset_state() -> void:
		GameState.reset_campaign()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		BoomManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


	func _close_modal_layers(root: Node) -> void:
		for child in root.get_children():
			if child is CanvasLayer and (child as CanvasLayer).layer >= 40:
				child.queue_free()


	func _capture_all_emotes(shop: Node) -> void:
		shop.player.visible = false
		for child in shop.get_children():
			if child is PatchFollower:
				child.visible = false
		for prior: ShopCustomer in shop.live_customers:
			prior.queue_free()
		shop.live_customers.clear()
		await get_tree().process_frame
		var used: Dictionary = {}
		var kinds := ["unhappy", "boom", "happy", "overpaid", "neutral", "wealthy"]
		for i in kinds.size():
			var generated := CustomerGen._make_walk_in(used)
			used[CustomerGen._identity_key(generated)] = true
			shop._spawn_customer(generated)
			var node: ShopCustomer = shop.live_customers[-1]
			node.position = Vector2(165 + i * 62, 320)
			node._paused_for_negotiation = true
			for child in node.get_children():
				if child is Label:
					(child as Label).visible = false
			var tag := UIKit.label(String(kinds[i]).capitalize(), 7, Color.WHITE)
			tag.add_theme_color_override("font_outline_color", Color("#20243a"))
			tag.add_theme_constant_override("outline_size", 3)
			tag.position = Vector2(-22, 20)
			node.add_child(tag)
		await get_tree().create_timer(0.12).timeout
		for i in kinds.size():
			(shop.live_customers[i] as ShopCustomer).show_emote(kinds[i], 8.0)
		await get_tree().create_timer(0.15).timeout
		_snap("05_all_customer_emotes_and_unique_characters.png")


	func _capture_all_bonds(shop: Node) -> void:
		var parts := UIKit.modal(shop, "Customer bond levels")
		var vb: VBoxContainer = parts[1]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		for tier in range(1, 6):
			var column := VBoxContainer.new()
			column.alignment = BoxContainer.ALIGNMENT_CENTER
			column.add_child(UIKit.bond_icon(tier, Vector2(88, 88)))
			var tier_label := UIKit.label("Bond %d" % tier, 12, UIKit.COL_ACCENT)
			tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(tier_label)
			row.add_child(column)
		vb.add_child(row)
		vb.add_child(UIKit.label("Five relationship tiers — the crown marks maximum bond.", 10, UIKit.COL_DIM))
		await get_tree().create_timer(0.35).timeout
		_snap("06_all_customer_bond_tiers.png")
		_close_modal_layers(shop)
		await get_tree().process_frame


	func _capture_market(shop: Node) -> void:
		var market := MarketPanel.new()
		shop.add_child(market)
		await get_tree().create_timer(0.35).timeout
		_snap("07_gold_market_menu.png")
		market.queue_free()
		await get_tree().process_frame


	func _capture_workshop(shop: Node) -> void:
		var workshop := WorkshopPanel.new()
		shop.add_child(workshop)
		await get_tree().create_timer(0.35).timeout
		_snap("08_gold_workshop_menu.png")
		workshop.queue_free()
		await get_tree().process_frame


	func _capture_drop_sizes() -> void:
		GameState.meet_hero("sora")
		DungeonManager.plan_expedition("kingdom_hearts", "sora", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(1.5).timeout
		var dungeon = get_tree().current_scene
		dungeon.hero.global_position = Vector2(320, 315)
		for child in dungeon.get_children():
			if child is PatchFollower:
				child.visible = false
		var specs := [
			{"item": "kh_potion", "label": "Potion", "position": Vector2(200, 245)},
			{"item": "kh_ether", "label": "Ether", "position": Vector2(255, 245)},
			{"gold": 25, "label": "25 gold", "position": Vector2(315, 245)},
			{"gold": 150, "label": "150 gold", "position": Vector2(375, 245)},
			{"gold": 750, "label": "750 gold", "position": Vector2(435, 245)},
		]
		for spec: Dictionary in specs:
			var drop := LootPickup.new()
			dungeon.add_child(drop)
			if spec.has("item"):
				drop.setup_item(String(spec["item"]))
			else:
				drop.setup_gold(int(spec["gold"]))
			drop.global_position = spec["position"]
			var label := UIKit.label(String(spec["label"]), 7, Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color("#20243a"))
			label.add_theme_constant_override("outline_size", 3)
			label.position = Vector2(-18, 13)
			drop.add_child(label)
		await get_tree().create_timer(0.25).timeout
		_snap("09_item_and_gold_drop_size_comparison.png")


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
