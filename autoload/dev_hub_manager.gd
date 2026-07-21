extends Node
## Development-only runtime coordinator for the Crossroads Live Developer Hub.
## It owns F1, pause behavior, curated placement/inspection, separate dev-state
## persistence, playtest reports, AI context exports, and an in-memory log.
## Normal user save slots are never read or written by this manager.

signal hub_visibility_changed(visible: bool)
signal selection_changed(object: Node)
signal placement_changed(active: bool)
signal log_added(line: String)

const HUB_SCENE := preload("res://scenes/dev/dev_hub.tscn")
const DEV_OBJECT := preload("res://scripts/dev/dev_placed_object.gd")
const DEV_STATE_PATH := "user://crossroads_dev/live_dev_state.json"
const STATUS_PATH := "res://data/dev_status.json"
const PLAYTEST_DIR := "playtest/latest"
const AI_DIR := "ai_workspace/current"
const DEFAULT_WORLD := "kingdom_hearts"
const LOG_LIMIT := 400

var enabled: bool = false
var hub: CanvasLayer
var hub_open: bool = false
var game_running_behind_hub: bool = false
var _pause_before_open: bool = false
var isolated_dev_state_active: bool = false

var selected_world: String = DEFAULT_WORLD
var selected_location: String = ""
var selected_object: Node = null
var temporary_world_unlocks: Array[String] = []
var dev_locations: Dictionary = {}
var dev_request: String = ""
var location_edit_mode: bool = false

var placement_active: bool = false
var selection_pick_active: bool = false
var placement_type: String = ""
var placement_content_id: String = ""
var placement_preview: Node2D
var moving_object: Node = null
var moving_origin := Vector2.ZERO
var placement_grid: float = 8.0

var recent_log: Array[String] = []
var playtest_active: bool = false
var playtest_started_at: String = ""
var playtest_notes: Array[Dictionary] = []
var last_validation: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var explicit_cli := "--dev-hub" in args
	var project_enabled := bool(ProjectSettings.get_setting("crossroads/development/enabled", false))
	var require_debug := bool(ProjectSettings.get_setting("crossroads/development/require_debug_build", true))
	enabled = explicit_cli or (project_enabled and (OS.is_debug_build() or not require_debug))
	if not enabled:
		return
	_load_dev_metadata()
	call_deferred("_connect_runtime_signals")
	log_event("Live Developer Hub enabled (F1)")


func _connect_runtime_signals() -> void:
	if SceneRouter != null and not SceneRouter.scene_transition_requested.is_connected(_on_scene_transition):
		SceneRouter.scene_transition_requested.connect(_on_scene_transition)
	if SaveManager != null:
		if not SaveManager.saved.is_connected(_on_save_event):
			SaveManager.saved.connect(_on_save_event.bind("saved"))
		if not SaveManager.loaded.is_connected(_on_load_event):
			SaveManager.loaded.connect(_on_load_event.bind("loaded"))
	if ContentDatabase != null and not ContentDatabase.missing_asset_fallback.is_connected(_on_missing_asset):
		ContentDatabase.missing_asset_fallback.connect(_on_missing_asset)


func is_development_enabled() -> bool:
	return enabled


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("dev_hub"):
		toggle_hub()
		get_viewport().set_input_as_handled()
		return
	if placement_active or selection_pick_active:
		_handle_world_input(event)


func toggle_hub() -> void:
	if hub_open:
		close_hub()
	else:
		open_hub()


func open_hub(tab_name: String = "Today") -> void:
	if not enabled:
		return
	if hub == null:
		hub = HUB_SCENE.instantiate()
		add_child(hub)
	_pause_before_open = get_tree().paused
	isolated_dev_state_active = true
	hub_open = true
	game_running_behind_hub = false
	get_tree().paused = true
	hub.call("open_hub", tab_name)
	hub_visibility_changed.emit(true)


func close_hub() -> void:
	if hub == null:
		return
	cancel_world_action()
	hub_open = false
	hub.call("close_hub")
	get_tree().paused = _pause_before_open
	hub_visibility_changed.emit(false)


func set_game_running_behind_hub(running: bool) -> void:
	game_running_behind_hub = running
	if hub_open:
		get_tree().paused = not running


func status_data() -> Dictionary:
	return _read_json(STATUS_PATH)


func current_scene_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "none"
	return scene.scene_file_path if scene.scene_file_path != "" else scene.name


func current_location_id() -> String:
	var scene := get_tree().current_scene
	if scene != null and scene.has_meta("location_id"):
		return String(scene.get_meta("location_id"))
	if current_scene_name().contains("shop"):
		return "crossroads_shop"
	if current_scene_name().contains("town"):
		return "crossroads_town"
	if current_scene_name().contains("dungeon"):
		return selected_world + "_dungeon"
	return selected_location


func select_development_world(world_id: String) -> void:
	if ContentDatabase.worlds.has(world_id):
		selected_world = world_id
		log_event("Selected development world '%s' (campaign unlocks unchanged)" % world_id)


func is_world_temporarily_unlocked(world_id: String) -> bool:
	return enabled and world_id in temporary_world_unlocks


func set_world_temporarily_unlocked(world_id: String, value: bool) -> void:
	if value and not (world_id in temporary_world_unlocks):
		temporary_world_unlocks.append(world_id)
	elif not value:
		temporary_world_unlocks.erase(world_id)
	log_event("Temporary world unlock %s = %s" % [world_id, value])


func world_summary(world_id: String) -> Dictionary:
	var summary := {"heroes": 0, "items": 0, "enemies": 0, "customers": 0, "locations": 0, "missing_assets": 0, "incomplete": 0}
	for entry: Dictionary in ContentDatabase.heroes.values():
		if String(entry.get("world", "")) == world_id:
			summary["heroes"] += 1
			_count_entity_quality(entry, world_id, summary)
	for entry: Dictionary in ContentDatabase.items.values():
		if String(entry.get("world", "")) == world_id:
			summary["items"] += 1
			var path := "res://assets/franchises/%s/processed/items/%s.png" % [world_id, String(entry.get("id", ""))]
			if not ResourceLoader.exists(path):
				summary["missing_assets"] += 1
			_count_incomplete_flags(entry, summary)
	for entry: Dictionary in ContentDatabase.enemies.values():
		if String(entry.get("world", "")) == world_id:
			summary["enemies"] += 1
			_count_entity_quality(entry, world_id, summary)
	for entry: Dictionary in ContentDatabase.bosses.values():
		if String(entry.get("world", "")) == world_id:
			summary["enemies"] += 1
			_count_entity_quality(entry, world_id, summary)
	for entry: Dictionary in ContentDatabase.named_customers.values():
		if String(entry.get("world", "")) == world_id:
			summary["customers"] += 1
			_count_incomplete_flags(entry, summary)
	for entry: Dictionary in all_locations().values():
		if String(entry.get("world", "")) == world_id:
			summary["locations"] += 1
	return summary


func _count_entity_quality(entry: Dictionary, world_id: String, summary: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	var manifest := "res://assets/franchises/%s/manifests/%s.json" % [world_id, id]
	var static_path := "res://assets/franchises/%s/processed/%s.png" % [world_id, id]
	if not FileAccess.file_exists(manifest) and not ResourceLoader.exists(static_path):
		summary["missing_assets"] += 1
	_count_incomplete_flags(entry, summary)


func _count_incomplete_flags(entry: Dictionary, summary: Dictionary) -> void:
	for key in ["needs_ai_balance", "needs_description", "needs_ai_personality"]:
		if bool(entry.get(key, false)):
			summary["incomplete"] += 1
			return


func all_locations() -> Dictionary:
	var out := ContentDatabase.locations.duplicate(true)
	for id: String in _runtime_location_catalog():
		if not out.has(id):
			out[id] = _runtime_location_catalog()[id]
	for id: String in dev_locations:
		out[id] = dev_locations[id]
	return out


func _runtime_location_catalog() -> Dictionary:
	var out := {
		"crossroads_town": {"id": "crossroads_town", "name": "Crossroads Town", "world": "", "type": "town", "width": 40, "height": 22, "tile_size": 16, "markers": [{"type": "player_spawn"}, {"type": "door_exit", "target": "crossroads_shop"}], "objects": [], "runtime_route": "town"},
		"crossroads_shop": {"id": "crossroads_shop", "name": "Crossroads Item Shop", "world": "", "type": "shop", "width": 40, "height": 22, "tile_size": 16, "markers": [{"type": "player_spawn"}, {"type": "customer_spawn"}, {"type": "customer_exit"}, {"type": "door_exit", "target": "crossroads_town"}], "objects": [], "runtime_route": "shop"},
	}
	for world_id: String in ContentDatabase.world_order:
		var world := ContentDatabase.get_world(world_id)
		var location_id := world_id + "_dungeon"
		out[location_id] = {
			"id": location_id, "name": String(world.get("location", world_id.capitalize())),
			"world": world_id, "type": "dungeon", "width": 40, "height": 22,
			"tile_size": 16, "markers": [{"type": "player_spawn"}, {"type": "door_exit", "target": "crossroads_town"}],
			"objects": [], "runtime_route": "dungeon",
		}
	return out


func blank_location(location_id: String, world_id: String = "") -> Dictionary:
	var id := location_id.strip_edges().to_lower().replace(" ", "_")
	if id == "":
		id = "dev_location_%d" % Time.get_ticks_msec()
	var world := world_id if world_id != "" else selected_world
	return {
		"id": id, "name": id.replace("_", " ").capitalize(), "world": world,
		"type": "town", "width": 40, "height": 22, "tile_size": 16,
		"tileset": "", "layers": {"ground": [], "decoration": []},
		"collision": [],
		"markers": [
			{"type": "player_spawn", "x": 20, "y": 11},
			{"type": "door_exit", "x": 20, "y": 20, "target": "crossroads_town"},
		],
		"objects": [], "development_only": true,
	}


func create_blank_location(location_id: String) -> Dictionary:
	var loc := blank_location(location_id)
	var id := String(loc["id"])
	var base := id
	var suffix := 2
	while all_locations().has(id):
		id = "%s_%d" % [base, suffix]
		suffix += 1
	loc["id"] = id
	dev_locations[id] = loc
	selected_location = id
	save_dev_state(false)
	log_event("Created blank development location '%s'" % id)
	return loc


func select_location(location_id: String) -> void:
	if all_locations().has(location_id):
		selected_location = location_id
		var loc: Dictionary = all_locations()[location_id]
		select_development_world(String(loc.get("world", selected_world)))


func current_location_data() -> Dictionary:
	return all_locations().get(selected_location, {})


func location_summary(location_id: String) -> Dictionary:
	var loc: Dictionary = all_locations().get(location_id, {})
	if loc.is_empty():
		return {}
	var markers: Array = loc.get("markers", [])
	var marker_counts := {}
	var entrances := 0
	var exits := 0
	for marker: Dictionary in markers:
		var kind := String(marker.get("type", "marker"))
		marker_counts[kind] = int(marker_counts.get(kind, 0)) + 1
		if kind in ["player_spawn", "customer_spawn"]:
			entrances += 1
		if kind in ["door_exit", "customer_exit"]:
			exits += 1
	return {
		"id": String(loc.get("id", location_id)), "name": String(loc.get("name", location_id)),
		"world": String(loc.get("world", "")), "type": String(loc.get("type", "")),
		"dimensions": "%dx%d @ %dpx" % [int(loc.get("width", 0)), int(loc.get("height", 0)), int(loc.get("tile_size", 16))],
		"entrances": entrances, "exits": exits, "spawn_markers": marker_counts,
		"interactables": (loc.get("objects", []) as Array).size(),
		"problems": validate_location(loc),
	}


func validate_location(loc: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if int(loc.get("width", 0)) <= 0 or int(loc.get("height", 0)) <= 0:
		problems.append("Dimensions must be positive")
	var has_player := false
	var has_exit := false
	for marker: Dictionary in loc.get("markers", []):
		if String(marker.get("type", "")) == "player_spawn": has_player = true
		if String(marker.get("type", "")) == "door_exit": has_exit = true
	if not has_player: problems.append("Missing player_spawn marker")
	if not has_exit: problems.append("Missing door_exit marker")
	if String(loc.get("world", "")) != "" and not ContentDatabase.worlds.has(String(loc.get("world", ""))):
		problems.append("Unknown world")
	return problems


func launch_selected_location() -> bool:
	var loc := current_location_data()
	if loc.is_empty():
		return false
	match String(loc.get("runtime_route", "")):
		"town":
			ensure_dev_campaign()
			SceneRouter.go("town", {"development": true, "location_id": selected_location})
		"shop":
			ensure_dev_campaign()
			SceneRouter.go("shop", {"development": true, "location_id": selected_location})
		"dungeon":
			ensure_dev_campaign()
			selected_world = String(loc.get("world", selected_world))
			var world := ContentDatabase.get_world(selected_world)
			DungeonManager.plan_expedition(selected_world, String(world.get("hero", "sora")), [])
			SceneRouter.go("dungeon", {"development": true, "location_id": selected_location})
		_:
			SceneRouter.go("dev_location", {"location_id": selected_location, "development": true})
	return true


func save_current_location_layout() -> bool:
	if selected_location == "":
		return false
	var loc: Dictionary = current_location_data().duplicate(true)
	if String(loc.get("runtime_route", "")) == "shop":
		log_event("Saved shop furniture and displays in separate development state")
		return save_dev_state(true)
	if String(loc.get("runtime_route", "")) != "":
		log_event("Built-in %s layout is runtime-authored and cannot be overwritten here" % String(loc.get("type", "location")), "WARNING")
		return false
	var runtime := _location_runtime()
	if runtime != null and runtime.has_method("serialize_dev_objects"):
		loc["objects"] = runtime.call("serialize_dev_objects")
	loc["development_only"] = true
	dev_locations[selected_location] = loc
	var ok := save_dev_state(false)
	log_event("Saved development layout '%s'" % selected_location)
	return ok


func reload_current_location_layout() -> bool:
	_load_dev_metadata()
	if selected_location == "" or not all_locations().has(selected_location):
		return false
	return launch_selected_location()


func restore_location_objects(runtime: Node) -> void:
	var loc := current_location_data()
	for row: Dictionary in loc.get("objects", []):
		if not runtime.has_method("add_dev_object"):
			break
		var pos_arr: Array = row.get("position", [0, 0])
		var obj: Node2D = runtime.call("add_dev_object", String(row.get("type", "object")), String(row.get("content_id", "")), Vector2(float(pos_arr[0]), float(pos_arr[1])), row.get("properties", {}))
		obj.rotation = float(row.get("rotation", 0.0))
		obj.set_collision_enabled(bool(row.get("collision_enabled", false)))


func create_or_open_location_brief() -> String:
	if selected_location == "":
		return ""
	var dir := ProjectSettings.globalize_path("res://docs/location_briefs")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(selected_location + ".md")
	if not FileAccess.file_exists(path):
		var template := _read_text("res://docs/LOCATION_BRIEF_TEMPLATE.md")
		var loc := current_location_data()
		var preface := "# %s Location Brief\n\n- Location ID: `%s`\n- World: `%s`\n- Type: `%s`\n\n" % [String(loc.get("name", selected_location)), selected_location, String(loc.get("world", selected_world)), String(loc.get("type", "town"))]
		_write_text_absolute(path, preface + template)
	log_event("Location brief: %s" % path)
	return path


func begin_placement(object_type: String, content_id: String, object_to_move: Node = null) -> bool:
	if not enabled or get_tree().current_scene == null:
		return false
	cancel_world_action()
	placement_active = true
	placement_type = object_type
	placement_content_id = content_id
	moving_object = object_to_move
	if moving_object != null and moving_object is Node2D:
		moving_origin = (moving_object as Node2D).global_position
		(moving_object as Node2D).visible = false
	placement_preview = DEV_OBJECT.new()
	get_tree().current_scene.add_child(placement_preview)
	placement_preview.setup(object_type, content_id, {"placement_valid": true}, true)
	if hub != null:
		hub.call("set_world_pick_mode", true, "Place %s '%s': click to confirm, Esc/right-click to cancel" % [object_type, content_id])
	placement_changed.emit(true)
	return true


func begin_select_object() -> void:
	cancel_world_action()
	selection_pick_active = true
	if hub != null:
		hub.call("set_world_pick_mode", true, "Select an editable runtime object: click it, Esc/right-click to cancel")


func begin_move_selected() -> bool:
	if not is_instance_valid(selected_object) or not (selected_object is Node2D):
		return false
	return begin_placement(String(selected_object.get_meta("dev_object_type", "object")), String(selected_object.get_meta("dev_content_id", "")), selected_object)


func _handle_world_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		cancel_world_action()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and placement_active:
		_update_preview(_screen_to_world((event as InputEventMouseMotion).position))
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_world_action()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var point := _screen_to_world(mb.position)
		if selection_pick_active:
			select_object_at(point)
			selection_pick_active = false
			_finish_world_pick("Spawn")
		elif placement_active:
			_confirm_placement(point)
		get_viewport().set_input_as_handled()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _snapped(point: Vector2) -> Vector2:
	return (point / placement_grid).round() * placement_grid


func _update_preview(point: Vector2) -> void:
	if placement_preview == null:
		return
	var at := _snapped(point)
	placement_preview.global_position = at
	var valid := placement_valid(at, placement_type, placement_content_id, moving_object)
	placement_preview.properties["placement_valid"] = valid
	placement_preview.modulate = Color(0.6, 1.1, 0.6, 0.75) if valid else Color(1.2, 0.45, 0.45, 0.75)
	placement_preview.queue_redraw()
	if hub != null:
		hub.call("set_placement_valid", valid, at)


func placement_valid(at: Vector2, object_type: String, content_id: String, moving: Node = null) -> bool:
	var runtime := _location_runtime()
	if runtime != null and runtime.has_method("placement_valid"):
		return bool(runtime.call("placement_valid", at, object_type, content_id))
	if object_type == "furniture":
		var shop := _shop_runtime()
		if shop == null:
			return false
		var def := ContentDatabase.get_furniture(content_id)
		if def.is_empty():
			return false
		var size_arr: Array = def.get("size", [40, 24])
		var rect := Rect2(at - Vector2(float(size_arr[0]), float(size_arr[1])) / 2.0, Vector2(float(size_arr[0]), float(size_arr[1])))
		if not shop.FURNITURE_AREA.encloses(rect.grow(2.0)):
			return false
		for inst: Dictionary in ShopFurnitureManager.layout:
			if moving is DisplayFurniture and int(inst.get("uid", 0)) == int(moving.uid):
				continue
			if rect.grow(2.0).intersects(ShopFurnitureManager.instance_rect(inst)):
				return false
		return true
	return get_tree().current_scene is Node2D


func _confirm_placement(point: Vector2) -> void:
	var at := _snapped(point)
	if not placement_valid(at, placement_type, placement_content_id, moving_object):
		log_event("Invalid placement at %s" % at)
		return
	if placement_type == "player_teleport":
		teleport_player(at)
		log_event("Teleported player to %s" % at)
	elif moving_object != null and is_instance_valid(moving_object):
		if moving_object is DisplayFurniture:
			ShopFurnitureManager.move_instance(int(moving_object.uid), at)
		(moving_object as Node2D).global_position = at
		(moving_object as Node2D).visible = true
		select_object(moving_object)
		log_event("Moved %s '%s' to %s" % [placement_type, placement_content_id, at])
	else:
		var placed := spawn_content(placement_type, placement_content_id, at)
		if placed != null:
			select_object(placed)
	_finish_world_pick("Spawn")


func cancel_world_action() -> void:
	if moving_object != null and is_instance_valid(moving_object) and moving_object is Node2D:
		(moving_object as Node2D).global_position = moving_origin
		(moving_object as Node2D).visible = true
	if placement_preview != null and is_instance_valid(placement_preview):
		placement_preview.queue_free()
	placement_preview = null
	moving_object = null
	placement_active = false
	selection_pick_active = false
	if hub != null:
		hub.call("set_world_pick_mode", false, "")
	placement_changed.emit(false)


func _finish_world_pick(tab_name: String) -> void:
	if placement_preview != null and is_instance_valid(placement_preview):
		placement_preview.queue_free()
	placement_preview = null
	moving_object = null
	placement_active = false
	if hub != null:
		hub.call("set_world_pick_mode", false, "")
		hub.call("open_hub", tab_name)
	placement_changed.emit(false)


func spawn_content(object_type: String, content_id: String, at: Vector2) -> Node:
	var placed: Node = null
	match object_type:
		"furniture":
			var shop := _shop_runtime()
			if shop != null:
				placed = shop.call("dev_spawn_furniture", content_id, at)
		"enemy":
			var dungeon := _dungeon_runtime()
			if dungeon != null:
				placed = dungeon.call("dev_spawn_enemy", content_id, at)
			else:
				var target := current_player()
				if target != null and target is Node2D:
					var mob := Enemy.new()
					get_tree().current_scene.add_child(mob)
					mob.setup(content_id, target)
					mob.global_position = at
					placed = mob
		"customer":
			var shop := _shop_runtime()
			if shop != null:
				placed = shop.call("dev_summon_customer", content_id, at)
			else:
				placed = _spawn_generic(object_type, content_id, at)
		_:
			placed = _spawn_generic(object_type, content_id, at)
	if placed != null:
		_mark_editable(placed, object_type, content_id)
		log_event("Spawned %s '%s' at %s" % [object_type, content_id, at])
	return placed


func _spawn_generic(object_type: String, content_id: String, at: Vector2) -> Node2D:
	var runtime := _location_runtime()
	if runtime != null and runtime.has_method("add_dev_object"):
		return runtime.call("add_dev_object", object_type, content_id, at, {})
	var obj := DEV_OBJECT.new() as Node2D
	get_tree().current_scene.add_child(obj)
	obj.setup(object_type, content_id)
	obj.global_position = at
	return obj


func _mark_editable(node: Node, object_type: String, content_id: String) -> void:
	node.add_to_group("dev_editable")
	node.set_meta("dev_object_type", object_type)
	node.set_meta("dev_content_id", content_id)
	node.set_meta("dev_instance_id", node.get_instance_id())


func select_object_at(point: Vector2) -> Node:
	var best: Node2D = null
	var best_distance := 36.0
	var scene := get_tree().current_scene
	for node in get_tree().get_nodes_in_group("dev_editable"):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if scene != null and not scene.is_ancestor_of(node):
			continue
		var distance := (node as Node2D).global_position.distance_to(point)
		if distance < best_distance:
			best = node
			best_distance = distance
	select_object(best)
	return best


func select_object(node: Node) -> void:
	if is_instance_valid(selected_object):
		if selected_object.has_method("set_dev_selected"):
			selected_object.call("set_dev_selected", false)
		elif selected_object is CanvasItem:
			(selected_object as CanvasItem).self_modulate = Color.WHITE
	selected_object = node
	if is_instance_valid(selected_object):
		if selected_object.has_method("set_dev_selected"):
			selected_object.call("set_dev_selected", true)
		elif selected_object is CanvasItem:
			(selected_object as CanvasItem).self_modulate = Color(1.2, 1.1, 0.65)
	selection_changed.emit(selected_object)


func selected_object_summary() -> Dictionary:
	if not is_instance_valid(selected_object):
		return {}
	var type := String(selected_object.get_meta("dev_object_type", selected_object.get_class()))
	var id := String(selected_object.get_meta("dev_content_id", ""))
	var position := Vector2.ZERO
	var rotation_value := 0.0
	if selected_object is Node2D:
		position = (selected_object as Node2D).global_position
		rotation_value = (selected_object as Node2D).rotation
	var collision := false
	if selected_object is CollisionObject2D:
		collision = (selected_object as CollisionObject2D).collision_layer != 0 or (selected_object as CollisionObject2D).collision_mask != 0
	elif selected_object.has_method("useful_properties"):
		collision = bool(selected_object.call("useful_properties").get("collision_enabled", false))
	return {
		"instance_id": selected_object.get_instance_id(), "content_id": id,
		"object_type": type, "position": [position.x, position.y],
		"rotation": rotation_value, "collision": collision,
		"properties": _useful_properties(type, id),
	}


func _useful_properties(type: String, id: String) -> Dictionary:
	if is_instance_valid(selected_object) and selected_object.has_method("useful_properties"):
		return selected_object.call("useful_properties")
	match type:
		"item": return ContentDatabase.get_item(id)
		"enemy": return ContentDatabase.get_enemy(id)
		"customer": return ContentDatabase.get_named_customer(id)
		"hero": return ContentDatabase.get_hero(id)
		"furniture": return ContentDatabase.get_furniture(id)
		"npc": return ContentDatabase.npcs.get(id, {})
	return {}


func delete_selected_object() -> bool:
	if not is_instance_valid(selected_object):
		return false
	var target := selected_object
	if target is DisplayFurniture:
		var shop := _shop_runtime()
		if shop == null or not bool(shop.call("dev_remove_furniture", int(target.uid))):
			return false
	else:
		target.queue_free()
	selected_object = null
	selection_changed.emit(null)
	log_event("Deleted runtime object")
	return true


func duplicate_selected_object() -> bool:
	if not is_instance_valid(selected_object):
		return false
	return begin_placement(String(selected_object.get_meta("dev_object_type", "object")), String(selected_object.get_meta("dev_content_id", "")))


func set_selected_position(value: Vector2) -> bool:
	if not is_instance_valid(selected_object) or not (selected_object is Node2D):
		return false
	if selected_object is DisplayFurniture:
		if not placement_valid(value, "furniture", String(selected_object.get_meta("dev_content_id", "")), selected_object):
			return false
		ShopFurnitureManager.move_instance(int(selected_object.uid), value)
	(selected_object as Node2D).global_position = value
	return true


func set_selected_rotation(value: float) -> bool:
	if not is_instance_valid(selected_object) or not (selected_object is Node2D):
		return false
	(selected_object as Node2D).rotation = value
	return true


func set_selected_collision(value: bool) -> bool:
	if not is_instance_valid(selected_object):
		return false
	if selected_object.has_method("set_collision_enabled"):
		selected_object.call("set_collision_enabled", value)
		return true
	if selected_object is CollisionObject2D:
		(selected_object as CollisionObject2D).collision_layer = 1 if value else 0
		(selected_object as CollisionObject2D).collision_mask = 1 if value else 0
		return true
	return false


func set_selected_game_property(key: String, value: String) -> bool:
	if not is_instance_valid(selected_object) or not selected_object.has_method("set_dev_property"):
		return false
	var type := String(selected_object.get_meta("dev_object_type", ""))
	var allowed := {
		"door": ["target_location"],
		"trigger": ["event_id"],
		"chest": ["reward_item_id"],
		"npc": ["dialogue_id"],
	}
	if key not in allowed.get(type, []):
		return false
	selected_object.call("set_dev_property", key, value.strip_edges())
	log_event("Set %s '%s' on selected %s" % [key, value.strip_edges(), type])
	return true


func focus_camera_on_selected() -> bool:
	if not is_instance_valid(selected_object) or not (selected_object is Node2D):
		return false
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return false
	camera.global_position = (selected_object as Node2D).global_position
	return true


func copy_selected_content_id() -> String:
	var id := String(selected_object.get_meta("dev_content_id", "")) if is_instance_valid(selected_object) else ""
	if id != "":
		DisplayServer.clipboard_set(id)
	return id


func source_path_for_selected() -> String:
	if not is_instance_valid(selected_object):
		return ""
	match String(selected_object.get_meta("dev_object_type", "")):
		"item": return ProjectSettings.globalize_path("res://data/items.json")
		"enemy": return ProjectSettings.globalize_path("res://data/enemies.json")
		"customer": return ProjectSettings.globalize_path("res://data/customers.json")
		"hero", "npc": return ProjectSettings.globalize_path("res://data/heroes.json")
		"furniture": return ProjectSettings.globalize_path("res://data/shop_furniture.json")
	return ""


func open_selected_source() -> String:
	var path := source_path_for_selected()
	if path != "" and not DisplayServer.get_name().contains("headless"):
		OS.shell_open(path)
	return path


func current_player() -> Node:
	var scene := get_tree().current_scene
	for node in get_tree().get_nodes_in_group("dev_player"):
		if is_instance_valid(node) and (scene == null or scene.is_ancestor_of(node)):
			return node
	return null


func select_active_hero(hero_id: String) -> bool:
	var dungeon := _dungeon_runtime()
	if dungeon != null:
		return bool(dungeon.call("dev_select_hero", hero_id))
	return false


func heal_player() -> bool:
	var player := current_player()
	if player == null or player.get("health") == null:
		return false
	player.health.heal(player.health.max_hp)
	return true


func revive_player() -> bool:
	var player := current_player()
	if player == null or player.get("health") == null:
		return false
	player.health.revive(1.0)
	return true


func set_player_speed(multiplier: float) -> bool:
	var player := current_player()
	if player is TownPlayer:
		(player as TownPlayer).set_dev_speed_multiplier(multiplier)
		return true
	if player is CombatHero:
		(player as CombatHero).movement.max_speed = float((player as CombatHero).stats.get("spd", 120)) * multiplier
		return true
	return false


func set_player_collision(value: bool) -> bool:
	var player := current_player()
	if player is TownPlayer:
		(player as TownPlayer).set_dev_collision_enabled(value)
		return true
	if player is CollisionObject2D:
		(player as CollisionObject2D).collision_layer = 2 if value else 0
		(player as CollisionObject2D).collision_mask = 1 if value else 0
		return true
	return false


func teleport_player(at: Vector2) -> bool:
	var player := current_player()
	if player == null or not (player is Node2D):
		return false
	(player as Node2D).global_position = at
	return true


func teleport_player_to_marker(marker_type: String) -> bool:
	var runtime := _location_runtime()
	if runtime == null:
		return false
	var points := LocationLoader.markers_of(runtime.location_root, marker_type)
	return not points.is_empty() and teleport_player(points[0])


func grant_equipment(hero_id: String, item_id: String) -> bool:
	var item := ContentDatabase.get_item(item_id)
	if item.is_empty():
		return false
	var category := String(item.get("category", ""))
	var slot := "weapon" if category == "weapon" else ("armor" if category == "armor" else String(item.get("slot", "accessory")))
	InventoryManager.add_item(item_id)
	return InventoryManager.equip(hero_id, slot, item_id)


func clear_equipment(hero_id: String) -> void:
	for slot in ["weapon", "armor", "accessory", "charm"]:
		InventoryManager.equip(hero_id, slot, "")


func reset_player_state() -> void:
	heal_player()
	revive_player()
	set_player_speed(1.0)
	set_player_collision(true)


func change_money(delta: int) -> void:
	if delta >= 0:
		EconomyManager.add_gold(delta)
	else:
		EconomyManager.spend_gold(mini(-delta, EconomyManager.gold))
	log_event("Development money change %+d; total %d" % [delta, EconomyManager.gold])


func change_inventory(item_id: String, delta: int) -> bool:
	if ContentDatabase.get_item(item_id).is_empty():
		return false
	if delta >= 0:
		InventoryManager.add_item(item_id, delta)
		return true
	return InventoryManager.remove_item(item_id, mini(-delta, InventoryManager.count(item_id)))


func set_day_and_period(day: int, period: int) -> void:
	TimeManager.day = clampi(day, 1, maxi(1, TimeManager.campaign_days()))
	TimeManager.period = clampi(period, 0, TimeManager.periods_per_day() - 1)
	TimeManager.chapter = clampi(((TimeManager.day - 1) / TimeManager.chapter_len()) + 1, 1, 8)
	log_event("Set development time to day %d %s" % [TimeManager.day, TimeManager.period_name()])


func set_relationship_level(content_id: String, level: int) -> void:
	var cfg: Dictionary = ContentDatabase.bal("friendship", {})
	var per := int(cfg.get("points_per_level", 10))
	RelationshipManager.relationships[content_id] = maxi(0, level) * per
	RelationshipManager.relationship_changed.emit(content_id, RelationshipManager.level(content_id))


func complete_bridge_development(world_id: String) -> bool:
	if not BridgeManager.gates.has(world_id):
		return false
	BridgeManager.gates[world_id] = {"shard": true, "paid": true, "repaired": true}
	BridgeManager.gate_repaired.emit(world_id)
	log_event("Marked bridge '%s' repaired in current development state" % world_id)
	return true


func reset_current_chapter() -> void:
	TimeManager.reset(TimeManager.chapter)
	var world := ContentDatabase.world_for_chapter(TimeManager.chapter)
	var id := String(world.get("id", ""))
	if BridgeManager.gates.has(id):
		BridgeManager.gates[id] = {"shard": false, "paid": false, "repaired": false}
	log_event("Reset chapter %d in development state" % TimeManager.chapter)


func ensure_dev_campaign(reset: bool = false) -> void:
	isolated_dev_state_active = true
	if GameState.campaign_active and not reset:
		return
	GameState.reset_campaign()
	GameState.current_slot = 0
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	BoomManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	ShopFurnitureManager.reset()
	log_event("Initialized in-memory development campaign (no normal save slot)")


func play_from_title() -> void:
	selected_location = ""
	SceneRouter.go("main_menu", {"development": true})


func play_from_shop() -> void:
	ensure_dev_campaign()
	selected_location = "crossroads_shop"
	SceneRouter.go("shop", {"development": true})


func play_kingdom_hearts_dungeon() -> void:
	ensure_dev_campaign()
	selected_world = "kingdom_hearts"
	selected_location = "kingdom_hearts_dungeon"
	DungeonManager.plan_expedition("kingdom_hearts", "sora", ["kh_potion", "kh_potion"])
	SceneRouter.go("dungeon", {"development": true})


func run_kingdom_hearts_full_loop() -> void:
	ensure_dev_campaign(true)
	selected_world = "kingdom_hearts"
	selected_location = "crossroads_town"
	EconomyManager.add_gold(10000)
	for id in ContentDatabase.get_world("kingdom_hearts").get("market_goods", []):
		InventoryManager.add_item(String(id), 3)
	SceneRouter.go("town", {"development": true, "full_loop": "kingdom_hearts"})
	log_event("Started Kingdom Hearts full-loop development setup from town")


func restart_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		log_event("Restarting scene %s" % scene.scene_file_path)
		get_tree().call_deferred("reload_current_scene")


func fill_inventory_for_selected_world(qty: int = 5) -> void:
	for id in ContentDatabase.get_world(selected_world).get("market_goods", []):
		InventoryManager.add_item(String(id), qty)
	log_event("Filled inventory with %s test goods" % selected_world)


func clear_displays() -> void:
	for i in range(InventoryManager.display.size()):
		InventoryManager.take_display(i)


func save_dev_state(include_game_state: bool = true) -> bool:
	if not enabled:
		return false
	if include_game_state:
		save_current_location_layout_if_runtime()
	var doc := {
		"schema": "crossroads.live_dev_state.v1",
		"timestamp": Time.get_datetime_string_from_system(),
		"selected_world": selected_world, "selected_location": selected_location,
		"temporary_world_unlocks": temporary_world_unlocks,
		"dev_locations": dev_locations,
		"request": dev_request,
	}
	if include_game_state:
		doc["game"] = current_state_snapshot()
	var ok := _write_json(DEV_STATE_PATH, doc)
	if ok:
		log_event("Saved separate development state to %s" % DEV_STATE_PATH)
	return ok


func save_current_location_layout_if_runtime() -> void:
	var runtime := _location_runtime()
	if runtime != null and selected_location != "":
		var loc := current_location_data().duplicate(true)
		loc["objects"] = runtime.call("serialize_dev_objects")
		dev_locations[selected_location] = loc


func load_dev_state(apply_game_state: bool = true) -> bool:
	var doc := _read_json(DEV_STATE_PATH)
	if doc.is_empty():
		return false
	_apply_dev_metadata(doc)
	if apply_game_state and doc.get("game", {}) is Dictionary:
		apply_state_snapshot(doc["game"])
	log_event("Loaded separate development state from %s" % DEV_STATE_PATH)
	return true


func current_state_snapshot() -> Dictionary:
	return {
		"scene": current_scene_name(), "world": selected_world,
		"location": current_location_id(), "day": TimeManager.day,
		"period": TimeManager.period, "period_name": TimeManager.period_name(),
		"chapter": TimeManager.chapter, "gold": EconomyManager.gold,
		"game_state": GameState.to_save(), "time": TimeManager.to_save(),
		"economy": EconomyManager.to_save(), "market": MarketManager.to_save(),
		"inventory": InventoryManager.to_save(), "relationships": RelationshipManager.to_save(),
		"bridge": BridgeManager.to_save(), "boom": BoomManager.to_save(), "story": StoryEventManager.to_save(),
		"furniture": ShopFurnitureManager.to_save(),
		"temporary_world_unlocks": temporary_world_unlocks,
		"selected_object": selected_object_summary(),
	}


func apply_state_snapshot(snapshot: Dictionary) -> void:
	GameState.from_save(snapshot.get("game_state", {}))
	TimeManager.from_save(snapshot.get("time", {}))
	EconomyManager.from_save(snapshot.get("economy", {}))
	MarketManager.from_save(snapshot.get("market", {}))
	InventoryManager.from_save(snapshot.get("inventory", {}))
	RelationshipManager.from_save(snapshot.get("relationships", {}))
	BridgeManager.from_save(snapshot.get("bridge", {}))
	BoomManager.from_save(snapshot.get("boom", {}))
	StoryEventManager.from_save(snapshot.get("story", {}))
	ShopFurnitureManager.from_save(snapshot.get("furniture", {}))
	temporary_world_unlocks.clear()
	for world_id in snapshot.get("temporary_world_unlocks", []):
		temporary_world_unlocks.append(String(world_id))


func start_playtest_session() -> bool:
	playtest_active = true
	playtest_started_at = Time.get_datetime_string_from_system()
	playtest_notes.clear()
	_clear_workspace_dir(PLAYTEST_DIR)
	log_event("Started playtest session at %s" % playtest_started_at)
	return capture_playtest_state()


func add_playtest_note(category: String, text: String) -> bool:
	if not playtest_active or text.strip_edges() == "":
		return false
	playtest_notes.append({"time": Time.get_time_string_from_system(), "category": category, "text": text.strip_edges(), "scene": current_scene_name(), "location": current_location_id()})
	_write_playtest_notes()
	log_event("Playtest note [%s]: %s" % [category, text.strip_edges()])
	return true


func capture_playtest_state() -> bool:
	_ensure_workspace_dir(PLAYTEST_DIR)
	var ok := _write_workspace_json(PLAYTEST_DIR + "/state_snapshot.json", current_state_snapshot())
	last_validation = run_content_validation()
	ok = _write_workspace_json(PLAYTEST_DIR + "/validation_report.json", {"generated": Time.get_datetime_string_from_system(), "results": last_validation}) and ok
	ok = _write_workspace_text(PLAYTEST_DIR + "/runtime_log.txt", "\n".join(combined_recent_logs(300))) and ok
	_write_playtest_notes()
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png(_workspace_absolute(PLAYTEST_DIR + "/screenshot.png"))
	log_event("Captured playtest state")
	return ok


func end_playtest_session() -> bool:
	if not playtest_active:
		return false
	var ok := capture_playtest_state()
	playtest_active = false
	log_event("Ended playtest session")
	return ok


func _write_playtest_notes() -> bool:
	var lines: Array[String] = ["# Live Playtest Notes", "", "- Started: %s" % playtest_started_at, "- Build scene: `%s`" % current_scene_name(), "- World/location: `%s` / `%s`" % [selected_world, current_location_id()], ""]
	if playtest_notes.is_empty():
		lines.append("No notes recorded yet.")
	else:
		for row: Dictionary in playtest_notes:
			lines.append("- **%s — %s** (`%s`, `%s`): %s" % [String(row.get("category", "note")), String(row.get("time", "")), String(row.get("scene", "")), String(row.get("location", "")), String(row.get("text", ""))])
	return _write_workspace_text(PLAYTEST_DIR + "/playtest_notes.md", "\n".join(lines) + "\n")


func export_ai_context(request_text: String = "") -> bool:
	dev_request = request_text
	_clear_workspace_dir(AI_DIR)
	last_validation = run_content_validation()
	var state := current_state_snapshot()
	var location := current_location_data()
	var available := available_content_summary()
	var status := status_data()
	var context_lines: Array[String] = [
		"# Crossroads Live AI Context", "",
		"Generated: %s" % Time.get_datetime_string_from_system(),
		"Current scene: `%s`" % current_scene_name(),
		"Selected world: `%s`" % selected_world,
		"Selected location: `%s`" % selected_location, "",
		"## Current vertical-slice goal", "", String(status.get("vertical_slice_goal", "Not recorded")), "",
		"## Selected runtime object", "", "```json", JSON.stringify(selected_object_summary(), "  "), "```", "",
		"## Unresolved validation", "", "%d validation rows; see `VALIDATION_REPORT.json`." % last_validation.size(), "",
		"## Next task", "", String((status.get("next_tasks", ["Review the current build"]) as Array)[0]), "",
		"Follow `AI_PARTNER.md`. Prefer the smallest playable improvement and preserve normal saves.",
	]
	var ok := _write_workspace_text(AI_DIR + "/PROJECT_CONTEXT.md", "\n".join(context_lines) + "\n")
	ok = _write_workspace_json(AI_DIR + "/CURRENT_STATE.json", state) and ok
	ok = _write_workspace_json(AI_DIR + "/SELECTED_LOCATION.json", location) and ok
	ok = _write_workspace_json(AI_DIR + "/AVAILABLE_CONTENT.json", available) and ok
	ok = _write_workspace_json(AI_DIR + "/VALIDATION_REPORT.json", {"generated": Time.get_datetime_string_from_system(), "results": last_validation}) and ok
	var notes_source := _workspace_absolute(PLAYTEST_DIR + "/playtest_notes.md")
	var notes := _read_text(notes_source) if FileAccess.file_exists(notes_source) else _read_text("res://PLAYTEST_NOTES.md")
	ok = _write_workspace_text(AI_DIR + "/PLAYTEST_NOTES.md", notes) and ok
	ok = _write_workspace_text(AI_DIR + "/REQUEST.md", request_text.strip_edges() + "\n") and ok
	log_event("Exported AI context to %s" % _workspace_absolute(AI_DIR))
	return ok


func copy_claude_prompt() -> String:
	var prompt := "Read AI_PARTNER.md and everything in ai_workspace/current/. Review the current state, propose the smallest playable improvement, list the files you intend to change, then implement and test it."
	DisplayServer.clipboard_set(prompt)
	return prompt


func available_content_summary() -> Dictionary:
	return {
		"worlds": _sorted_keys(ContentDatabase.worlds),
		"items": _sorted_keys(ContentDatabase.items),
		"customers": _sorted_keys(ContentDatabase.named_customers),
		"heroes": _sorted_keys(ContentDatabase.heroes),
		"enemies": _sorted_keys(ContentDatabase.enemies),
		"bosses": _sorted_keys(ContentDatabase.bosses),
		"furniture": _sorted_keys(ContentDatabase.furniture),
		"npcs": _sorted_keys(ContentDatabase.npcs),
		"locations": _sorted_keys(all_locations()),
	}


func run_content_validation() -> Array[Dictionary]:
	var scan := CCSContentScan.new()
	scan.scan()
	return CCSValidator.run(scan)


func validation_for_world(world_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in run_content_validation():
		var id := String(row.get("id", ""))
		var path := String(row.get("path", ""))
		if path.contains("/%s/" % world_id) or _content_belongs_to_world(id, world_id):
			out.append(row)
	return out


func _content_belongs_to_world(id: String, world_id: String) -> bool:
	for table in [ContentDatabase.items, ContentDatabase.heroes, ContentDatabase.enemies, ContentDatabase.bosses, ContentDatabase.named_customers, all_locations()]:
		if table.has(id) and String((table[id] as Dictionary).get("world", "")) == world_id:
			return true
	return false


func log_event(message: String, level: String = "INFO") -> void:
	var line := "%s [%s] %s" % [Time.get_time_string_from_system(), level, message]
	recent_log.append(line)
	while recent_log.size() > LOG_LIMIT:
		recent_log.pop_front()
	log_added.emit(line)
	print("[DevHub] " + line)


func combined_recent_logs(limit: int = 150) -> Array[String]:
	var out: Array[String] = []
	out.append_array(DebugManager.recent_lines(limit))
	out.append_array(_godot_log_tail(limit))
	out.append_array(recent_log)
	var start := maxi(0, out.size() - limit)
	return out.slice(start)


func clear_visible_log() -> void:
	recent_log.clear()
	log_event("Visible Dev Hub log cleared; source logs were not deleted")


func _godot_log_tail(limit: int) -> Array[String]:
	var path := "user://logs/godot.log"
	if not FileAccess.file_exists(path):
		return []
	var lines := _read_text(path).split("\n")
	var start := maxi(0, lines.size() - limit)
	var out: Array[String] = []
	for i in range(start, lines.size()):
		if String(lines[i]).strip_edges() != "":
			out.append(String(lines[i]))
	return out


func _on_scene_transition(scene_key: String, path: String, ctx: Dictionary) -> void:
	log_event("Scene transition: %s -> %s context=%s" % [scene_key, path, JSON.stringify(ctx)])


func _on_save_event(slot_name: String, verb: String) -> void:
	log_event("Normal SaveManager %s: %s" % [verb, slot_name], "SAVE")


func _on_load_event(slot_name: String, verb: String) -> void:
	log_event("Normal SaveManager %s: %s" % [verb, slot_name], "SAVE")


func _on_missing_asset(kind: String, content_id: String, expected: String) -> void:
	log_event("Missing %s asset '%s'; placeholder used (%s)" % [kind, content_id, expected], "WARNING")


func _shop_runtime() -> Node:
	return _first_current_group("shop_runtime")


func _dungeon_runtime() -> Node:
	return _first_current_group("dungeon_runtime")


func _location_runtime() -> Node:
	return _first_current_group("location_runtime")


func _first_current_group(group_name: String) -> Node:
	var scene := get_tree().current_scene
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node) and (scene == null or node == scene or scene.is_ancestor_of(node)):
			return node
	return null


func _load_dev_metadata() -> void:
	var doc := _read_json(DEV_STATE_PATH)
	if not doc.is_empty():
		_apply_dev_metadata(doc)


func _apply_dev_metadata(doc: Dictionary) -> void:
	selected_world = String(doc.get("selected_world", DEFAULT_WORLD))
	selected_location = String(doc.get("selected_location", ""))
	temporary_world_unlocks.clear()
	for world_id in doc.get("temporary_world_unlocks", []):
		temporary_world_unlocks.append(String(world_id))
	dev_locations = doc.get("dev_locations", {})
	dev_request = String(doc.get("request", ""))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		log_event("Could not write %s" % path, "ERROR")
		return false
	file.store_string(JSON.stringify(data, "  "))
	return true


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.open(path, FileAccess.READ).get_as_text()


func _write_text_absolute(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


func _workspace_absolute(relative: String) -> String:
	return ProjectSettings.globalize_path("res://" + relative)


func _ensure_workspace_dir(relative: String) -> void:
	DirAccess.make_dir_recursive_absolute(_workspace_absolute(relative))


func _clear_workspace_dir(relative: String) -> void:
	_ensure_workspace_dir(relative)
	var dir := DirAccess.open(_workspace_absolute(relative))
	if dir == null:
		return
	for name in dir.get_files():
		if name != ".gitkeep":
			DirAccess.remove_absolute(_workspace_absolute(relative + "/" + name))


func _write_workspace_text(relative: String, text: String) -> bool:
	return _write_text_absolute(_workspace_absolute(relative), text)


func _write_workspace_json(relative: String, data: Dictionary) -> bool:
	return _write_workspace_text(relative, JSON.stringify(data, "  "))


func _sorted_keys(table: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in table.keys():
		out.append(String(key))
	out.sort()
	return out
