extends Node
## Headless probe: walks controller-style focus through the NegotiationPanel
## and checks the MarketPanel keeps focus across a list rebuild.

const KEYS := {"ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_up": KEY_UP, "ui_down": KEY_DOWN}


func _ready() -> void:
	await get_tree().process_frame
	await _probe_negotiation()
	await _probe_market()
	await _probe_modal_gate()
	print("FOCUS_PROBE_DONE")
	get_tree().quit()


func _probe_modal_gate() -> void:
	print("MODAL open with none up: ", UIKit.modal_open())
	var parts := UIKit.modal(self, "probe")
	var parts2 := UIKit.modal(self, "probe2")
	print("MODAL open with two up: ", UIKit.modal_open())
	(parts2[0] as CanvasLayer).queue_free()
	await get_tree().process_frame
	print("MODAL open with one up: ", UIKit.modal_open())
	(parts[0] as CanvasLayer).queue_free()
	await get_tree().process_frame
	print("MODAL open after closing: ", UIKit.modal_open())


func _probe_negotiation() -> void:
	var catalog: Array = MarketManager.wholesale_catalog()
	var cust := {"id": "probe", "name": "Probe", "archetype": "adventurer",
		"budget": 500, "world": "kingdom_hearts", "color": "#c0c0c0"}
	var panel := NegotiationPanel.new()
	panel.setup(cust, String(catalog[0]))
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	UIKit._first_button_in(panel).grab_focus()
	await get_tree().process_frame
	print("NEGO START: ", _desc(get_viewport().gui_get_focus_owner()))
	for dir: String in ["ui_right", "ui_right", "ui_right", "ui_left",
			"ui_down", "ui_up", "ui_left"]:
		_press(dir)
		await get_tree().process_frame
		print("NEGO ", dir, " -> ", _desc(get_viewport().gui_get_focus_owner()))
	# with the counter-offer button showing, up from the row reaches it
	panel.accept_counter_btn.text = "Accept their 100g"
	panel.accept_counter_btn.visible = true
	await get_tree().process_frame
	_press("ui_up")
	await get_tree().process_frame
	print("NEGO ui_up(counter) -> ", _desc(get_viewport().gui_get_focus_owner()))
	panel.queue_free()
	await get_tree().process_frame


func _probe_market() -> void:
	var panel := MarketPanel.new()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: Array = panel._list.get_children()
	print("MARKET rows: ", rows.size())
	var target_row: int = mini(2, rows.size() - 1)
	UIKit._first_button_in(rows[target_row]).grab_focus()
	await get_tree().process_frame
	print("MARKET focus before rebuild: row ", target_row, " ", _desc(get_viewport().gui_get_focus_owner()))
	panel._fill()
	await get_tree().process_frame
	var focus := get_viewport().gui_get_focus_owner()
	var row_after := -1
	var fresh: Array = panel._list.get_children().filter(func(c: Node) -> bool:
		return not c.is_queued_for_deletion())
	for i in fresh.size():
		if focus != null and (fresh[i] == focus or fresh[i].is_ancestor_of(focus)):
			row_after = i
	print("MARKET focus after rebuild: row ", row_after, " ", _desc(focus))
	panel.queue_free()
	await get_tree().process_frame


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEYS[action]
		ev.physical_keycode = KEYS[action]
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _desc(c: Control) -> String:
	if c == null:
		return "<null>"
	var txt := ""
	if c is Button:
		txt = (c as Button).text
	elif c is LineEdit:
		txt = "LineEdit(%s)" % (c as LineEdit).text
	return "%s '%s'" % [c.get_class(), txt]
