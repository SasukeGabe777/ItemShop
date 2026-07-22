extends Node
## Windowed visual proof for customer order dialogue and the two-page handbook.

const SHOT_DIR := "user://screenshots/help_encyclopedia_orders/"
const ORDER_DIALOG_SCRIPT := preload("res://scripts/ui/order_dialog.gd")
const HELP_PANEL_SCRIPT := preload("res://scripts/ui/help_encyclopedia_panel.gd")


func _ready() -> void:
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	GameState.reset_campaign()
	InventoryManager.reset()
	EconomyManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	TimeManager.reset(2)
	GameState.tutorials_seen.append("first_shop_vertical_slice")
	for item_id in ["kh_potion", "kh_ether", "kingdom_key", "lucid_shard", "blaze_shard", "fire_flower", "super_mushroom", "rupee", "deku_nut", "pokeball"]:
		GameState.learn_item(item_id)
	var customer := CustomerGen.runtime_named(ContentDatabase.get_named_customer("moogle_c"))
	var entry := ContentDatabase.customer_pool_entry_by_name(String(customer["name"]))
	var portrait: Texture2D = load(String(entry.get("static", "")))
	var shop: Node = load("res://scenes/shop/shop.tscn").instantiate()
	add_child(shop)
	await get_tree().create_timer(0.6).timeout
	var visible_customer := ShopCustomer.new()
	shop.add_child(visible_customer)
	visible_customer.position = Vector2(74, 245)
	visible_customer.setup(customer, [visible_customer.position], Vector2(320, 400))
	visible_customer.set_physics_process(false)

	var request_offer := {
		"kind": "item", "target": "kingdom_key", "qty": 1,
		"reward_each": 2220, "return_in_days": 3, "order_type": "special",
	}
	var request := ORDER_DIALOG_SCRIPT.new()
	request.show_request(shop, customer, request_offer, portrait)
	await get_tree().create_timer(0.35).timeout
	_snap("01_customer_specific_order_request.png")
	request.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var order := InventoryManager.add_order(String(customer["id"]), "item", "kh_potion", 6, 95, 2, customer)
	TimeManager.day = int(order["return_day"])
	InventoryManager.add_item("kh_potion", 6)
	var delivery := ORDER_DIALOG_SCRIPT.new()
	delivery.show_delivery(shop, customer, order, portrait)
	await get_tree().create_timer(0.35).timeout
	_snap("02_customer_returns_for_delivery.png")
	delivery.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var handbook := HELP_PANEL_SCRIPT.new()
	shop.add_child(handbook)
	await get_tree().create_timer(0.35).timeout
	_snap("03_help_encyclopedia_contents.png")
	handbook.show_help()
	handbook._show_help_topic("Orders")
	await get_tree().create_timer(0.25).timeout
	_snap("04_help_orders_and_bond_guidance.png")
	handbook.show_encyclopedia()
	await get_tree().create_timer(0.25).timeout
	_snap("05_encyclopedia_categories.png")
	handbook.open_category("Items")
	await get_tree().create_timer(0.25).timeout
	_snap("06_item_sprite_browser_and_entry.png")
	handbook.open_category("Enemies")
	await get_tree().create_timer(0.25).timeout
	_snap("07_enemy_sprite_browser_and_entry.png")
	var customer_entries: Array[Dictionary] = handbook._entries("Customers")
	if not customer_entries.is_empty():
		var customer_id := handbook._customer_relationship_id(customer_entries[0]["data"])
		GameState.know_customer(customer_id)
		RelationshipManager.change_relationship(customer_id, 13)
	handbook.open_category("Customers")
	await get_tree().create_timer(0.25).timeout
	_snap("08_customer_sprite_browser_and_bond_entry.png")
	print("HELP_ORDERS_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
	get_tree().quit()


func _snap(filename: String) -> void:
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)
