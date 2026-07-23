extends Node
## Headless proof for the secret @ activation, all-content checklists, and the
## grouped Markdown/clipboard export used for sprite correction passes.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	GameState.admin_mode = false
	GameState.admin_review_flags.clear()
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
	var customers := panel._entries("Customers")
	_check(items.size() == ContentDatabase.live_items.size(),
		"admin item checklist does not reveal the full live catalog")
	_check(enemies.size() == ContentDatabase.enemies.size(),
		"admin enemy checklist is still filtered by campaign access")
	_check(not customers.is_empty(), "admin character checklist has no customer visuals")
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
