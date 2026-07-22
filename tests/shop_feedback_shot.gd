extends Node
## Windowed visual proof in the real shop: customer emote + gold popup, bond
## and coin art in negotiation, then the absurd-price departure feedback.

class Probe:
	extends Node

	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		GameState.reset_campaign()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		BoomManager.reset()
		ShopFurnitureManager.reset()
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
		customer.position = Vector2(385, 245)
		customer.show_emote("happy", 5.0)
		UIKit.gold_popup(shop.player, 650)
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		await get_tree().create_timer(0.25).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_feedback_deal.png")

		customer._paused_for_negotiation = true
		shop.busy = true
		shop.player.frozen = true
		var panel := NegotiationPanel.new()
		panel.setup(cust, "kh_potion", customer.portrait_texture())
		shop.add_child(panel)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_feedback_bond.png")
		panel.queue_free()
		await get_tree().create_timer(0.8).timeout

		customer.position = Vector2(385, 330)
		customer.show_emote("unhappy", 5.0)
		shop._speech(customer, "That's ridiculous...")
		await get_tree().create_timer(0.12).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_feedback_walkaway.png")
		await get_tree().create_timer(0.2).timeout
		shop.busy = false
		shop.player.frozen = false
		shop._open_furniture_catalog()
		await get_tree().create_timer(0.35).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/shop_feedback_gold_menu.png")
		print("SHOP_FEEDBACK_SHOT_DONE")
		get_tree().quit()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
