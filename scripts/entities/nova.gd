class_name Nova
extends Node2D
## Self-centered AOE special (Pikachu's Discharge, Charmander's Fire Spin):
## plays a ring-effect frame strip once around the caster and damages each
## enemy inside the radius once. Frames come from the special's "sheet"
## (a horizontal strip; "frames" columns) — the user-supplied PMD effect rips.

var packet: Dictionary = {}
var radius: float = 44.0
var _sprite: Sprite2D
var _frames: int = 1
var _fps: float = 12.0
var _age: float = 0.0
var _hit: Array[Node] = []


func setup(damage_packet: Dictionary, sp: Dictionary) -> void:
	packet = damage_packet
	radius = float(sp.get("radius", 44))
	_fps = float(sp.get("fps", 12))
	_sprite = Sprite2D.new()
	var tex_path := String(sp.get("sheet", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
		_frames = maxi(int(sp.get("frames", 1)), 1)
		_sprite.hframes = _frames
	else:
		_sprite.texture = PlaceholderFactory.flat_texture(Color(1.0, 0.9, 0.4), 16, 16)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_age += delta
	var f := int(_age * _fps)
	if f >= _frames:
		queue_free()
		return
	_sprite.frame = f
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy in _hit:
			continue
		if enemy.global_position.distance_to(global_position) <= radius:
			_hit.append(enemy)
			if enemy.has_method("take_packet"):
				enemy.take_packet(packet, global_position)
			FX.burst(get_parent(), enemy.global_position, Color(1.0, 0.9, 0.5), 8)
