extends Node
## Headless proof that every supplied barrier block is mapped to its matching
## dungeon and stamped for both horizontal and vertical obstacle runs.

const EXPECTED := {
	"mario": ["res://assets/locations/mariodungeon/barrierblock.png", Vector2i(30, 64)],
	"final_fantasy": ["res://assets/locations/ffdungeon/processed/barrier_block.png", Vector2i(16, 23)],
	"zelda": ["res://assets/locations/zeldadungeon/processed/barrier_block.png", Vector2i(16, 17)],
	"naruto": ["res://assets/locations/narutodungeon/processed/barrier_block.png", Vector2i(26, 26)],
	"dragon_ball": ["res://assets/locations/dbzdungeon/processed/barrier_rock.png", Vector2i(28, 28)],
	"pokemon": ["res://assets/locations/pkmndungeon/processed/barrier_boulder.png", Vector2i(32, 32)],
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
		var holder := StaticBody2D.new()
		add_child(holder)
		var stamped: bool = dungeon.call(
			"_stamp_props", holder, size, world, Vector2(17, 29), true)
		_check(stamped, "%s failed to stamp a %s run" % [world_id, size])
		var sprites := holder.get_children().filter(func(child: Node) -> bool: return child is Sprite2D)
		var shapes := holder.get_children().filter(func(child: Node) -> bool:
			return child is CollisionShape2D)
		_check(not sprites.is_empty(), "%s stamped no sprites for %s" % [world_id, size])
		_check(shapes.size() == sprites.size(),
			"%s stamped %d sprites but %d fitted colliders for %s" % [
				world_id, sprites.size(), shapes.size(), size])
		for sprite: Sprite2D in sprites:
			_check(sprite.texture == texture, "%s stamped an unexpected barrier texture" % world_id)
		for i in range(mini(sprites.size(), shapes.size())):
			var sprite := sprites[i] as Sprite2D
			var shape := shapes[i] as CollisionShape2D
			var rect := shape.shape as RectangleShape2D
			var used := texture.get_image().get_used_rect()
			var expected_collision_size := Vector2(used.size) * sprite.scale.abs()
			var expected_center := sprite.position + (
				Vector2(used.position) + Vector2(used.size) * 0.5
				- texture.get_size() * 0.5) * sprite.scale
			_check(rect != null and rect.size.is_equal_approx(expected_collision_size),
				"%s collider %d size %s does not match visible %s" % [
					world_id, i, rect.size if rect != null else Vector2.ZERO,
					expected_collision_size])
			_check(shape.position.is_equal_approx(expected_center),
				"%s collider %d center %s does not match visible %s" % [
					world_id, i, shape.position, expected_center])
		holder.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
