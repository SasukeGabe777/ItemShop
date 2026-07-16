@tool
extends VBoxContainer
## Guided Location Workshop. It wraps the existing tile/marker editor with
## human-readable briefs, deterministic proposal templates, direct play, and
## review artifacts that an AI partner can consume without Godot scene knowledge.

signal data_written

const LocationEditorTab := preload("res://addons/crossroads_content_studio/ui/locations_tab.gd")
const LOCATION_TYPES := ["shop", "town", "dungeon_room", "story_scene"]

var scan: CCSContentScan
var brief_root: String = CCSAssetPaths.DATA_LOCATION_BRIEFS
var locations_data_path: String = CCSAssetPaths.DATA_LOCATIONS

var editor
var _steps: TabContainer
var _world_option: OptionButton
var _location_option: OptionButton
var _availability: TextEdit
var _world_status: Label
var _brief_status: Label
var _proposal_view: TextEdit
var _proposal_status: Label
var _review_status: Label
var _brief_controls: Dictionary = {}
var _review_controls: Dictionary = {}
var _world_ids: Array[String] = []
var _location_ids: Array[String] = []
var _loaded_brief: Dictionary = {}


func setup(p_scan: CCSContentScan) -> void:
	scan = p_scan
	if _steps == null:
		_build_ui()
	editor.locations_data_path = locations_data_path
	editor.setup(scan)
	_refresh_worlds()
	_refresh_locations()
	_refresh_availability()


func _ready() -> void:
	if _steps == null:
		_build_ui()


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Location Workshop - brief, propose, build, play, review"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	_steps = TabContainer.new()
	_steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_steps)
	_build_world_step()
	_build_brief_step()
	_build_proposal_step()
	_build_map_step()
	_build_review_step()


func _scroll_step(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_steps.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	return body


func _build_world_step() -> void:
	var body := _scroll_step("1 World")
	body.add_child(_heading("STEP 1 - Select world", "Choose the content family first. The Workshop only lists assets that already exist."))
	var row := HBoxContainer.new()
	row.add_child(_label("World:"))
	_world_option = OptionButton.new()
	_world_option.custom_minimum_size.x = 220
	_world_option.item_selected.connect(func(_idx: int) -> void:
		_refresh_locations()
		_refresh_availability())
	row.add_child(_world_option)
	row.add_child(_label("Existing location:"))
	_location_option = OptionButton.new()
	_location_option.custom_minimum_size.x = 240
	_location_option.item_selected.connect(_on_existing_location_selected)
	row.add_child(_location_option)
	body.add_child(row)
	_availability = TextEdit.new()
	_availability.editable = false
	_availability.custom_minimum_size = Vector2(720, 360)
	_availability.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(_availability)
	_world_status = _status_label("Select a world to inspect its current content.")
	body.add_child(_world_status)


func _build_brief_step() -> void:
	var body := _scroll_step("2 Brief")
	body.add_child(_heading("STEP 2 - Create location brief", "Describe the intended player experience before painting. Save writes readable JSON under data/location_briefs/."))
	_add_line_field(body, "location_name", "Location name")
	_add_line_field(body, "id", "Stable location ID")
	_add_text_field(body, "purpose", "Purpose")
	var type_row := HBoxContainer.new()
	type_row.add_child(_label("Location type"))
	var type_option := OptionButton.new()
	for value in LOCATION_TYPES:
		type_option.add_item(value)
	type_row.add_child(type_option)
	_brief_controls["location_type"] = type_option
	body.add_child(type_row)
	_add_text_field(body, "player_experience", "Player experience")
	_add_text_field(body, "visual_theme", "Visual theme")
	var dimensions := HBoxContainer.new()
	dimensions.add_child(_label("Width / height"))
	var width := _spin(4, 64, 20)
	var height := _spin(4, 64, 12)
	dimensions.add_child(width)
	dimensions.add_child(height)
	_brief_controls["width"] = width
	_brief_controls["height"] = height
	body.add_child(dimensions)
	for spec in [
		["entry_points", "Entry points"], ["exit_points", "Exit points"],
		["enemy_plan", "Enemy plan"], ["reward_plan", "Reward plan"],
		["interactables", "Interactables"], ["story_events", "Story events"],
		["design_notes", "Design notes"],
	]:
		_add_text_field(body, String(spec[0]), String(spec[1]))
	var actions := HBoxContainer.new()
	actions.add_child(_button("Save Location Brief", save_brief))
	actions.add_child(_button("Load Saved Brief", func() -> void: load_brief(_brief_id())))
	actions.add_child(_button("Apply Brief to Map", _sync_editor_from_brief))
	body.add_child(actions)
	_brief_status = _status_label("No brief saved yet.")
	body.add_child(_brief_status)


func _build_proposal_step() -> void:
	var body := _scroll_step("3 Proposal")
	body.add_child(_heading("STEP 3 - Generate proposal", "This creates a structured design handoff. It does not paint tiles or call an online AI."))
	body.add_child(_button("Generate Layout Proposal", generate_layout_proposal))
	_proposal_view = TextEdit.new()
	_proposal_view.editable = false
	_proposal_view.custom_minimum_size = Vector2(720, 440)
	_proposal_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(_proposal_view)
	_proposal_status = _status_label("Save a brief, then generate its proposal.")
	body.add_child(_proposal_status)


func _build_map_step() -> void:
	var body := VBoxContainer.new()
	body.name = "4 Build Map"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_steps.add_child(body)
	body.add_child(_heading("STEP 4 - Build map / STEP 5 - Play", "Use the existing painter. PLAY THIS LOCATION saves first and launches an isolated debug runtime."))
	editor = LocationEditorTab.new()
	editor.locations_data_path = locations_data_path
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.data_written.connect(func() -> void: data_written.emit())
	body.add_child(editor)


func _build_review_step() -> void:
	var body := _scroll_step("5 Review")
	body.add_child(_heading("STEP 6 - Review", "Record the human play result beside the brief so the next AI revision starts from evidence."))
	for spec in [
		["navigation_readable", "Navigation readable?"],
		["collisions_correct", "Collisions correct?"],
		["objective_clear", "Objective clear?"],
		["enemies_appropriate", "Enemies appropriate?"],
		["rewards_worthwhile", "Rewards worthwhile?"],
	]:
		var row := HBoxContainer.new()
		row.add_child(_label(String(spec[1])))
		var option := OptionButton.new()
		for value in ["untested", "yes", "no"]:
			option.add_item(value)
		row.add_child(option)
		_review_controls[String(spec[0])] = option
		body.add_child(row)
	for spec in [["visual_problems", "Visual problems"], ["missing_assets", "Missing assets"], ["notes", "Revision notes"]]:
		var edit := _text_edit()
		_review_controls[String(spec[0])] = edit
		body.add_child(_label(String(spec[1])))
		body.add_child(edit)
	var decision_row := HBoxContainer.new()
	decision_row.add_child(_label("Decision"))
	var decision := OptionButton.new()
	decision.add_item("revise")
	decision.add_item("approved")
	decision_row.add_child(decision)
	_review_controls["decision"] = decision
	body.add_child(decision_row)
	body.add_child(_button("Save Location Review", save_review))
	_review_status = _status_label("No review saved yet.")
	body.add_child(_review_status)


func _heading(title: String, description: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 14)
	box.add_child(heading)
	var detail := Label.new()
	detail.text = description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate = Color(0.75, 0.78, 0.84)
	box.add_child(detail)
	return box


func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label


func _status_label(value: String) -> Label:
	var label := _label(value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _spin(minimum: int, maximum: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.value = value
	return spin


func _text_edit() -> TextEdit:
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(620, 64)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	return edit


func _add_line_field(parent: VBoxContainer, key: String, title: String) -> void:
	parent.add_child(_label(title))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brief_controls[key] = edit
	parent.add_child(edit)


func _add_text_field(parent: VBoxContainer, key: String, title: String) -> void:
	parent.add_child(_label(title))
	var edit := _text_edit()
	_brief_controls[key] = edit
	parent.add_child(edit)


func _selected_world() -> String:
	if _world_option == null or _world_option.selected < 0 or _world_ids.is_empty():
		return "crossroads"
	return _world_ids[_world_option.selected]


func _refresh_worlds() -> void:
	var previous := _selected_world()
	_world_ids = CCSAssetPaths.known_world_ids(scan.world_order if scan != null else [])
	_world_option.clear()
	for id in _world_ids:
		_world_option.add_item(id)
	var target := _world_ids.find(previous)
	if target < 0 and scan != null and not scan.world_order.is_empty():
		target = _world_ids.find(scan.world_order[0])
	if target >= 0:
		_world_option.select(target)


func _refresh_locations() -> void:
	if _location_option == null:
		return
	var previous := _brief_id()
	_location_ids.clear()
	_location_option.clear()
	_location_option.add_item("<new location>")
	if scan == null:
		return
	for loc: Dictionary in scan.locations_raw:
		if String(loc.get("world", "")) == _selected_world():
			_location_ids.append(String(loc.get("id", "")))
	_location_ids.sort()
	for id in _location_ids:
		_location_option.add_item(id)
	var idx := _location_ids.find(previous)
	if idx >= 0:
		_location_option.select(idx + 1)


func _refresh_availability() -> void:
	if _availability == null or scan == null:
		return
	var world := _selected_world()
	var lines: Array[String] = []
	lines.append("AVAILABLE TILESETS")
	lines.append_array(_display_lines(_tilesets_for_world(world)))
	lines.append("\nAVAILABLE ENEMIES")
	lines.append_array(_display_lines(_ids_for_world(scan.enemies, world) + _ids_for_world(scan.bosses, world)))
	lines.append("\nAVAILABLE ITEMS / REWARDS")
	lines.append_array(_display_lines(_ids_for_world(scan.items, world)))
	lines.append("\nAVAILABLE NPCS")
	lines.append_array(_display_lines(_ids_for_world(scan.npcs, world) + _ids_for_world(scan.named_customers, world)))
	lines.append("\nEXISTING CONNECTED LOCATIONS")
	var connected: Array[String] = []
	for loc: Dictionary in scan.locations_raw:
		if String(loc.get("world", "")) == world:
			var targets: Array[String] = []
			for marker: Dictionary in loc.get("markers", []):
				if String(marker.get("target", "")) != "":
					targets.append(String(marker["target"]))
			connected.append("%s%s" % [String(loc.get("id", "?")), " -> " + ", ".join(targets) if not targets.is_empty() else ""])
	lines.append_array(_display_lines(connected))
	_availability.text = "\n".join(lines)
	_world_status.text = "World '%s': %d tilesets, %d enemies/bosses, %d rewards, %d NPCs/customers, %d authored locations." % [
		world, _tilesets_for_world(world).size(), _ids_for_world(scan.enemies, world).size() + _ids_for_world(scan.bosses, world).size(),
		_ids_for_world(scan.items, world).size(), _ids_for_world(scan.npcs, world).size() + _ids_for_world(scan.named_customers, world).size(), connected.size()]


func _display_lines(values: Array[String]) -> Array[String]:
	return ["- (none found)"] if values.is_empty() else values.map(func(value: String) -> String: return "- " + value)


func _ids_for_world(table: Dictionary, world: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in table:
		if String((table[id] as Dictionary).get("world", "")) == world:
			out.append(id)
	out.sort()
	return out


func _tilesets_for_world(world: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(CCSAssetPaths.tileset_dir(world))
	if dir == null:
		return out
	for name in dir.get_files():
		if name.ends_with(".json") and not name.ends_with(".meta.json"):
			out.append(CCSAssetPaths.tileset_dir(world).path_join(name))
	out.sort()
	return out


func _brief_id() -> String:
	if not _brief_controls.has("id"):
		return ""
	var raw := (_brief_controls["id"] as LineEdit).text.strip_edges()
	return CCSFactoryIO.sanitize_id(raw) if raw != "" else ""


func brief_path(location_id: String) -> String:
	return brief_root.path_join(CCSFactoryIO.sanitize_id(location_id) + ".json")


func proposal_path(location_id: String) -> String:
	return brief_root.path_join(CCSFactoryIO.sanitize_id(location_id) + ".proposal.json")


func review_path(location_id: String) -> String:
	return brief_root.path_join(CCSFactoryIO.sanitize_id(location_id) + ".review.json")


func set_brief_data(brief: Dictionary) -> void:
	_loaded_brief = brief.duplicate(true)
	for key in _brief_controls:
		var control: Control = _brief_controls[key]
		var value: Variant = brief.get(key, "")
		if key == "location_name":
			value = brief.get("location_name", brief.get("name", ""))
		elif key in ["width", "height"]:
			value = (brief.get("dimensions", {}) as Dictionary).get(key, brief.get(key, 20 if key == "width" else 12))
		if control is LineEdit:
			(control as LineEdit).text = String(value)
		elif control is TextEdit:
			(control as TextEdit).text = String(value)
		elif control is SpinBox:
			(control as SpinBox).value = int(value)
		elif control is OptionButton:
			_select_option(control as OptionButton, String(value))
	var world := String(brief.get("world", _selected_world()))
	var world_idx := _world_ids.find(world)
	if world_idx >= 0:
		_world_option.select(world_idx)
	_refresh_locations()
	_refresh_availability()
	_sync_editor_from_brief()


func _collect_brief() -> Dictionary:
	var id := _brief_id()
	var name := (_brief_controls["location_name"] as LineEdit).text.strip_edges()
	if id == "" and name != "":
		id = CCSFactoryIO.sanitize_id(name)
		(_brief_controls["id"] as LineEdit).text = id
	var doc := {
		"schema": "crossroads.location_brief.v1",
		"id": id,
		"location_name": name,
		"world": _selected_world(),
		"location_type": (_brief_controls["location_type"] as OptionButton).get_item_text((_brief_controls["location_type"] as OptionButton).selected),
		"purpose": (_brief_controls["purpose"] as TextEdit).text.strip_edges(),
		"player_experience": (_brief_controls["player_experience"] as TextEdit).text.strip_edges(),
		"visual_theme": (_brief_controls["visual_theme"] as TextEdit).text.strip_edges(),
		"dimensions": {"width": int((_brief_controls["width"] as SpinBox).value), "height": int((_brief_controls["height"] as SpinBox).value)},
		"entry_points": (_brief_controls["entry_points"] as TextEdit).text.strip_edges(),
		"exit_points": (_brief_controls["exit_points"] as TextEdit).text.strip_edges(),
		"enemy_plan": (_brief_controls["enemy_plan"] as TextEdit).text.strip_edges(),
		"reward_plan": (_brief_controls["reward_plan"] as TextEdit).text.strip_edges(),
		"interactables": (_brief_controls["interactables"] as TextEdit).text.strip_edges(),
		"story_events": (_brief_controls["story_events"] as TextEdit).text.strip_edges(),
		"design_notes": (_brief_controls["design_notes"] as TextEdit).text.strip_edges(),
		"updated_at": Time.get_datetime_string_from_system(),
	}
	doc["created_at"] = String(_loaded_brief.get("created_at", doc["updated_at"]))
	return doc


func save_brief() -> bool:
	var doc := _collect_brief()
	var id := String(doc.get("id", ""))
	if id == "" or String(doc.get("location_name", "")) == "":
		_brief_status.text = "Location name and ID are required."
		return false
	var err := CCSFactoryIO.save_doc(brief_path(id), doc)
	if err != "":
		_brief_status.text = "Error: " + err
		return false
	_loaded_brief = doc
	_sync_editor_from_brief()
	_brief_status.text = "Saved %s" % brief_path(id)
	return true


func load_brief(location_id: String) -> bool:
	if location_id.strip_edges() == "":
		_brief_status.text = "Enter or select a location ID first."
		return false
	var doc := CCSFactoryIO.load_doc(brief_path(location_id))
	if doc.is_empty():
		_brief_status.text = "No saved brief at %s" % brief_path(location_id)
		return false
	set_brief_data(doc)
	_brief_status.text = "Loaded %s" % brief_path(location_id)
	_load_proposal(location_id)
	_load_review(location_id)
	return true


func _sync_editor_from_brief() -> void:
	if editor == null:
		return
	editor.prepare_from_brief(_collect_brief())


func generate_layout_proposal() -> Dictionary:
	if not save_brief():
		return {}
	var brief := _collect_brief()
	var id := String(brief["id"])
	var dimensions: Dictionary = brief["dimensions"]
	var proposal := {
		"schema": "crossroads.location_proposal.v1",
		"location_id": id,
		"world": brief["world"],
		"generated_at": Time.get_datetime_string_from_system(),
		"room_purpose": brief["purpose"],
		"recommended_dimensions": {
			"width": dimensions["width"], "height": dimensions["height"],
			"reason": "Use the brief dimensions first; revise only after a playtest shows the route is cramped or empty.",
		},
		"proposed_tile_zones": [
			{"zone": "boundary", "layer": "walls", "purpose": "Readable perimeter and collision boundary"},
			{"zone": "main_route", "layer": "ground", "purpose": "Direct readable path from entry to objective and exit"},
			{"zone": "encounter_space", "layer": "ground", "purpose": String(brief["enemy_plan"]) if String(brief["enemy_plan"]) != "" else "Keep clear unless an encounter is approved"},
			{"zone": "visual_landmarks", "layer": "decoration", "purpose": String(brief["visual_theme"])},
		],
		"entrances_and_exits": {"entries": _lines(String(brief["entry_points"])), "exits": _lines(String(brief["exit_points"]))},
		"enemy_placements": {"plan": String(brief["enemy_plan"]), "marker_type": "dungeon_enemy_spawn", "guidance": "Place away from the player spawn and preserve a readable escape lane."},
		"reward_placement": {"plan": String(brief["reward_plan"]), "marker_type": "dungeon_chest_spawn", "guidance": "Make the reward visible from, or clearly signposted by, the objective route."},
		"interaction_points": {"interactables": _lines(String(brief["interactables"])), "story_events": _lines(String(brief["story_events"]))},
		"risks": ["Exit target missing or circular", "Collision traps the player", "Markers overlap walls", "Decoration obscures the objective", "Encounter density exceeds the brief"],
		"required_missing_assets": _required_missing_assets(brief),
		"acceptance_criteria": [
			"Player spawns at the intended entry", "Required exit is reachable", "Collision contains the route without trapping the player",
			"Objective is understandable without editor knowledge", "Approved enemies and rewards use existing content IDs or documented placeholders",
			"PLAY THIS LOCATION launches without parser/runtime errors", "Human review is saved as approved or revise",
		],
		"design_notes": brief["design_notes"],
	}
	var err := CCSFactoryIO.save_doc(proposal_path(id), proposal)
	if err != "":
		_proposal_status.text = "Error: " + err
		return {}
	_proposal_view.text = JSON.stringify(proposal, "  ")
	_proposal_status.text = "Saved %s" % proposal_path(id)
	return proposal


func _required_missing_assets(brief: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	if _tilesets_for_world(String(brief["world"])).is_empty():
		missing.append("No saved tileset for world '%s'" % String(brief["world"]))
	if String(brief["enemy_plan"]) != "" and _ids_for_world(scan.enemies, String(brief["world"])).is_empty():
		missing.append("Enemy plan exists but no regular enemy content is available for this world")
	if String(brief["reward_plan"]) != "" and _ids_for_world(scan.items, String(brief["world"])).is_empty():
		missing.append("Reward plan exists but no item content is available for this world")
	if missing.is_empty():
		missing.append("None identified automatically; Claude must still inspect referenced content and validation fallbacks")
	return missing


func _lines(value: String) -> Array[String]:
	var out: Array[String] = []
	for line in value.replace(";", "\n").split("\n"):
		var clean := String(line).strip_edges()
		if clean != "":
			out.append(clean)
	return out


func _load_proposal(location_id: String) -> void:
	var doc := CCSFactoryIO.load_doc(proposal_path(location_id))
	_proposal_view.text = JSON.stringify(doc, "  ") if not doc.is_empty() else ""


func set_review_data(review: Dictionary) -> void:
	for key in _review_controls:
		var control: Control = _review_controls[key]
		var value := String(review.get(key, ""))
		if control is OptionButton:
			_select_option(control as OptionButton, value)
		elif control is TextEdit:
			(control as TextEdit).text = value


func save_review() -> bool:
	var id := _brief_id()
	if id == "":
		_review_status.text = "Save or load a location brief first."
		return false
	var review := {
		"schema": "crossroads.location_review.v1", "location_id": id,
		"reviewed_at": Time.get_datetime_string_from_system(),
	}
	for key in _review_controls:
		var control: Control = _review_controls[key]
		if control is OptionButton:
			review[key] = (control as OptionButton).get_item_text((control as OptionButton).selected)
		elif control is TextEdit:
			review[key] = (control as TextEdit).text.strip_edges()
	var err := CCSFactoryIO.save_doc(review_path(id), review)
	if err != "":
		_review_status.text = "Error: " + err
		return false
	_review_status.text = "Saved %s" % review_path(id)
	return true


func _load_review(location_id: String) -> void:
	var doc := CCSFactoryIO.load_doc(review_path(location_id))
	if not doc.is_empty():
		set_review_data(doc)
		_review_status.text = "Loaded %s" % review_path(location_id)


func _select_option(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if option.get_item_text(i) == value:
			option.select(i)
			return


func _on_existing_location_selected(index: int) -> void:
	if index <= 0 or index - 1 >= _location_ids.size() or scan == null:
		return
	var id := _location_ids[index - 1]
	var loc: Dictionary = scan.locations.get(id, {})
	if loc.is_empty():
		return
	var brief := CCSFactoryIO.load_doc(brief_path(id))
	if brief.is_empty():
		brief = {
			"id": id, "location_name": String(loc.get("name", id)), "world": String(loc.get("world", _selected_world())),
			"location_type": String(loc.get("location_type", "town")), "dimensions": {"width": int(loc.get("width", 20)), "height": int(loc.get("height", 12))},
		}
	set_brief_data(brief)
	editor.load_location_data(loc)
	_load_proposal(id)
	_load_review(id)
