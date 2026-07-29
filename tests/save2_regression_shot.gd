extends Node
## Windowed visual acceptance for the exact first-load regressions reported
## from save slot 2. Captures real report, market, negotiation and facing UI.

const SHOT_DIR := "user://screenshots/save2_regression/"
var failures: Array[String] = []


func _ready() -> void:
	AudioManager.set_muted(true)
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_add_backdrop()
	await get_tree().create_timer(0.8).timeout
	_load_regression_state()
	await _capture_briefing()
	await _capture_market()
	await _capture_negotiation()
	await _capture_facing()
	if failures.is_empty():
		print("SAVE2_REGRESSION_SHOT_PASS folder=",
			ProjectSettings.globalize_path(SHOT_DIR))
	else:
		for message in failures:
			printerr("SAVE2_REGRESSION_SHOT_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _load_regression_state() -> void:
	if SaveManager.load_from_slot(2) \
			and TimeManager.chapter == 5 and TimeManager.day == 15:
		return
	GameState.reset_campaign()
	TimeManager.from_save({"chapter": 5, "day": 15, "period": 1})
	MarketManager.from_save({"active_events": [
		{"days_left": 1, "id": "bottle_deposit"},
		{"days_left": 2, "id": "shard_glut"},
	]})
	RelationshipManager.from_save({"relationships": {
		"moogle_c": 42, "moogle_ff_c": 4, "peach_c": 6,
	}})


func _add_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("#69876a")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)


func _capture_briefing() -> void:
	var layer := DayBriefing.show_report(self)
	await get_tree().create_timer(0.45).timeout
	var panel := _modal_panel(layer)
	_check_panel_bounds(panel, "day report")
	_snap("01_save2_day_report.png")
	layer.queue_free()
	await get_tree().process_frame


func _capture_market() -> void:
	var market := MarketPanel.new()
	add_child(market)
	await get_tree().create_timer(0.35).timeout
	var panel := _modal_panel(market)
	_check_panel_bounds(panel, "market")
	var rows := market._list.get_children()
	check(not rows.is_empty(), "market rendered no rows")
	if not rows.is_empty():
		var first := UIKit._first_button_in(rows[0])
		check(first != null, "market first row has no usable button")
		if first != null:
			first.grab_focus()
			market._scroll.scroll_vertical = 0
			market._fill()
			await get_tree().process_frame
			await get_tree().process_frame
			var focus := get_viewport().gui_get_focus_owner()
			check(focus != null and market._list.is_ancestor_of(focus),
				"market rebuild lost the row cursor")
			check(market._scroll.scroll_vertical < 40,
				"market rebuild threw a top-row cursor to the bottom")
	_snap("02_save2_market_top.png")
	for _step in range(3):
		market._cycle_rarity()
		await get_tree().process_frame
		await get_tree().process_frame
	check(market._rarity_filter == "Rare",
		"market rarity filter did not cycle to Rare")
	for row: Node in market._list.get_children():
		if row.has_meta("item_id"):
			check(ContentDatabase.item_rarity(String(row.get_meta("item_id"))) == "Rare",
				"Rare filter displayed a non-Rare item")
	_snap("02b_market_rare_filter.png")
	market.queue_free()
	await get_tree().process_frame


func _capture_negotiation() -> void:
	var peach := CustomerGen.runtime_named(
		ContentDatabase.get_named_customer("peach_c"))
	peach["budget"] = 500000
	var panel := NegotiationPanel.new()
	panel.setup(peach, "kh_potion")
	add_child(panel)
	await get_tree().create_timer(0.45).timeout
	_check_panel_bounds(_modal_panel(panel), "negotiation")
	var labels := panel.find_children("*", "Label", true, false)
	var read_copy := ""
	for label: Label in labels:
		if label.text.begins_with("Price read"):
			read_copy = label.text
	check(read_copy != "" and "4000%" not in read_copy,
		"negotiation still presents the raw purse as an offer promise")
	_snap("03_peach_truthful_price_read.png")
	panel.queue_free()
	await get_tree().process_frame


func _capture_facing() -> void:
	var title := UIKit.label("Default player direction check", 20, Color.WHITE)
	title.position = Vector2(180, 85)
	add_child(title)
	var left := CharacterVisual.new()
	left.position = Vector2(260, 210)
	add_child(left)
	left.setup_from_manifest(
		"res://assets/hero/manifests/hero_faraway_overworld.json")
	left.scale = Vector2(3, 3)
	left.face(Vector2.LEFT, false)
	var left_label := UIKit.label("LEFT", 16, Color.WHITE)
	left_label.position = Vector2(225, 265)
	add_child(left_label)
	var right := CharacterVisual.new()
	right.position = Vector2(380, 210)
	add_child(right)
	right.setup_from_manifest(
		"res://assets/hero/manifests/hero_faraway_overworld.json")
	right.scale = Vector2(3, 3)
	right.face(Vector2.RIGHT, false)
	var right_label := UIKit.label("RIGHT", 16, Color.WHITE)
	right_label.position = Vector2(350, 265)
	add_child(right_label)
	await get_tree().create_timer(0.25).timeout
	check(left.animated.flip_h and not right.animated.flip_h,
		"default hero direction flags are reversed")
	_snap("04_default_player_left_right.png")


func _modal_panel(root: Node) -> PanelContainer:
	var panels := root.find_children("*", "PanelContainer", true, false)
	for panel: PanelContainer in panels:
		if panel.get_parent() is CenterContainer:
			return panel
	return null


func _check_panel_bounds(panel: PanelContainer, label: String) -> void:
	check(panel != null, "%s did not create an ornate modal" % label)
	if panel == null:
		return
	var rect := panel.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	print("SAVE2_BOUNDS ", label, " rect=", rect, " viewport=", viewport_size)
	check(rect.position.x >= -0.5 and rect.position.y >= -0.5
		and rect.end.x <= viewport_size.x + 0.5
		and rect.end.y <= viewport_size.y + 0.5,
		"%s extends outside the viewport: %s" % [label, rect])


func _snap(filename: String) -> void:
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
