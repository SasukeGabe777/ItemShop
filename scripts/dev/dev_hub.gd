class_name LiveDevHub
extends CanvasLayer
## Scaled, code-built runtime workspace. The persistent left rail is intentionally
## narrow so the same layout remains usable at the 640x360 design viewport and
## larger desktop windows.

const TABS := ["Today", "World", "Location", "Spawn", "Shop", "Player", "Game State", "Playtest", "AI Partner", "Logs"]
const NOTE_TYPES := ["blocking bug", "gameplay issue", "visual issue", "usability issue", "polish", "idea"]

var root: Control
var workspace: PanelContainer
var nav_box: VBoxContainer
var content_box: VBoxContainer
var content_scroll: ScrollContainer
var content: VBoxContainer
var current_tab: String = "Today"
var running_button: Button
var placement_banner: PanelContainer
var placement_label: Label
var placement_valid_label: Label
var footer_label: Label
var _spawn_ids: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	root.visible = false
	placement_banner.visible = false


func _build_ui() -> void:
	root = Control.new()
	root.name = "WorkspaceRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.05, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)

	workspace = UIKit.panel()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(workspace)

	var horizontal := HBoxContainer.new()
	horizontal.add_theme_constant_override("separation", 8)
	workspace.add_child(horizontal)

	var nav_panel := UIKit.panel(Vector2(126, 0))
	nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal.add_child(nav_panel)
	nav_box = VBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 2)
	nav_panel.add_child(nav_box)
	var dev_label := UIKit.label("DEVELOPMENT\nMODE", 13, Color("#ffcf55"))
	dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_box.add_child(dev_label)
	nav_box.add_child(UIKit.hsep())
	for tab_name in TABS:
		var button := UIKit.button(tab_name, _show_tab.bind(tab_name), 9)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav_box.add_child(button)
	nav_box.add_child(UIKit.spacer())
	nav_box.add_child(UIKit.label("F1 close/open", 8, UIKit.COL_DIM))

	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal.add_child(content_box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	content_box.add_child(header)
	var title := UIKit.header("Crossroads Live Developer Hub")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	running_button = UIKit.button("Resume Game Behind Hub", _toggle_running, 9)
	header.add_child(running_button)
	header.add_child(UIKit.button("Close [F1]", DevHubManager.close_hub, 9))
	content_box.add_child(UIKit.hsep())

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(content_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	content_scroll.add_child(content)
	footer_label = UIKit.label("", 8, UIKit.COL_DIM)
	content_box.add_child(footer_label)

	placement_banner = UIKit.panel()
	placement_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	placement_banner.offset_left = 8
	placement_banner.offset_top = 8
	placement_banner.offset_right = -8
	placement_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(placement_banner)
	var placement_row := HBoxContainer.new()
	placement_banner.add_child(placement_row)
	placement_label = UIKit.label("", 10, UIKit.COL_ACCENT)
	placement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_row.add_child(placement_label)
	placement_valid_label = UIKit.label("", 9, UIKit.COL_GOOD)
	placement_row.add_child(placement_valid_label)


func open_hub(tab_name: String = "Today") -> void:
	current_tab = tab_name if tab_name in TABS else "Today"
	root.visible = true
	placement_banner.visible = false
	_refresh_running_button()
	_show_tab(current_tab)


func close_hub() -> void:
	root.visible = false
	placement_banner.visible = false


func set_world_pick_mode(active: bool, text: String) -> void:
	root.visible = not active
	placement_banner.visible = active
	placement_label.text = text
	placement_valid_label.text = ""


func set_placement_valid(valid: bool, at: Vector2) -> void:
	placement_valid_label.text = "%s @ %d, %d" % ["VALID" if valid else "INVALID", int(at.x), int(at.y)]
	placement_valid_label.add_theme_color_override("font_color", UIKit.COL_GOOD if valid else UIKit.COL_BAD)


func _toggle_running() -> void:
	DevHubManager.set_game_running_behind_hub(not DevHubManager.game_running_behind_hub)
	_refresh_running_button()


func _refresh_running_button() -> void:
	if running_button == null:
		return
	running_button.text = "Pause Game" if DevHubManager.game_running_behind_hub else "Resume Game Behind Hub"


func _show_tab(tab_name: String) -> void:
	current_tab = tab_name
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	footer_label.text = "%s | scene: %s | world: %s | normal saves untouched by Dev Hub actions" % [tab_name, DevHubManager.current_scene_name(), DevHubManager.selected_world]
	match tab_name:
		"Today": _build_today()
		"World": _build_world()
		"Location": _build_location()
		"Spawn": _build_spawn()
		"Shop": _build_shop()
		"Player": _build_player()
		"Game State": _build_game_state()
		"Playtest": _build_playtest()
		"AI Partner": _build_ai_partner()
		"Logs": _build_logs()


func _section(title: String, description: String = "") -> VBoxContainer:
	var panel := UIKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UIKit.header(title))
	if description != "":
		var label := UIKit.label(description, 9, UIKit.COL_DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	return box


func _action_row(parent: Container, actions: Array) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	parent.add_child(row)
	for action: Array in actions:
		row.add_child(UIKit.button(String(action[0]), action[1], 9))
	return row


func _status(text: String, color: Color = UIKit.COL_DIM) -> Label:
	var label := UIKit.label(text, 9, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label


func _build_today() -> void:
	var status := DevHubManager.status_data()
	var goal := _section("Current vertical-slice goal")
	var goal_label := UIKit.label(String(status.get("vertical_slice_goal", "No maintained development goal found.")), 10)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.add_child(goal_label)

	var overview := _section("Live state")
	overview.add_child(UIKit.label("Scene: %s" % DevHubManager.current_scene_name()))
	overview.add_child(UIKit.label("Location: %s" % (DevHubManager.current_location_id() if DevHubManager.current_location_id() != "" else "not identified")))
	overview.add_child(UIKit.label("World: %s" % DevHubManager.selected_world))
	overview.add_child(UIKit.label("Day %d — %s (chapter %d)" % [TimeManager.day, TimeManager.period_name(), TimeManager.chapter]))

	var systems := _section("Maintained build status", "Loaded from data/dev_status.json; update it when the claims change.")
	systems.add_child(UIKit.label("Working", 10, UIKit.COL_GOOD))
	for line in status.get("working_systems", []):
		systems.add_child(UIKit.label("• " + String(line), 9))
	systems.add_child(UIKit.label("Incomplete", 10, UIKit.COL_BAD))
	for line in status.get("incomplete_systems", []):
		systems.add_child(UIKit.label("• " + String(line), 9))
	systems.add_child(UIKit.label("Next three tasks", 10, UIKit.COL_ACCENT))
	var task_index := 1
	for line in (status.get("next_tasks", []) as Array).slice(0, 3):
		systems.add_child(UIKit.label("%d. %s" % [task_index, String(line)], 9))
		task_index += 1

	var launch := _section("Launch points", "These create or use in-memory development state. They do not write a normal save slot.")
	_action_row(launch, [
		["Play From Title", _launch_and_close.bind(DevHubManager.play_from_title)],
		["Play From Shop", _launch_and_close.bind(DevHubManager.play_from_shop)],
		["Play Kingdom Hearts Dungeon", _launch_and_close.bind(DevHubManager.play_kingdom_hearts_dungeon)],
		["Run Kingdom Hearts Full Loop", _launch_and_close.bind(DevHubManager.run_kingdom_hearts_full_loop)],
		["Restart Current Scene", _launch_and_close.bind(DevHubManager.restart_current_scene)],
	])


func _launch_and_close(action: Callable) -> void:
	DevHubManager.close_hub()
	action.call()


func _build_world() -> void:
	var intro := _section("Development world", "Selecting a world filters development tools; it does not permanently unlock campaign content.")
	for world_id in ContentDatabase.world_order:
		var world := ContentDatabase.get_world(world_id)
		var summary := DevHubManager.world_summary(world_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		intro.add_child(row)
		var selected := "▶ " if DevHubManager.selected_world == world_id else ""
		var label := UIKit.label("%s%s" % [selected, String(world.get("name", world_id))], 9, UIKit.COL_ACCENT if selected != "" else UIKit.COL_TEXT)
		label.custom_minimum_size.x = 115
		row.add_child(label)
		var counts := UIKit.label("H %d | I %d | E %d | C %d | L %d | missing %d | incomplete %d" % [summary.heroes, summary.items, summary.enemies, summary.customers, summary.locations, summary.missing_assets, summary.incomplete], 8, UIKit.COL_DIM)
		counts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(counts)
		row.add_child(UIKit.button("Select", func() -> void:
			DevHubManager.select_development_world(world_id)
			_show_tab("World"), 8))


func _build_location() -> void:
	var locations := DevHubManager.all_locations()
	var select_box := _section("Locations", "Normal data locations and separate development locations are listed together.")
	var option := OptionButton.new()
	var ids: Array[String] = []
	for key in locations.keys(): ids.append(String(key))
	ids.sort()
	for id in ids:
		option.add_item(id)
		if id == DevHubManager.selected_location: option.select(option.item_count - 1)
	select_box.add_child(option)
	var details := UIKit.label("", 9)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	select_box.add_child(details)
	var refresh_details := func() -> void:
		if option.selected < 0 or ids.is_empty():
			details.text = "No locations exist yet. Create a blank development location."
			return
		var id := ids[option.selected]
		DevHubManager.select_location(id)
		var row := DevHubManager.location_summary(id)
		details.text = "ID: %s\nName: %s\nWorld/type: %s / %s\nDimensions: %s\nEntrances/exits: %d / %d\nSpawn markers: %s\nInteractables: %d\nValidation: %s" % [row.id, row.name, row.world, row.type, row.dimensions, row.entrances, row.exits, JSON.stringify(row.spawn_markers), row.interactables, "none" if (row.problems as Array).is_empty() else "; ".join(row.problems)]
	option.item_selected.connect(func(_idx: int) -> void: refresh_details.call())
	refresh_details.call()

	var create_row := HBoxContainer.new()
	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "new_location_id"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_child(id_edit)
	create_row.add_child(UIKit.button("Create Blank Development Location", func() -> void:
		DevHubManager.create_blank_location(id_edit.text)
		_show_tab("Location"), 9))
	select_box.add_child(create_row)

	var actions := _section("Location actions", "Version 1 places gameplay objects; use the Asset Factory for tileset preparation and tile painting.")
	_action_row(actions, [
		["Load Selected Location", _launch_location],
		["Restart Selected Location", _launch_location],
		["Enter Location Edit Mode", func() -> void: DevHubManager.location_edit_mode = not DevHubManager.location_edit_mode; _show_tab("Location")],
		["Save Location Layout", func() -> void: DevHubManager.save_current_location_layout(); _show_tab("Location")],
		["Reload Location Layout", func() -> void: DevHubManager.reload_current_location_layout(); DevHubManager.close_hub()],
		["Open/Create Location Brief", _create_brief],
		["Play This Location", _launch_location],
	])
	actions.add_child(UIKit.label("Edit mode: %s" % ("ON" if DevHubManager.location_edit_mode else "off"), 9, UIKit.COL_GOOD if DevHubManager.location_edit_mode else UIKit.COL_DIM))


func _launch_location() -> void:
	if DevHubManager.launch_selected_location():
		DevHubManager.close_hub()


func _create_brief() -> void:
	var path := DevHubManager.create_or_open_location_brief()
	if path != "":
		DisplayServer.clipboard_set(path)
		_status("Brief path copied: " + path, UIKit.COL_GOOD)


func _build_spawn() -> void:
	var picker := _section("Search and place content", "Select a type and content ID, then click Place. The hub hides while you preview and confirm in the world.")
	var controls := HBoxContainer.new()
	picker.add_child(controls)
	var type_option := OptionButton.new()
	var types := ["item", "customer", "hero", "enemy", "furniture", "chest", "npc", "door", "trigger"]
	for type in types: type_option.add_item(type)
	controls.add_child(type_option)
	var search := LineEdit.new()
	search.placeholder_text = "search content IDs or names"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(search)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 105)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_child(list)
	var refill := func() -> void:
		var type := type_option.get_item_text(type_option.selected)
		_spawn_ids = _content_ids_for_type(type)
		list.clear()
		var query := search.text.strip_edges().to_lower()
		var visible_ids: Array[String] = []
		for id in _spawn_ids:
			var display := _content_display_name(type, id)
			if query == "" or id.to_lower().contains(query) or display.to_lower().contains(query):
				list.add_item("%s — %s" % [id, display])
				visible_ids.append(id)
		list.set_meta("visible_ids", visible_ids)
	type_option.item_selected.connect(func(_idx: int) -> void: refill.call())
	search.text_changed.connect(func(_text: String) -> void: refill.call())
	refill.call()
	_action_row(picker, [
		["Place Selected", func() -> void:
			var selected := list.get_selected_items()
			if selected.is_empty(): return
			var visible_ids: Array = list.get_meta("visible_ids", [])
			DevHubManager.begin_placement(type_option.get_item_text(type_option.selected), String(visible_ids[selected[0]]))],
		["Select Object In World", DevHubManager.begin_select_object],
		["Cancel Placement", DevHubManager.cancel_world_action],
	])
	_build_inspector()


func _content_ids_for_type(type: String) -> Array[String]:
	match type:
		"item": return DevHubManager._sorted_keys(ContentDatabase.items)
		"customer": return DevHubManager._sorted_keys(ContentDatabase.named_customers)
		"hero": return DevHubManager._sorted_keys(ContentDatabase.heroes)
		"enemy":
			var all := ContentDatabase.enemies.duplicate()
			all.merge(ContentDatabase.bosses)
			return DevHubManager._sorted_keys(all)
		"furniture": return DevHubManager._sorted_keys(ContentDatabase.furniture)
		"npc": return DevHubManager._sorted_keys(ContentDatabase.npcs)
		"chest": return ["standard_chest"]
		"door": return ["door_exit"]
		"trigger": return ["story_trigger", "combat_trigger", "interaction_trigger"]
	return []


func _content_display_name(type: String, id: String) -> String:
	match type:
		"item": return String(ContentDatabase.get_item(id).get("name", id))
		"customer": return String(ContentDatabase.get_named_customer(id).get("name", id))
		"hero": return String(ContentDatabase.get_hero(id).get("name", id))
		"enemy": return String(ContentDatabase.get_enemy(id).get("name", id))
		"furniture": return String(ContentDatabase.get_furniture(id).get("name", id))
		"npc": return String((ContentDatabase.npcs.get(id, {}) as Dictionary).get("name", id))
	return id.replace("_", " ").capitalize()


func _build_inspector() -> void:
	var box := _section("Runtime Object Inspector", "Only useful game-development fields are exposed.")
	var summary := DevHubManager.selected_object_summary()
	if summary.is_empty():
		box.add_child(UIKit.label("No editable runtime object selected.", 9, UIKit.COL_DIM))
		return
	var props := JSON.stringify(summary.properties)
	if props.length() > 450: props = props.left(450) + "…"
	var label := UIKit.label("Instance: %s\nContent: %s\nType: %s\nPosition: %s\nRotation: %.2f\nCollision: %s\nProperties: %s" % [summary.instance_id, summary.content_id, summary.object_type, summary.position, summary.rotation, summary.collision, props], 9)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var position_row := HBoxContainer.new()
	box.add_child(position_row)
	var x := SpinBox.new(); x.min_value = -10000; x.max_value = 10000; x.value = float(summary.position[0]); x.prefix = "X "
	var y := SpinBox.new(); y.min_value = -10000; y.max_value = 10000; y.value = float(summary.position[1]); y.prefix = "Y "
	var rotation := SpinBox.new(); rotation.min_value = -360; rotation.max_value = 360; rotation.value = rad_to_deg(float(summary.rotation)); rotation.prefix = "Rot "
	position_row.add_child(x); position_row.add_child(y); position_row.add_child(rotation)
	position_row.add_child(UIKit.button("Apply", func() -> void:
		DevHubManager.set_selected_position(Vector2(x.value, y.value))
		DevHubManager.set_selected_rotation(deg_to_rad(rotation.value))
		_show_tab("Spawn"), 8))
	var collision := CheckBox.new()
	collision.text = "Collision enabled"
	collision.button_pressed = bool(summary.collision)
	collision.toggled.connect(DevHubManager.set_selected_collision)
	box.add_child(collision)
	var supported_property: String = String({"door": "target_location", "trigger": "event_id", "chest": "reward_item_id", "npc": "dialogue_id"}.get(String(summary.object_type), ""))
	if supported_property != "":
		var property_row := HBoxContainer.new()
		var property_value := LineEdit.new()
		property_value.placeholder_text = String(supported_property)
		property_value.text = String((summary.properties as Dictionary).get(supported_property, ""))
		property_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		property_row.add_child(property_value)
		property_row.add_child(UIKit.button("Set %s" % String(supported_property).replace("_", " ").capitalize(), func() -> void:
			DevHubManager.set_selected_game_property(supported_property, property_value.text)
			_show_tab("Spawn"), 8))
		box.add_child(property_row)
	_action_row(box, [
		["Move", DevHubManager.begin_move_selected], ["Delete", func() -> void: DevHubManager.delete_selected_object(); _show_tab("Spawn")],
		["Duplicate", DevHubManager.duplicate_selected_object], ["Focus Camera", DevHubManager.focus_camera_on_selected],
		["Copy Content ID", DevHubManager.copy_selected_content_id], ["Open Source / Asset Factory Data", DevHubManager.open_selected_source],
	])


func _build_shop() -> void:
	var shop := DevHubManager._shop_runtime()
	if shop == null:
		var not_here := _section("Shop runtime not active", "Load the real shop scene to use save-compatible furniture, slots, customers, and sessions.")
		not_here.add_child(UIKit.button("Play From Shop", _launch_and_close.bind(DevHubManager.play_from_shop)))
		return
	var status := _section("Shop controls")
	status.add_child(UIKit.label("Session: %s | furniture: %d | display slots: %d | reachable: %d" % ["open" if shop.session_active else "closed", shop.furniture_nodes.size(), InventoryManager.display.size(), ShopFurnitureManager.get_reachable_display_slots().size()]))
	_action_row(status, [
		["Toggle Shop Edit Mode", shop.dev_toggle_edit_mode], ["Clear Displays", DevHubManager.clear_displays],
		["Fill Inventory With Test Items", DevHubManager.fill_inventory_for_selected_world],
		["Open Shop", shop.dev_open_shop], ["Close Shop", shop.dev_close_shop],
		["Save Layout (Dev State)", DevHubManager.save_dev_state], ["Reload Layout", func() -> void: DevHubManager.load_dev_state(); shop.dev_rebuild_furniture(); _show_tab("Shop")],
	])
	var boom_tools := _section("Boom testing", "Force a data-defined Boom, then stock displays and open the real shop session. State uses the normal Boom save path.")
	boom_tools.add_child(UIKit.label("Active: %s" % ("%s - %d session(s) left" % [BoomManager.display_name(), BoomManager.sessions_left]
		if BoomManager.is_active() else "none"), 9, UIKit.COL_ACCENT if BoomManager.is_active() else UIKit.COL_DIM))
	var boom_option := OptionButton.new()
	var boom_ids := DevHubManager._sorted_keys(ContentDatabase.booms)
	for id in boom_ids:
		boom_option.add_item("%s - %s" % [id, ContentDatabase.booms[id].get("name", id)])
	boom_tools.add_child(boom_option)
	_action_row(boom_tools, [
		["Force Selected Boom", func() -> void:
			if boom_option.selected >= 0:
				var world := DevHubManager.selected_world if String(ContentDatabase.booms[boom_ids[boom_option.selected]].get("dynamic_world", "")) != "" \
					or bool(ContentDatabase.booms[boom_ids[boom_option.selected]].get("trigger_only", false)) else ""
				BoomManager.force_boom(boom_ids[boom_option.selected], world)
				_show_tab("Shop")],
		["Clear Boom", func() -> void: BoomManager.clear_active(); _show_tab("Shop")],
	])

	var furniture := _section("Furniture placement", "Positions and display items use ShopFurnitureManager and InventoryManager's existing save-compatible format.")
	var furniture_option := OptionButton.new()
	var furniture_ids := DevHubManager._sorted_keys(ContentDatabase.furniture)
	for id in furniture_ids: furniture_option.add_item("%s — %s" % [id, ContentDatabase.get_furniture(id).get("name", id)])
	furniture.add_child(furniture_option)
	_action_row(furniture, [
		["Place Furniture", func() -> void:
			if furniture_option.selected >= 0: DevHubManager.begin_placement("furniture", furniture_ids[furniture_option.selected])],
		["Select Furniture To Move", DevHubManager.begin_select_object],
		["Remove Selected Furniture", func() -> void: DevHubManager.delete_selected_object(); _show_tab("Shop")],
	])

	var displays := _section("Display slots and customer pathing")
	var slot_option := OptionButton.new()
	for slot in range(InventoryManager.display.size()): slot_option.add_item("Slot %d — %s" % [slot + 1, String(InventoryManager.display[slot])])
	var item_option := OptionButton.new()
	var item_ids := DevHubManager._sorted_keys(ContentDatabase.items)
	for id in item_ids: item_option.add_item(id)
	var slot_row := HBoxContainer.new(); slot_row.add_child(slot_option); slot_row.add_child(item_option)
	slot_row.add_child(UIKit.button("Assign Item", func() -> void:
		if slot_option.selected >= 0 and item_option.selected >= 0:
			shop.dev_set_display_item(slot_option.selected, item_ids[item_option.selected]); _show_tab("Shop"), 8))
	displays.add_child(slot_row)
	var reachable_lines: Array[String] = []
	for row: Dictionary in ShopFurnitureManager.get_reachable_display_slots():
		reachable_lines.append("#%d %s @ %s item=%s" % [int(row.index) + 1, String(row.type), row.position, String(row.item_id)])
	var reachable := UIKit.label("Reachable display targets:\n" + "\n".join(reachable_lines), 8, UIKit.COL_DIM)
	reachable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	displays.add_child(reachable)

	var customers := _section("Summon customer")
	var customer_option := OptionButton.new()
	var customer_ids := DevHubManager._sorted_keys(ContentDatabase.named_customers)
	for id in customer_ids: customer_option.add_item("%s — %s" % [id, ContentDatabase.get_named_customer(id).get("name", id)])
	customers.add_child(customer_option)
	customers.add_child(UIKit.button("Summon Selected Customer", func() -> void:
		if customer_option.selected >= 0: shop.dev_summon_customer(customer_ids[customer_option.selected])))


func _build_player() -> void:
	var player := DevHubManager.current_player()
	var box := _section("Player runtime", "Uses the active TownPlayer or CombatHero and existing equipment systems.")
	if player == null:
		box.add_child(UIKit.label("No supported player is active in the current scene.", 9, UIKit.COL_BAD))
		return
	box.add_child(UIKit.label("Active node: %s | content: %s" % [player.name, String(player.get_meta("dev_content_id", "hero"))]))
	var hero_option := OptionButton.new()
	var hero_ids := DevHubManager._sorted_keys(ContentDatabase.heroes)
	for id in hero_ids: hero_option.add_item(id)
	box.add_child(hero_option)
	_action_row(box, [["Select Active Hero (Dungeon)", func() -> void: DevHubManager.select_active_hero(hero_ids[hero_option.selected]); _show_tab("Player")], ["Heal", DevHubManager.heal_player], ["Revive", DevHubManager.revive_player], ["Reset Player State", DevHubManager.reset_player_state]])
	var speed := HSlider.new(); speed.min_value = 0.25; speed.max_value = 3.0; speed.step = 0.25; speed.value = 1.0
	speed.value_changed.connect(DevHubManager.set_player_speed)
	box.add_child(UIKit.label("Movement speed multiplier")); box.add_child(speed)
	var collision := CheckBox.new(); collision.text = "Collision enabled"; collision.button_pressed = true; collision.toggled.connect(DevHubManager.set_player_collision); box.add_child(collision)
	_action_row(box, [["Teleport To Cursor", func() -> void: DevHubManager.begin_placement("player_teleport", "player")], ["Teleport To Player Spawn", func() -> void: DevHubManager.teleport_player_to_marker("player_spawn")]])

	var equipment := _section("Equipment")
	var item_option := OptionButton.new()
	var equipment_ids: Array[String] = []
	for id: String in ContentDatabase.items:
		if String(ContentDatabase.get_item(id).get("category", "")) in ["weapon", "armor", "accessory"]:
			equipment_ids.append(id)
	equipment_ids.sort()
	for id in equipment_ids: item_option.add_item(id)
	equipment.add_child(item_option)
	_action_row(equipment, [["Grant Selected Equipment", func() -> void:
		var hero_id := hero_ids[hero_option.selected]
		if item_option.selected >= 0: DevHubManager.grant_equipment(hero_id, equipment_ids[item_option.selected])], ["Clear Hero Equipment", func() -> void: DevHubManager.clear_equipment(hero_ids[hero_option.selected])]])


func _build_game_state() -> void:
	var money := _section("Money and inventory", "Changes affect only current in-memory state until explicitly saved. Dev Save uses user://crossroads_dev, not normal slots.")
	var money_spin := SpinBox.new(); money_spin.min_value = -9999999; money_spin.max_value = 9999999; money_spin.value = 1000; money.add_child(money_spin)
	_action_row(money, [["Apply Money Delta", func() -> void: DevHubManager.change_money(int(money_spin.value)); _show_tab("Game State")]])
	money.add_child(UIKit.label("Current gold: %d" % EconomyManager.gold, 10, UIKit.COL_ACCENT))
	var item_option := OptionButton.new(); var item_ids := DevHubManager._sorted_keys(ContentDatabase.items); for id in item_ids: item_option.add_item(id)
	var qty := SpinBox.new(); qty.min_value = -999; qty.max_value = 999; qty.value = 1
	var item_row := HBoxContainer.new(); item_row.add_child(item_option); item_row.add_child(qty); item_row.add_child(UIKit.button("Apply Item Delta", func() -> void: DevHubManager.change_inventory(item_ids[item_option.selected], int(qty.value)); _show_tab("Game State"), 8)); money.add_child(item_row)

	var time := _section("Campaign development state")
	var day := SpinBox.new(); day.min_value = 1; day.max_value = TimeManager.campaign_days(); day.value = TimeManager.day
	var period := OptionButton.new(); for name in ContentDatabase.bal("period_names", ["Morning", "Afternoon", "Evening", "Night"]): period.add_item(String(name)); period.select(TimeManager.period)
	var time_row := HBoxContainer.new(); time_row.add_child(day); time_row.add_child(period); time_row.add_child(UIKit.button("Set Day / Period", func() -> void: DevHubManager.set_day_and_period(int(day.value), period.selected); _show_tab("Game State"), 8)); time.add_child(time_row)
	var world_option := OptionButton.new(); for id in ContentDatabase.world_order: world_option.add_item(id)
	time.add_child(world_option)
	_action_row(time, [["Toggle Temporary World Unlock", func() -> void:
		var id := world_option.get_item_text(world_option.selected); DevHubManager.set_world_temporarily_unlocked(id, not DevHubManager.is_world_temporarily_unlocked(id)); _show_tab("Game State")], ["Complete Bridge Repair (Dev)", func() -> void: DevHubManager.complete_bridge_development(world_option.get_item_text(world_option.selected)); _show_tab("Game State")], ["Reset Current Chapter", func() -> void: DevHubManager.reset_current_chapter(); _show_tab("Game State")]])
	var relation_id := LineEdit.new(); relation_id.placeholder_text = "customer or hero ID"
	var relation_level := SpinBox.new(); relation_level.min_value = 0; relation_level.max_value = 10
	var relation_row := HBoxContainer.new(); relation_row.add_child(relation_id); relation_row.add_child(relation_level); relation_row.add_child(UIKit.button("Set Relationship Level", func() -> void: DevHubManager.set_relationship_level(relation_id.text, int(relation_level.value)), 8)); time.add_child(relation_row)

	var persistence := _section("Separate development state")
	_action_row(persistence, [["Save Dev State", DevHubManager.save_dev_state], ["Load Dev State", func() -> void: DevHubManager.load_dev_state(); _show_tab("Game State")]])
	persistence.add_child(UIKit.label("Normal user save slots are only touched by the normal SaveManager UI or debug console, never by these buttons.", 9, UIKit.COL_GOOD))


func _build_playtest() -> void:
	var session := _section("In-game playtest session", "Reports are generated under playtest/latest/ in the project workspace.")
	session.add_child(UIKit.label("Session: %s" % ("ACTIVE since " + DevHubManager.playtest_started_at if DevHubManager.playtest_active else "not active"), 10, UIKit.COL_GOOD if DevHubManager.playtest_active else UIKit.COL_DIM))
	_action_row(session, [["Start Playtest Session", func() -> void: DevHubManager.start_playtest_session(); _show_tab("Playtest")], ["Capture Current State", DevHubManager.capture_playtest_state], ["End Playtest Session", func() -> void: DevHubManager.end_playtest_session(); _show_tab("Playtest")]])
	var note_type := OptionButton.new(); for type in NOTE_TYPES: note_type.add_item(type)
	var note := TextEdit.new(); note.custom_minimum_size = Vector2(0, 80); note.placeholder_text = "What happened? Include expected and actual behavior for bugs."
	session.add_child(note_type); session.add_child(note)
	session.add_child(UIKit.button("Add Note", func() -> void:
		if DevHubManager.add_playtest_note(note_type.get_item_text(note_type.selected), note.text): note.clear(); _show_tab("Playtest")))


func _build_ai_partner() -> void:
	var box := _section("AI context export", "No external API is called. This writes a compact, reviewable package under ai_workspace/current/.")
	var request := TextEdit.new(); request.custom_minimum_size = Vector2(0, 100); request.placeholder_text = "Human request for the next Claude/Codex session"; request.text = DevHubManager.dev_request
	box.add_child(request)
	_action_row(box, [["EXPORT CURRENT CONTEXT FOR AI", func() -> void: DevHubManager.export_ai_context(request.text); _show_tab("AI Partner")], ["Copy Claude Prompt", func() -> void: DevHubManager.copy_claude_prompt(); _show_tab("AI Partner")]])
	box.add_child(UIKit.label("Exports project context, current state, selected location/object, available content, validation, playtest notes, and REQUEST.md.", 9, UIKit.COL_DIM))


func _build_logs() -> void:
	var controls := _section("Runtime and validation logs", "Clearing this view does not delete Godot/source log files.")
	_action_row(controls, [["Refresh", func() -> void: _show_tab("Logs")], ["Run Content Validation", func() -> void: DevHubManager.last_validation = DevHubManager.run_content_validation(); _show_tab("Logs")], ["Clear Visible Log", func() -> void: DevHubManager.clear_visible_log(); _show_tab("Logs")]])
	var validation_counts := {"ERROR": 0, "WARNING": 0, "INFO": 0}
	for row: Dictionary in DevHubManager.last_validation:
		var severity := String(row.get("severity", "INFO")); validation_counts[severity] = int(validation_counts.get(severity, 0)) + 1
	controls.add_child(UIKit.label("Validation: %d errors, %d warnings, %d info" % [validation_counts.ERROR, validation_counts.WARNING, validation_counts.INFO], 9, UIKit.COL_BAD if validation_counts.ERROR > 0 else UIKit.COL_GOOD))
	var output := RichTextLabel.new(); output.bbcode_enabled = false; output.fit_content = true; output.custom_minimum_size = Vector2(0, 240)
	output.text = "\n".join(DevHubManager.combined_recent_logs(180))
	controls.add_child(output)
	if not DevHubManager.last_validation.is_empty():
		var issues := UIKit.label("Recent content validation issues:\n" + _validation_text(DevHubManager.last_validation, 30), 8, UIKit.COL_DIM)
		issues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls.add_child(issues)


func _validation_text(rows: Array[Dictionary], limit: int) -> String:
	var lines: Array[String] = []
	for row in rows.slice(0, limit):
		lines.append("[%s] %s/%s: %s" % [String(row.get("severity", "")), String(row.get("type", "")), String(row.get("id", "")), String(row.get("message", ""))])
	return "\n".join(lines)
