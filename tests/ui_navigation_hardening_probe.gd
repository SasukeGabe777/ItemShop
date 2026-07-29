extends Node
## Regression coverage for display stocking feedback/world labels, the full
## Guild roster, and controller-safe Market action columns.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	TimeManager.reset(9)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	await get_tree().process_frame
	await _probe_button_feedback()
	await _probe_guild_roster()
	await _probe_item_world()
	await _probe_market_columns()
	if failures.is_empty():
		print("UI_NAVIGATION_HARDENING_PROBE_PASS")
	else:
		for message: String in failures:
			printerr("UI_NAVIGATION_HARDENING_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _probe_button_feedback() -> void:
	var button := UIKit.button("Feedback", func() -> void: pass)
	add_child(button)
	button.pressed.emit()
	_check(button.modulate != Color.WHITE,
		"menu confirmation did not change the button visual")
	await get_tree().create_timer(0.2).timeout
	_check(button.modulate.is_equal_approx(Color.WHITE),
		"menu confirmation visual did not return to normal")
	button.queue_free()


func _probe_guild_roster() -> void:
	var guild := GuildPanel.new()
	add_child(guild)
	await get_tree().process_frame
	await get_tree().process_frame
	var hero_ids := guild._roster_hero_ids()
	_check(hero_ids.size() == ContentDatabase.heroes.size(),
		"Guild exposes %d heroes at full progression, expected %d" % [
			hero_ids.size(), ContentDatabase.heroes.size()])
	_check(guild.roster.get_child_count() == hero_ids.size(),
		"Guild roster buttons do not match its declared heroes")
	_check(guild.roster_scroll.horizontal_scroll_mode \
			== ScrollContainer.SCROLL_MODE_DISABLED,
		"Guild roster still permits a horizontal scrollbar")
	_check(not guild.roster_scroll.get_h_scroll_bar().visible,
		"Guild roster rendered a horizontal scrollbar")
	guild.queue_free()
	await get_tree().process_frame


func _probe_item_world() -> void:
	var shop_script := load("res://scripts/shop/shop.gd") as GDScript
	var shop: Node = shop_script.new()
	_check(shop._item_world_label("kh_potion") == "Kingdom Hearts",
		"display stocking does not resolve Kingdom Hearts item origins")
	var pick_layer := CanvasLayer.new()
	var row: Control = shop._make_pick_row("kh_potion", 0, pick_layer)
	var label_text: Array[String] = []
	for node: Node in row.find_children("*", "Label", true, false):
		label_text.append(String((node as Label).text))
	_check("Kingdom Hearts" in " ".join(label_text),
		"display stocking row does not show the item's world")
	row.free()
	pick_layer.free()
	shop.free()


func _probe_market_columns() -> void:
	var catalog := MarketManager.wholesale_catalog()
	for i in mini(2, catalog.size()):
		InventoryManager.add_item(String(catalog[i]))
	var market := MarketPanel.new()
	add_child(market)
	await get_tree().process_frame
	await get_tree().process_frame
	var buys: Array[Button] = []
	var sells: Array[Button] = []
	for child: Node in market._list.get_children():
		if not child.has_meta("buy_button"):
			continue
		var buy := child.get_meta("buy_button") as Button
		var sell := child.get_meta("sell_button") as Button
		if buy != null and not buy.disabled:
			buys.append(buy)
		if sell != null and not sell.disabled:
			sells.append(sell)
	_check(buys.size() >= 2, "Market probe could not find two enabled Buy buttons")
	_check(sells.size() >= 2, "Market probe could not find two enabled Sell buttons")
	if buys.size() >= 2:
		buys[0].grab_focus()
		await get_tree().process_frame
		_press("ui_down")
		await get_tree().process_frame
		_check(get_viewport().gui_get_focus_owner() == buys[1],
			"Market ui_down moved away from the Buy column")
		_press("ui_up")
		await get_tree().process_frame
		_check(get_viewport().gui_get_focus_owner() == buys[0],
			"Market ui_up moved away from the Buy column")
	if sells.size() >= 2:
		sells[0].grab_focus()
		await get_tree().process_frame
		_press("ui_down")
		await get_tree().process_frame
		_check(get_viewport().gui_get_focus_owner() == sells[1],
			"Market ui_down moved away from the Sell column")
	market.queue_free()
	await get_tree().process_frame


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
