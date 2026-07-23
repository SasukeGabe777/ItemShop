extends Node
## Headless proof that every supplied barrier block is mapped to its matching
## dungeon and stamped for both horizontal and vertical obstacle runs.

const EXPECTED := {
	"mario": ["res://assets/locations/mariodungeon/barrierblock.png", Vector2i(30, 64)],
	"final_fantasy": ["res://assets/locations/ffdungeon/processed/barrier_block.png", Vector2i(16, 23)],
	"zelda": ["res://assets/locations/zeldadungeon/processed/barrier_block.png", Vector2i(16, 17)],
	"naruto": ["res://assets/locations/narutodungeon/processed/barrier_block.png", Vector2i(26, 26)],
	"dragon_ball": ["res://assets/locations/dbzdungeon/processed/barrier_rock.png", Vector2i(28, 28)],
}

var failures: Array[String] = []


func _ready() -> void:
	var dungeon_script: Script = load("res://scripts/dungeon/dungeon.gd")
	var dungeon = dungeon_script.new()
	for world_id: String in EXPECTED:
		_check_world(dungeon, world_id)
	dungeon.free()
	if failures.is_empty():
		print("BARRIER_BLOCKS_PROBE_PASS")
	else:
		for message in failures:
			printerr("BARRIER_BLOCKS_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_world(dungeon: Node, world_id: String) -> void:
	var expected_path := String(EXPECTED[world_id][0])
	var expected_size: Vector2i = EXPECTED[world_id][1]
	var world := ContentDatabase.get_world(world_id)
	var barriers: Dictionary = world.get("barriers", {})
	for axis in ["h", "v"]:
		var paths: Array = barriers.get(axis, [])
		_check(paths == [expected_path], "%s %s barrier mapping is %s" % [world_id, axis, paths])
	var texture: Texture2D = load(expected_path) if ResourceLoader.exists(expected_path) else null
	_check(texture != null, "%s barrier texture does not load" % world_id)
	if texture == null:
		return
	_check(Vector2i(texture.get_width(), texture.get_height()) == expected_size,
		"%s barrier is %dx%d, expected cleaned %dx%d" % [world_id,
			texture.get_width(), texture.get_height(), expected_size.x, expected_size.y])
	for size in [Vector2(96, 32), Vector2(32, 96)]:
		var holder := Node2D.new()
		add_child(holder)
		var stamped: bool = dungeon.call("_stamp_props", holder, size, world, Vector2(17, 29))
		_check(stamped, "%s failed to stamp a %s run" % [world_id, size])
		var sprites := holder.get_children().filter(func(child: Node) -> bool: return child is Sprite2D)
		_check(not sprites.is_empty(), "%s stamped no sprites for %s" % [world_id, size])
		for sprite: Sprite2D in sprites:
			_check(sprite.texture == texture, "%s stamped an unexpected barrier texture" % world_id)
		holder.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
