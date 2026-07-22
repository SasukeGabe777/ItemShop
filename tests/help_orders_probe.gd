extends Node
## Headless proof for visible order requests/returns and the help encyclopedia.

const ORDER_DIALOG_SCRIPT := preload("res://scripts/ui/order_dialog.gd")
const HELP_PANEL_SCRIPT := preload("res://scripts/ui/help_encyclopedia_panel.gd")

var failures: Array[String] = []


func _ready() -> void:
	AudioManager.set_muted(true)
	GameState.reset_campaign()
	InventoryManager.reset()
	EconomyManager.reset()
	RelationshipManager.reset()
	TimeManager.reset(2)
	CustomerGen.rng.seed = 73021
	_check_order_limits()
	GameState.reset_campaign()
	InventoryManager.reset()
	EconomyManager.reset()
	RelationshipManager.reset()
	TimeManager.reset(2)
	await _check_order_lifecycle()
	await _check_help_and_encyclopedia()
	if failures.is_empty():
		print("HELP_ORDERS_PROBE_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_order_limits() -> void:
	var expected := [4, 6, 8, 10, 12]
	for shop_level in range(1, 6):
		GameState.shop_level = shop_level
		check(InventoryManager.order_capacity() == expected[shop_level - 1],
			"shop level %d order capacity is not %d" % [shop_level, expected[shop_level - 1]])
	GameState.shop_level = 1
	var customer := CustomerGen.runtime_named(ContentDatabase.get_named_customer("moogle_c"))
	for i in range(4):
		var added := InventoryManager.add_order("capacity_%d" % i, "item", "kh_potion", 1, 50, 2, customer)
		check(not added.is_empty(), "level 1 rejected order %d before reaching capacity" % (i + 1))
	check(InventoryManager.add_order("capacity_overflow", "item", "kh_potion", 1, 50, 2,
		customer).is_empty(), "level 1 accepted more than four orders")
	check(not InventoryManager.can_request_order(), "full order ledger still permits requests")
	var full_session := CustomerGen.generate_session_customers()
	check(full_session.filter(func(c: Dictionary) -> bool: return bool(c.get("order_intent", false))).is_empty(),
		"full order ledger generated a commission customer")
	InventoryManager.orders.clear()
	InventoryManager.last_order_request_day = -1
	var available_session := CustomerGen.generate_session_customers()
	check(available_session.filter(func(c: Dictionary) -> bool: return bool(c.get("order_intent", false))).size() <= 1,
		"more than one commission customer was planned for one day")
	check(InventoryManager.can_request_order(), "fresh day does not permit an order request")
	InventoryManager.mark_order_requested()
	check(not InventoryManager.can_request_order(), "a second order request is allowed on the same day")
	check(CustomerGen.make_order_offer(customer, false, true).is_empty(),
		"forced offer bypassed the one-request-per-day gate")
	var saved_inventory := InventoryManager.to_save()
	InventoryManager.reset()
	InventoryManager.from_save(saved_inventory)
	check(not InventoryManager.can_request_order(), "daily request limit was lost after saving and loading")
	TimeManager.day += 1
	check(InventoryManager.can_request_order(), "order requests did not reopen on the next day")
	check(not CustomerGen.make_order_offer(customer, false, true).is_empty(),
		"next-day order request could not generate an offer")


func _check_order_lifecycle() -> void:
	var source := ContentDatabase.get_named_customer("moogle_c")
	var customer := CustomerGen.runtime_named(source)
	var offer := CustomerGen.make_order_offer(customer, false, true)
	check(not offer.is_empty(), "forced customer commission did not produce an offer")
	check(String(offer.get("kind", "")) == "item", "order request is not for one specific item")
	check(ContentDatabase.is_live_item(String(offer.get("target", ""))), "order request targets unavailable art")
	var qty := int(offer.get("qty", 0))
	check(qty == 1 or qty >= 4, "order is neither a rarity nor a plentiful batch: %d" % qty)
	check(int(offer.get("return_in_days", 0)) in range(1, 5), "return promise is outside 1–4 days")

	var request_dialog := ORDER_DIALOG_SCRIPT.new()
	request_dialog.show_request(self, customer, offer, null)
	await get_tree().process_frame
	var request_text := _all_text(request_dialog)
	check("return on Day" in request_text and "Take the order" in request_text,
		"request dialogue does not state the return date and acceptance choice")
	request_dialog.queue_free()
	await get_tree().process_frame

	var order := InventoryManager.add_order(String(customer["id"]), "item", String(offer["target"]),
		qty, int(offer["reward_each"]), int(offer["return_in_days"]), customer)
	check(not order.is_empty(), "accepted order was not recorded")
	check(InventoryManager.due_orders().is_empty(), "customer returned before the promised day")
	TimeManager.day = int(order["return_day"])
	var due := InventoryManager.due_orders()
	check(due.size() == 1, "order is not due on its promised return day")
	var session := CustomerGen.generate_session_customers()
	var returners := session.filter(func(c: Dictionary) -> bool:
		return int(c.get("order_delivery_id", -1)) == int(order["id"]))
	check(returners.size() == 1, "the same customer did not return to request delivery")
	if not returners.is_empty():
		check(String(returners[0].get("name", "")) == String(customer["name"]),
			"returning order customer changed identity")
		var brain := CustomerBrain.new()
		add_child(brain)
		var requested_id := {"value": -1}
		brain.wants_order_delivery.connect(func(_c: Dictionary, order_id: int) -> void:
			requested_id["value"] = order_id)
		brain.setup(returners[0])
		brain.begin_browsing()
		brain.browse_time = 0.0
		brain.tick(0.1)
		check(int(requested_id["value"]) == int(order["id"]),
			"returning customer did not ask for delivery")
		brain.queue_free()

	InventoryManager.add_item(String(offer["target"]), qty)
	var before_gold := EconomyManager.gold
	var before_bond := RelationshipManager.points(String(customer["id"]))
	var delivery_dialog := ORDER_DIALOG_SCRIPT.new()
	delivery_dialog.show_delivery(self, customer, order, null)
	await get_tree().process_frame
	var delivery_text := _all_text(delivery_dialog)
	check("Deliver the items" in delivery_text and "I don't have it" in delivery_text,
		"return dialogue does not provide both delivery choices")
	delivery_dialog.queue_free()
	await get_tree().process_frame
	check(InventoryManager.try_fulfill_order(int(order["id"])), "stocked order could not be delivered")
	check(InventoryManager.count(String(offer["target"])) == 0, "delivery did not consume stock")
	check(EconomyManager.gold == before_gold + qty * int(offer["reward_each"]),
		"delivery payment is incorrect")
	check(RelationshipManager.points(String(customer["id"])) == before_bond + 8,
		"completed order did not create the major bond increase")

	var failed := InventoryManager.add_order(String(customer["id"]), "item", String(offer["target"]),
		4, int(offer["reward_each"]), 1, customer)
	var failure_bond := RelationshipManager.points(String(customer["id"]))
	check(InventoryManager.fail_order(int(failed["id"])), "missing-order response did not resolve order")
	check(RelationshipManager.points(String(customer["id"])) == failure_bond - 6,
		"failed order did not create the major bond decrease")


func _check_help_and_encyclopedia() -> void:
	for item_id in ["kh_potion", "kingdom_key", "lucid_shard", "rupee"]:
		GameState.learn_item(item_id)
	var panel := HELP_PANEL_SCRIPT.new()
	add_child(panel)
	await get_tree().process_frame
	var home_text := _all_text(panel)
	check("How to play" in home_text and "Order ledger" in home_text and "Encyclopedia" in home_text,
		"Help & Encyclopedia contents page is incomplete")
	panel.show_help()
	await get_tree().process_frame
	var help_text := _all_text(panel)
	for term in ["Bond", "Customer mood", "Purse", "Orders", "Haggling"]:
		check(term in help_text, "help topic is missing: %s" % term)
	panel.show_encyclopedia()
	await get_tree().process_frame
	var category_text := _all_text(panel)
	for category in ["Items", "Enemies", "Bosses", "Heroes", "Customers"]:
		check(category in category_text, "encyclopedia category is missing: %s" % category)
	panel.open_category("Items")
	await get_tree().process_frame
	check("Potion" in _all_text(panel), "item grid does not show recorded names")
	var entries: Array[Dictionary] = panel._entries("Items")
	check(not entries.is_empty(), "item encyclopedia has no recorded entries")
	if not entries.is_empty():
		panel.show_entry("Items", entries[0])
		await get_tree().process_frame
		check("Market value" in _all_text(panel), "item detail page lacks encyclopedia data")
	panel.open_category("Customers")
	await get_tree().process_frame
	var customer_entries: Array[Dictionary] = panel._entries("Customers")
	check(not customer_entries.is_empty(), "customer encyclopedia has no accessible entries")
	if not customer_entries.is_empty():
		var customer_entry := customer_entries[0]
		var customer_id := panel._customer_relationship_id(customer_entry["data"])
		GameState.know_customer(customer_id)
		RelationshipManager.change_relationship(customer_id, 13)
		panel.show_entry("Customers", customer_entry)
		await get_tree().process_frame
		var customer_text := _all_text(panel)
		check("Customer type" in customer_text and "Bond Lv." in customer_text,
			"customer detail page lacks type or bond data")
		check("Status: Met" in customer_text, "customer detail page does not show known status")
	panel.queue_free()
	await get_tree().process_frame


func _all_text(root: Node) -> String:
	var text := ""
	for node in root.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	for node in root.find_children("*", "Button", true, false):
		text += (node as Button).text + "\n"
	return text


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("HELP_ORDERS_PROBE_FAIL: " + message)
