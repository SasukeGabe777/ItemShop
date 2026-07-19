extends Node2D
## Smoke-tests the Live Developer Hub's required safe runtime workflows.

const DEV_LOCATION_SCENE := preload("res://scenes/dev/dev_location.tscn")
const SHOP_SCENE := preload("res://scenes/shop/shop.tscn")

var failures: Array[String] = []
var original_dev_state_exists := false
var original_dev_state_text := ""
var original_dev_metadata := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_original_dev_state()
	var normal_saves_before := _normal_save_fingerprints()

	_check(DevHubManager.is_development_enabled(), "development mode is enabled in this debug build")
	_check(InputMap.has_action("dev_hub") and _has_f1_binding(), "F1 is bound to the development hub action")
	var toggle_event := InputEventAction.new()
	toggle_event.action = "dev_hub"
	toggle_event.pressed = true
	DevHubManager._unhandled_input(toggle_event)
	_check(DevHubManager.hub_open and get_tree().paused, "hub opens and pauses the game")
	DevHubManager.set_game_running_behind_hub(true)
	_check(not get_tree().paused, "game can resume behind the visible hub")
	DevHubManager.close_hub()
	_check(not DevHubManager.hub_open and not get_tree().paused, "hub closes and restores pause state")

	DevHubManager.ensure_dev_campaign(true)
	DevHubManager.select_development_world("kingdom_hearts")
	_check(DevHubManager.all_locations().has("crossroads_shop") and DevHubManager.all_locations().has("kingdom_hearts_dungeon"), "built-in shop and world dungeon locations are cataloged")
	var gold_before := EconomyManager.gold
	DevHubManager.change_money(321)
	_check(EconomyManager.gold == gold_before + 321, "money can be changed in memory")
	_check(DevHubManager.change_inventory("kh_potion", 2) and InventoryManager.count("kh_potion") >= 2, "inventory can be changed in memory")

	var location_data := DevHubManager.create_blank_location("automated_dev_hub_test")
	_check(not location_data.is_empty(), "blank development location can be created")
	var location := DEV_LOCATION_SCENE.instantiate()
	add_child(location)
	_check(location.is_in_group("location_runtime"), "development location launches")
	var item := DevHubManager.spawn_content("item", "kh_potion", Vector2(160, 144))
	var customer_id := _first_id(ContentDatabase.named_customers)
	var customer := DevHubManager.spawn_content("customer", customer_id, Vector2(192, 144))
	var enemy := DevHubManager.spawn_content("enemy", "shadow_heartless", Vector2(240, 144))
	_check(item != null, "an item can be spawned")
	_check(customer != null, "a customer can be spawned")
	_check(enemy != null, "an enemy can be spawned")
	DevHubManager.select_object(item)
	_check(DevHubManager.set_selected_position(Vector2(176, 152)), "a selected object can be moved")
	_check(DevHubManager.save_current_location_layout(), "development location layout can be saved")

	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	var furniture: Node = shop.call("dev_spawn_furniture", "small_display_crate", Vector2(260, 250))
	_check(furniture != null, "shop furniture can be spawned with the existing furniture system")
	if furniture != null:
		DevHubManager.select_object(furniture)
		_check(DevHubManager.set_selected_position(Vector2(300, 250)), "shop furniture can be selected and moved")
	var summoned: Node = shop.call("dev_summon_customer", customer_id, Vector2(106, 305))
	_check(summoned != null, "a real shop customer can be summoned")
	_check(bool(shop.call("dev_set_display_item", 0, "kh_potion")) and String(InventoryManager.display[0]) == "kh_potion", "an item can be assigned to a real display slot")

	_check(DevHubManager.save_dev_state(), "separate development state can be saved")
	_check(FileAccess.file_exists(DevHubManager.DEV_STATE_PATH), "development state uses its own file")
	_check(DevHubManager.start_playtest_session(), "playtest session starts and captures state")
	_check(DevHubManager.add_playtest_note("gameplay issue", "Automated Live Developer Hub workflow check."), "playtest note can be added")
	_check(DevHubManager.end_playtest_session(), "playtest session ends")
	for path in ["runtime_log.txt", "state_snapshot.json", "validation_report.json", "playtest_notes.md"]:
		_check(FileAccess.file_exists("res://playtest/latest/" + path), "playtest report exists: " + path)

	_check(DevHubManager.export_ai_context("Verify the Live Developer Hub automated workflow."), "AI context can be exported")
	for path in ["PROJECT_CONTEXT.md", "CURRENT_STATE.json", "SELECTED_LOCATION.json", "AVAILABLE_CONTENT.json", "VALIDATION_REPORT.json", "PLAYTEST_NOTES.md", "REQUEST.md"]:
		_check(FileAccess.file_exists("res://ai_workspace/current/" + path), "AI context file exists: " + path)
	_check(DevHubManager.copy_claude_prompt().begins_with("Read AI_PARTNER.md"), "Claude prompt is generated")

	SaveManager.autosave()
	_check(normal_saves_before == _normal_save_fingerprints(), "normal save files were not modified")
	_report()


func _first_id(table: Dictionary) -> String:
	var keys := table.keys()
	return String(keys[0]) if not keys.is_empty() else ""


func _has_f1_binding() -> bool:
	for event in InputMap.action_get_events("dev_hub"):
		if event is InputEventKey and ((event as InputEventKey).physical_keycode == KEY_F1 or (event as InputEventKey).keycode == KEY_F1):
			return true
	return false


func _normal_save_fingerprints() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return out
	for name in dir.get_files():
		var path := ProjectSettings.globalize_path("user://saves/" + name)
		out[name] = FileAccess.get_md5(path)
	return out


func _capture_original_dev_state() -> void:
	original_dev_state_exists = FileAccess.file_exists(DevHubManager.DEV_STATE_PATH)
	if original_dev_state_exists:
		original_dev_state_text = FileAccess.open(DevHubManager.DEV_STATE_PATH, FileAccess.READ).get_as_text()
	original_dev_metadata = {
		"selected_world": DevHubManager.selected_world,
		"selected_location": DevHubManager.selected_location,
		"temporary_world_unlocks": DevHubManager.temporary_world_unlocks.duplicate(),
		"dev_locations": DevHubManager.dev_locations.duplicate(true),
		"request": DevHubManager.dev_request,
		"isolated": DevHubManager.isolated_dev_state_active,
	}


func _restore_original_dev_state() -> void:
	var absolute := ProjectSettings.globalize_path(DevHubManager.DEV_STATE_PATH)
	if original_dev_state_exists:
		var file := FileAccess.open(DevHubManager.DEV_STATE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(original_dev_state_text)
	elif FileAccess.file_exists(DevHubManager.DEV_STATE_PATH):
		DirAccess.remove_absolute(absolute)
	DevHubManager.selected_world = String(original_dev_metadata.get("selected_world", "kingdom_hearts"))
	DevHubManager.selected_location = String(original_dev_metadata.get("selected_location", ""))
	DevHubManager.temporary_world_unlocks.clear()
	for world_id in original_dev_metadata.get("temporary_world_unlocks", []):
		DevHubManager.temporary_world_unlocks.append(String(world_id))
	DevHubManager.dev_locations = original_dev_metadata.get("dev_locations", {}).duplicate(true)
	DevHubManager.dev_request = String(original_dev_metadata.get("request", ""))
	DevHubManager.isolated_dev_state_active = bool(original_dev_metadata.get("isolated", false))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("DEV_HUB_CHECK_PASS: " + label)
	else:
		failures.append(label)
		printerr("DEV_HUB_CHECK_FAIL: " + label)


func _report() -> void:
	if failures.is_empty():
		print("DEV_HUB_TEST_PASS")
	else:
		printerr("DEV_HUB_TEST_FAIL: %d failure(s)" % failures.size())
	get_tree().paused = false
	var exit_code := 0 if failures.is_empty() else 1
	for child in get_children():
		child.queue_free()
	if is_instance_valid(DevHubManager.hub):
		DevHubManager.hub.queue_free()
		DevHubManager.hub = null
	call_deferred("_quit_after_cleanup", exit_code)


func _quit_after_cleanup(exit_code: int) -> void:
	_restore_original_dev_state()
	DevHubManager.selected_object = null
	AudioManager.stop_music()
	AudioManager.music_player.stream = null
	AudioManager.stinger_player.stop()
	AudioManager.stinger_player.stream = null
	AudioManager.music_player.queue_free()
	AudioManager.stinger_player.queue_free()
	for _frame in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit(exit_code)
