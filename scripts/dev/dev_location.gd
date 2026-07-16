class_name DevRuntimeLocation
extends Node2D
## Runtime host for Asset-Factory locations and user:// development locations.
## Normal campaign scenes are unchanged; this scene exists only for direct
## construction and playtesting through the Live Developer Hub.

const DEV_OBJECT_SCRIPT := preload("res://scripts/dev/dev_placed_object.gd")
const WORKSHOP_BRIDGE := preload("res://scripts/dev/location_workshop_bridge.gd")

var location_data: Dictionary = {}
var location_root: Node2D
var player: TownPlayer
var bounds := Rect2(0, 0, 640, 360)


func _ready() -> void:
	add_to_group("location_runtime")
	var workshop_location_id := WORKSHOP_BRIDGE.consume_launch()
	if workshop_location_id != "":
		DevHubManager.ensure_dev_campaign()
		DevHubManager.select_location(workshop_location_id)
	location_data = DevHubManager.current_location_data()
	if location_data.is_empty():
		location_data = DevHubManager.blank_location("scratch_location")
	var cell := int(location_data.get("tile_size", 16))
	bounds = Rect2(0, 0, int(location_data.get("width", 40)) * cell, int(location_data.get("height", 22)) * cell)
	_build_location()
	_spawn_player()
	DevHubManager.restore_location_objects(self)
	DevHubManager.log_event("Loaded development location '%s'" % String(location_data.get("id", "unknown")))


func _build_location() -> void:
	location_root = LocationLoader.build(location_data)
	if location_root != null:
		add_child(location_root)
	var bg := Polygon2D.new()
	bg.name = "DevelopmentBackdrop"
	bg.polygon = PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	var world := ContentDatabase.get_world(String(location_data.get("world", DevHubManager.selected_world)))
	bg.color = Color(String(world.get("floor_color", "#34384f")))
	bg.z_index = -50
	add_child(bg)
	_build_boundaries()


func _build_boundaries() -> void:
	for spec: Array in [
		[Vector2(bounds.size.x / 2.0, -4), Vector2(bounds.size.x, 8)],
		[Vector2(bounds.size.x / 2.0, bounds.size.y + 4), Vector2(bounds.size.x, 8)],
		[Vector2(-4, bounds.size.y / 2.0), Vector2(8, bounds.size.y)],
		[Vector2(bounds.size.x + 4, bounds.size.y / 2.0), Vector2(8, bounds.size.y)],
	]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.position = spec[0]
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = spec[1]
		shape.shape = rect
		body.add_child(shape)
		add_child(body)


func _spawn_player() -> void:
	player = TownPlayer.new()
	var spawn := bounds.get_center()
	for marker: Dictionary in location_data.get("markers", []):
		if String(marker.get("type", "")) == "player_spawn":
			var cell := int(location_data.get("tile_size", 16))
			spawn = Vector2((int(marker.get("x", 0)) + 0.5) * cell, (int(marker.get("y", 0)) + 0.5) * cell)
			break
	player.position = spawn
	add_child(player)
	var camera := Camera2D.new()
	camera.zoom = Vector2(1.25, 1.25)
	player.add_child(camera)


func placement_valid(at: Vector2, _object_type: String, _content_id: String) -> bool:
	if not bounds.grow(-12.0).has_point(at):
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func add_dev_object(object_type: String, content_id: String, at: Vector2, properties: Dictionary = {}) -> Node2D:
	var obj := DEV_OBJECT_SCRIPT.new() as Node2D
	add_child(obj)
	obj.setup(object_type, content_id, properties)
	obj.position = at
	return obj


func clear_dev_objects() -> void:
	for obj in get_tree().get_nodes_in_group("dev_editable"):
		if obj is Node and obj.get_script() == DEV_OBJECT_SCRIPT and is_ancestor_of(obj):
			obj.queue_free()


func serialize_dev_objects() -> Array:
	var out: Array = []
	for obj in get_tree().get_nodes_in_group("dev_editable"):
		if obj is Node and obj.get_script() == DEV_OBJECT_SCRIPT and is_ancestor_of(obj):
			out.append(obj.call("serialize_dev_object"))
	return out
