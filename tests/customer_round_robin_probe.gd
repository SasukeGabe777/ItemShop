extends Node
## Proves that co-op orders and negotiations share one strict P1/P2 turn.

const SHOT_DIR := "user://screenshots/customer_round_robin/"


class Probe:
	extends Node

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		_reset_state()
		MultiplayerState.set_enabled(true)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		SceneRouter.go("shop")
		await get_tree().create_timer(1.2).timeout
		var shop := get_tree().current_scene
		MultiplayerState.next_customer_player = 2
		shop._begin_session()
		_expect(MultiplayerState.next_customer_player == 2,
			"a new shop session reset the ongoing round-robin turn")
		shop.session_active = false
		shop.customers_remaining.clear()
		MultiplayerState.next_customer_player = 1

		var customers: Array[ShopCustomer] = []
		for i in 4:
			customers.append(_add_customer(shop, "round_robin_%d" % i,
				Vector2(270 + i * 30, 350)))

		shop._on_negotiate_requested(customers[0].data, "kh_potion")
		_expect(shop._nego_player == 1, "first negotiation did not go to P1")
		var p1_negotiation := _negotiation_panel()
		_expect(p1_negotiation != null and p1_negotiation.get_viewport() == shop.get_viewport(),
			"P1 negotiation was missing or opened in the wrong viewport")
		await _save_shot("01_p1_negotiation.png")
		await _close_negotiation()

		# The expected player being busy must hold the queue; it must never skip
		# P2 and hand P1 a second consecutive customer.
		shop.busy2 = true
		shop.player2.frozen = true
		shop._on_negotiate_requested(customers[1].data, "kh_potion")
		_expect(shop.negotiating == null and shop.nego_queue.size() == 1,
			"second negotiation skipped busy P2 instead of waiting")
		shop.busy2 = false
		shop.player2.frozen = false
		shop._open_next_negotiation()
		_expect(shop._nego_player == 2, "second negotiation did not go to P2")
		var p2_negotiation := _negotiation_panel()
		_expect(p2_negotiation != null and p2_negotiation.get_viewport() == MultiplayerState.p2_viewport(),
			"P2 negotiation was missing or opened in the wrong viewport")
		await _save_shot("02_p2_negotiation.png")
		await _close_negotiation()

		var order1 := InventoryManager.add_order("round_robin_2", "item", "kh_potion",
			1, 100, 1, customers[2].data)
		shop._on_order_delivery_requested(customers[2].data, int(order1["id"]))
		_expect(shop._order_player == 1, "third shared interaction (order) did not return to P1")
		var p1_order := _order_dialog()
		_expect(p1_order != null and p1_order.get_viewport() == shop.get_viewport(),
			"P1 order was missing or opened in the wrong viewport")
		await _save_shot("03_p1_order.png")
		await _close_order()

		var order2 := InventoryManager.add_order("round_robin_3", "item", "kh_potion",
			1, 100, 1, customers[3].data)
		shop._on_order_delivery_requested(customers[3].data, int(order2["id"]))
		_expect(shop._order_player == 2, "fourth shared interaction (order) did not go to P2")
		var p2_order := _order_dialog()
		_expect(p2_order != null and p2_order.get_viewport() == MultiplayerState.p2_viewport(),
			"P2 order was missing or opened in the wrong viewport")
		await _save_shot("04_p2_order.png")
		await _close_order()

		# Let the two order-response speech tweens finish before replacing the
		# scene so their queued callbacks do not outlive their temporary labels.
		await get_tree().create_timer(3.2).timeout
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await get_tree().create_timer(0.25).timeout
		MultiplayerState.set_enabled(false)
		if failures.is_empty():
			print("CUSTOMER_ROUND_ROBIN_PROBE_PASS sequence=P1,P2,P1,P2")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("CUSTOMER_ROUND_ROBIN_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	func _reset_state() -> void:
		GameState.reset_campaign()
		GameState.tutorials_seen.append("first_shop_vertical_slice")
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BoomManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		InventoryManager.add_item("kh_potion", 6)
		InventoryManager.display[0] = "kh_potion"


	func _add_customer(shop: Node, id: String, at: Vector2) -> ShopCustomer:
		var customer := ShopCustomer.new()
		shop.add_child(customer)
		customer.position = at
		var data := {
			"id": id,
			"name": id.capitalize(),
			"archetype": "adventurer",
			"budget": 999999,
			"world": "kingdom_hearts",
			"named": false,
		}
		customer.setup(data, shop.browse_points, shop.ENTRANCE)
		shop.live_customers.append(customer)
		return customer


	func _negotiation_panel() -> NegotiationPanel:
		for node in get_tree().root.find_children("*", "NegotiationPanel", true, false):
			return node as NegotiationPanel
		return null


	func _order_dialog() -> OrderDialog:
		for node in get_tree().root.find_children("*", "OrderDialog", true, false):
			return node as OrderDialog
		return null


	func _close_negotiation() -> void:
		var panel := _negotiation_panel()
		_expect(panel != null, "negotiation panel was missing at close")
		if panel != null:
			panel._finish({"result": Negotiation.RESULT_LEAVE, "message": ""})
		await get_tree().process_frame
		await get_tree().process_frame


	func _close_order() -> void:
		var dialog := _order_dialog()
		_expect(dialog != null, "order dialog was missing at close")
		if dialog != null:
			dialog._finish("missing")
		await get_tree().process_frame
		await get_tree().process_frame


	func _save_shot(filename: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)
		_expect(error == OK, "could not save screenshot %s" % filename)


	func _expect(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
