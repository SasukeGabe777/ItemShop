@tool
extends CCSEntityFactoryTab
## Customer Factory: create named shoppers fast — a single static frame is
## enough (Save Static Sprite Only), full walk animations optional. Economic
## personality fields default safely and are flagged needs_ai_personality /
## needs_ai_balance so they can be filled in later.

var _archetype_option: OptionButton
var _chapter_spin: SpinBox
var _budget_spin: SpinBox
var _quirk_edit: LineEdit
var _line_edit: LineEdit


func _cfg_type_label() -> String:
	return "Customer"


func _cfg_data_path() -> String:
	return CCSAssetPaths.DATA_CUSTOMERS


func _cfg_array_key() -> String:
	return "named"


func _cfg_schema_tag() -> String:
	return "crossroads.customers.v1"


func _cfg_required_anims() -> Array[String]:
	return ["idle_down", "idle_up", "idle_side", "walk_down", "walk_up", "walk_side"]


func _cfg_optional_anims() -> Array[String]:
	return [
		"idle_left", "idle_right", "walk_left", "walk_right",
		"happy", "angry", "thinking", "buy", "leave",
	]


func _cfg_entries() -> Array:
	return scan.named_customers_raw


func _cfg_default_entry(id: String, name: String, world: String) -> Dictionary:
	return {
		"id": id, "name": name, "world": world,
		"archetype": _default_archetype(),
		"chapter": 1, "budget_mult": 1.0,
		"quirk": "", "line": "", "color": "#c0c0c0",
		"needs_ai_personality": true,
		"needs_ai_balance": true,
	}


func _default_archetype() -> String:
	if scan != null and not scan.archetypes.is_empty():
		var ids: Array = scan.archetypes.keys()
		ids.sort()
		return "adventurer" if scan.archetypes.has("adventurer") else String(ids[0])
	return "adventurer"


func _build_extra_fields(box: HFlowContainer) -> void:
	_archetype_option = add_option(box, "Archetype", [])
	_chapter_spin = add_spin(box, "Chapter", 1, 8, 1)
	_budget_spin = add_spin(box, "Budget x", 0.25, 4.0, 1.0, 0.05)
	var quirk_wrap := HBoxContainer.new()
	var ql := Label.new()
	ql.text = "Quirk:"
	quirk_wrap.add_child(ql)
	_quirk_edit = LineEdit.new()
	_quirk_edit.custom_minimum_size = Vector2(130, 0)
	quirk_wrap.add_child(_quirk_edit)
	box.add_child(quirk_wrap)
	var line_wrap := HBoxContainer.new()
	var ll := Label.new()
	ll.text = "Line:"
	line_wrap.add_child(ll)
	_line_edit = LineEdit.new()
	_line_edit.custom_minimum_size = Vector2(180, 0)
	line_wrap.add_child(_line_edit)
	box.add_child(line_wrap)
	var dup_btn := Button.new()
	dup_btn.text = "Duplicate Customer"
	dup_btn.tooltip_text = "Copy the selected customer into a new id (same sprite, archetype, and settings)"
	dup_btn.pressed.connect(_on_duplicate_pressed)
	box.add_child(dup_btn)


func refresh() -> void:
	super.refresh()
	_archetype_option.clear()
	var ids: Array = scan.archetypes.keys()
	ids.sort()
	for id in ids:
		_archetype_option.add_item(String(id))
	select_option(_archetype_option, _default_archetype())


func _apply_extra_fields(entry: Dictionary) -> void:
	entry["archetype"] = option_value(_archetype_option)
	entry["chapter"] = int(_chapter_spin.value)
	entry["budget_mult"] = _budget_spin.value
	entry["quirk"] = _quirk_edit.text.strip_edges()
	entry["line"] = _line_edit.text.strip_edges()


func _load_extra_fields(entry: Dictionary) -> void:
	select_option(_archetype_option, String(entry.get("archetype", _default_archetype())))
	_chapter_spin.value = int(entry.get("chapter", 1))
	_budget_spin.value = float(entry.get("budget_mult", 1.0))
	_quirk_edit.text = String(entry.get("quirk", ""))
	_line_edit.text = String(entry.get("line", ""))


func _on_duplicate_pressed() -> void:
	if _current_id == "":
		_status.text = "Select an existing customer to duplicate first."
		return
	var src := _entry_by_id(_current_id)
	if src.is_empty():
		return
	var taken := {}
	for entry: Dictionary in _cfg_entries():
		taken[String(entry.get("id", ""))] = true
	var new_id := CCSFactoryIO.unique_id(String(src["id"]), taken)
	var copy := src.duplicate(true)
	copy["id"] = new_id
	copy["name"] = "%s Copy" % String(src.get("name", new_id))
	copy["needs_ai_personality"] = true
	# variants without their own art fall back to the original's sprite
	if String(copy.get("hero_ref", "")) == "":
		var world := String(src.get("world", "crossroads"))
		if FileAccess.file_exists(CCSAssetPaths.manifest_path(world, _current_id)) \
				or FileAccess.file_exists(CCSAssetPaths.entity_processed_path(world, _current_id)):
			copy["hero_ref"] = _current_id
	var err := CCSFactoryIO.upsert_entry(_cfg_data_path(), _cfg_array_key(), _cfg_schema_tag(), copy)
	_status.text = ("Duplicated '%s' as '%s'." % [_current_id, new_id]) if err == "" else "Error: %s" % err
	if err == "":
		data_written.emit()
