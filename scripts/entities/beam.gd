class_name Beam
extends Node2D
## Sustained beam special (Special Beam Cannon / Kamehameha): muzzle sprite at
## the caster's hands, a texture-repeated shaft that extends to full range,
## and a traveling tip. Damages each hurtbox along the line once.

const GROW_TIME := 0.15
const HOLD_TIME := 0.4
const FADE_TIME := 0.15

var packet: Dictionary = {}
var beam_range: float = 180.0
var half_width: float = 5.0
var target_layer: int = 0
var _age: float = 0.0
var _hit: Array[Node] = []
var _shaft: Sprite2D
var _tip: Sprite2D
var _shaft_h: float = 8.0


func setup(damage_packet: Dictionary, direction: Vector2, sp: Dictionary, layer: int) -> void:
	packet = damage_packet
	target_layer = layer
	beam_range = float(sp.get("range", 180))
	half_width = float(sp.get("width", 10)) * 0.5
	rotation = direction.angle()
	for part: Array in [["muzzle", 0], ["shaft", 1], ["tip", 2]]:
		var tex_path := String(sp.get(part[0], ""))
		var tex: Texture2D = load(tex_path) if tex_path != "" and ResourceLoader.exists(tex_path) else \
			PlaceholderFactory.flat_texture(Color(1.0, 0.85, 0.3), 8, 8)
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		add_child(s)
		match int(part[1]):
			0:
				s.position = Vector2.ZERO
			1:
				_shaft = s
				_shaft.region_enabled = true
				_shaft_h = tex.get_height()
			2:
				_tip = s
	_apply_length(0.0)


func _apply_length(l: float) -> void:
	_shaft.region_rect = Rect2(0, 0, maxf(l, 1.0), _shaft_h)
	_shaft.position = Vector2(l * 0.5, 0)
	_tip.position = Vector2(l, 0)
	_tip.visible = l > 4.0


func _physics_process(delta: float) -> void:
	_age += delta
	var l := beam_range * clampf(_age / GROW_TIME, 0.0, 1.0)
	_apply_length(l)
	if _age > GROW_TIME + HOLD_TIME:
		var fade := 1.0 - (_age - GROW_TIME - HOLD_TIME) / FADE_TIME
		modulate.a = maxf(fade, 0.0)
		if fade <= 0.0:
			queue_free()
			return
	_damage_line(l)


func _damage_line(l: float) -> void:
	var dir := Vector2.RIGHT.rotated(global_rotation)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy in _hit:
			continue
		# the beam fires from the caster's chest; enemy.global_position is their
		# FEET, so aim at the body center (feet - hit_radius) and widen the
		# perpendicular tolerance by the body half-height, or tall/short enemies
		# standing right in the beam get skipped
		var hr: float = float(enemy.get("hit_radius")) if enemy.get("hit_radius") != null else 12.0
		var rel := (enemy.global_position - Vector2(0.0, hr)) - global_position
		var along := rel.dot(dir)
		if along < 0.0 or along > l:
			continue
		# generous vertical band: the beam leaves the chest but enemies stand on
		# the ground at varying heights, so add a fixed slack (~the chest offset)
		# on top of the body half-height, or short enemies slip under the beam
		if absf(rel.cross(dir)) <= half_width + hr + 24.0:
			_hit.append(enemy)
			if enemy.has_method("take_packet"):
				enemy.take_packet(packet, global_position)
			FX.burst(get_parent(), enemy.global_position, Color(1.0, 0.8, 0.4), 8)
