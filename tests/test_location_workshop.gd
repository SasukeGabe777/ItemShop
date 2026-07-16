extends Node
## Focused proof of the human/AI Location Workshop. All write-side assertions
## use user:// scratch data; the repository's real locations/briefs stay clean.

const WORKSHOP_SCRIPT := preload("res://addons/crossroads_content_studio/ui/location_workshop_tab.gd")
const DEV_LOCATION_SCENE := preload("res://scenes/dev/dev_location.tscn")
const BRIDGE := preload("res://scripts/dev/location_workshop_bridge.gd")
const TEST_ROOT := "user://location_workshop_test"
const LOCATION_ID := "workshop_test_room"

var failures: Array[String] = []


func _ready() -> void:
	print("LOCATION_WORKSHOP_STAGE: setup")
	BRIDGE.clear_launch()
	var scan := CCSContentScan.new()
	scan.scan()
	var workshop = WORKSHOP_SCRIPT.new()
	workshop.brief_root = TEST_ROOT.path_join("briefs")
	workshop.locations_data_path = TEST_ROOT.path_join("locations.json")
	add_child(workshop)
	workshop.setup(scan)

	var brief := {
		"id": LOCATION_ID,
		"location_name": "Workshop Test Room",
		"world": "kingdom_hearts",
		"purpose": "Prove one readable combat-and-reward room can be designed without scene internals.",
		"location_type": "dungeon_room",
		"player_experience": "Enter south, read the arena, defeat one Shadow, collect a shard, leave north.",
		"visual_theme": "Small Traverse Town plaza with a clear central route.",
		"dimensions": {"width": 12, "height": 8},
		"entry_points": "south player spawn",
		"exit_points": "north door -> crossroads_town",
		"enemy_plan": "shadow_heartless x1 in the center",
		"reward_plan": "lucid_shard chest near the north exit",
		"interactables": "one chest; one exit door",
		"story_events": "none",
		"design_notes": "Keep the route short and reuse existing systems.",
	}
	workshop.set_brief_data(brief)
	_check(workshop._availability.text.contains("shadow_heartless"), "world step lists available enemies")
	_check(workshop.save_brief(), "visual brief saves")
	print("LOCATION_WORKSHOP_STAGE: brief")
	var saved_brief := CCSFactoryIO.load_doc(workshop.brief_path(LOCATION_ID))
	_check(String(saved_brief.get("player_experience", "")).contains("defeat one Shadow"), "brief is human-readable structured JSON")

	var proposal: Dictionary = workshop.generate_layout_proposal()
	_check(not proposal.is_empty(), "layout proposal generates")
	_check((proposal.get("proposed_tile_zones", []) as Array).size() >= 4, "proposal includes structured tile zones")
	_check((proposal.get("acceptance_criteria", []) as Array).size() >= 5, "proposal includes acceptance criteria")
	_check(FileAccess.file_exists(workshop.proposal_path(LOCATION_ID)), "proposal file is saved beside the brief")
	print("LOCATION_WORKSHOP_STAGE: proposal")

	var map = workshop.editor
	_check(map.loc_w == 12 and map.loc_h == 8, "brief dimensions apply to the existing map editor")
	_check(map.paint_cell("ground", Vector2i(1, 1), 2), "ground can be painted")
	_check(map.paint_cell("walls", Vector2i(0, 0), 3), "walls can be painted")
	_check(map.paint_cell("decoration", Vector2i(2, 2), 4), "decorations can be painted")
	_check(map.paint_cell("collision", Vector2i(0, 0)), "collision can be painted")
	_check(map.place_marker("player_spawn", Vector2i(1, 1)), "player marker can be placed")
	_check(map.place_marker("customer_spawn", Vector2i(1, 6)), "customer spawn marker can be placed")
	_check(map.place_marker("customer_exit", Vector2i(0, 6)), "customer exit marker can be placed")
	_check(map.place_marker("dungeon_enemy_spawn", Vector2i(5, 4)), "enemy marker can be placed")
	_check(map.place_marker("dungeon_chest_spawn", Vector2i(8, 2)), "chest marker can be placed")
	_check(map.place_marker("item_stand_slot", Vector2i(3, 3)), "item stand marker can be placed")
	_check(map.place_marker("door_exit", Vector2i(6, 0), "crossroads_town"), "exit marker can be placed with a target")
	_check(map.place_marker("dialogue_trigger", Vector2i(2, 6)), "dialogue trigger can be placed")
	_check(map.place_marker("boss_trigger", Vector2i(9, 4)), "boss trigger can be placed")
	_check(map.place_marker("shop_counter_area", Vector2i(4, 6)), "legacy shop counter marker remains available")
	_check(map.move_marker_at(Vector2i(5, 4), Vector2i(6, 4)), "an existing marker can be moved")
	_check(map.save_location(), "painted location saves")
	var saved_location: Dictionary = map.current_location_entry()
	_check(not saved_location.is_empty(), "saved location reload document exists")
	_check(int((saved_location.get("layers", {}) as Dictionary).get("walls", [])[0]) == 3, "wall layer persists")
	_check((saved_location.get("markers", []) as Array).size() == 10, "gameplay markers persist")
	print("LOCATION_WORKSHOP_STAGE: map")
	map._reset_map()
	map.load_location_data(saved_location)
	_check(int(map.layers["ground"][1 * map.loc_w + 1]) == 2, "saved tile map reloads")
	_check(map._marker_at(Vector2i(6, 4)) >= 0, "moved marker reloads at its new cell")

	workshop.set_review_data({
		"navigation_readable": "yes", "collisions_correct": "yes", "objective_clear": "yes",
		"enemies_appropriate": "yes", "rewards_worthwhile": "yes", "visual_problems": "Placeholder floor",
		"missing_assets": "Dedicated plaza tiles", "notes": "Ready for one human pass", "decision": "approved",
	})
	_check(workshop.save_review(), "review saves")
	var review := CCSFactoryIO.load_doc(workshop.review_path(LOCATION_ID))
	_check(String(review.get("decision", "")) == "approved", "review records approved/revise decision")
	print("LOCATION_WORKSHOP_STAGE: review")

	var had_location := ContentDatabase.locations.has(LOCATION_ID)
	var original_location: Dictionary = ContentDatabase.locations.get(LOCATION_ID, {}).duplicate(true)
	ContentDatabase.locations[LOCATION_ID] = saved_location
	_check(map.play_this_location(false), "PLAY THIS LOCATION prepares a safe debug launch")
	print("LOCATION_WORKSHOP_STAGE: runtime")
	var runtime := DEV_LOCATION_SCENE.instantiate()
	add_child(runtime)
	await get_tree().process_frame
	_check(DevHubManager.isolated_dev_state_active, "location launches in isolated development state")
	_check(DevHubManager.selected_location == LOCATION_ID, "the selected workshop location reaches the runtime")
	_check(runtime.location_root != null and runtime.location_root.get_node_or_null("Walls") != null, "runtime builds the painted wall layer")
	_check(runtime.player.position.is_equal_approx(Vector2(24, 24)), "runtime uses the painted player spawn marker")
	if had_location:
		ContentDatabase.locations[LOCATION_ID] = original_location
	else:
		ContentDatabase.locations.erase(LOCATION_ID)
	runtime.queue_free()
	workshop.queue_free()
	BRIDGE.clear_launch()
	await get_tree().process_frame
	_report()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [Location Workshop] " + message)
	else:
		failures.append(message)
		printerr("LOCATION_WORKSHOP_FAIL: " + message)


func _report() -> void:
	if failures.is_empty():
		print("LOCATION_WORKSHOP_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)
