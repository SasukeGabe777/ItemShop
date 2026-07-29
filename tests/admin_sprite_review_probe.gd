extends Node
## Headless proof for the secret @ activation, all-content checklists, and the
## grouped Markdown/clipboard export used for sprite correction passes.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	GameState.admin_mode = false
	GameState.admin_review_flags.clear()
	GameState.admin_item_flags.clear()
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = 64
	GameState._input(event)
	_check(GameState.admin_mode, "@ did not enable admin mode")
	var panel := HelpEncyclopediaPanel.new()
	add_child(panel)
	panel.show_encyclopedia()
	var items := panel._entries("Items")
	var enemies := panel._entries("Enemies")
	var heroes := panel._entries("Heroes")
	var npcs := panel._entries("NPCs")
	var customers := panel._entries("Customers")
	_check(items.size() == ContentDatabase.items.size(),
		"admin item checklist is not generated from the complete item data pack")
	_check(enemies.size() == ContentDatabase.enemies.size(),
		"admin enemy checklist is still filtered by campaign access")
	_check(heroes.size() == ContentDatabase.heroes.size(),
		"admin hero checklist is not generated from the complete hero data pack")
	_check(npcs.size() == ContentDatabase.npcs.size(),
		"admin NPC checklist is not generated from the complete NPC data pack")
	_check(not customers.is_empty(), "admin character checklist has no customer visuals")
	_check(_has_entry(customers, "sora_c"),
		"authored customer without pool art is missing from the admin checklist")
	if items.is_empty() or enemies.is_empty() or customers.is_empty():
		_finish(panel)
		return
	var item: Dictionary = items[0]
	var enemy: Dictionary = enemies[0]
	var customer: Dictionary = customers[0]
	GameState.set_admin_review_flag("Items", String(item["id"]), true)
	GameState.set_admin_review_flag("Enemies", String(enemy["id"]), true)
	GameState.set_admin_review_flag("Customers", String(customer["id"]), true)
	panel.open_category("Items")
	var checks := panel.find_children("AdminReviewCheck", "CheckBox", true, false)
	_check(checks.size() >= items.size(), "admin item list is missing review checkboxes")
	panel._export_admin_review()
	var export_path := ProjectSettings.globalize_path(HelpEncyclopediaPanel.ADMIN_EXPORT_PATH)
	_check(FileAccess.file_exists(HelpEncyclopediaPanel.ADMIN_EXPORT_PATH), "Markdown review export was not created")
	if FileAccess.file_exists(HelpEncyclopediaPanel.ADMIN_EXPORT_PATH):
		var file := FileAccess.open(HelpEncyclopediaPanel.ADMIN_EXPORT_PATH, FileAccess.READ)
		var markdown := file.get_as_text()
		_check("## Items" in markdown and "## Characters" in markdown and "## Enemies" in markdown,
			"Markdown export is missing grouped review sections")
		_check("`%s`" % String(item["id"]) in markdown, "flagged item missing from export")
		_check("`%s`" % String(enemy["id"]) in markdown, "flagged enemy missing from export")
		_check("`%s`" % String(customer["id"]) in markdown, "flagged customer missing from export")
	var item_id := String(item["id"])
	GameState.set_admin_item_issue(item_id, "wrong_world", true)
	GameState.set_admin_item_note(item_id, "Expected world correction from playtest.")
	_check(GameState.is_admin_item_issue_flagged(item_id, "wrong_world"),
		"structured item issue was not stored")
	_check(FileAccess.file_exists(GameState.ADMIN_ITEM_FLAGS_PATH),
		"persistent item-audit draft was not created")
	panel._export_item_audit_pack()
	_check(FileAccess.file_exists(HelpEncyclopediaPanel.ADMIN_ITEM_EXPORT_JSON),
		"item audit JSON pack was not created")
	_check(FileAccess.file_exists(HelpEncyclopediaPanel.ADMIN_ITEM_EXPORT_MD),
		"item audit Markdown pack was not created")
	if FileAccess.file_exists(HelpEncyclopediaPanel.ADMIN_ITEM_EXPORT_JSON):
		var audit: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			HelpEncyclopediaPanel.ADMIN_ITEM_EXPORT_JSON))
		_check(audit is Dictionary, "item audit JSON is invalid")
		if audit is Dictionary:
			var flags: Dictionary = (audit as Dictionary).get("flags", {})
			_check(flags.has(item_id), "flagged item missing from audit pack")
			_check("current_data" in (flags.get(item_id, {}) as Dictionary),
				"audit pack omitted current source data")
	panel._show_admin_campaign()
	_check(panel.right.get_child_count() > 0,
		"Admin Control Center campaign page is empty")
	var mario_was_open := BridgeManager.is_repaired("mario")
	panel._show_admin_worlds()
	var mario_button := _button_starting_with(panel.right, "Mario")
	_check(mario_button != null, "Admin world controls omitted Mario")
	if mario_button != null:
		mario_button.pressed.emit()
		_check(BridgeManager.is_repaired("mario") != mario_was_open,
			"Admin Mario toggle changed the wrong captured world")
	panel._show_admin_booms()
	var boom_button := _button_starting_with(panel.right, "Kids' Adventure Day")
	_check(boom_button != null, "Admin Boom controls omitted authored Booms")
	if boom_button != null:
		boom_button.pressed.emit()
		_check(BoomManager.active_boom_id == "kids_adventure_day",
			"Admin Boom button activated the wrong captured Boom")
	print("ADMIN_SPRITE_REVIEW_EXPORT=", export_path)
	_finish(panel)


func _finish(panel: Node) -> void:
	panel.queue_free()
	if failures.is_empty():
		print("ADMIN_SPRITE_REVIEW_PROBE_PASS")
	else:
		for message in failures:
			printerr("ADMIN_SPRITE_REVIEW_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _has_entry(entries: Array[Dictionary], entry_id: String) -> bool:
	for entry: Dictionary in entries:
		if String(entry.get("id", "")) == entry_id:
			return true
	return false


func _button_starting_with(root: Node, prefix: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(prefix):
			return button
	return null
