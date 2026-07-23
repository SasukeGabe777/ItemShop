class_name Projectile
extends Area2D
## Simple projectile used by hero specials and shooter enemies.

var velocity: Vector2 = Vector2.ZERO
var packet: Dictionary = {}
var lifetime: float = 2.0


func setup(damage_packet: Dictionary, direction: Vector2, speed: float, color: Color, target_layer: int, texture: Texture2D = null) -> void:
	packet = damage_packet
	velocity = direction.normalized() * speed
	collision_layer = 0
	collision_mask = target_layer | 1  # target hurtboxes + walls
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = texture if texture != null else PlaceholderFactory.flat_texture(color, 6, 6)
	add_child(sprite)
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)


## Real projectile art from a strip sheet (move_VFX drop): direction rows,
## animated columns. Replaces the flat placeholder sprite.
var _anim_sprite: Sprite2D
var _anim_hframes: int = 1
var _anim_row: int = 0
var _anim_fps: float = 12.0
var _anim_age: float = 0.0


func set_art(sheet: String, hframes: int, vframes: int, row: int, fps: float = 12.0) -> void:
	if not ResourceLoader.exists(sheet):
		return
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	_anim_sprite = Sprite2D.new()
	_anim_sprite.texture = load(sheet)
	_anim_sprite.hframes = hframes
	_anim_sprite.vframes = vframes
	_anim_hframes = hframes
	_anim_row = clampi(row, 0, vframes - 1)
	_anim_fps = fps
	_anim_sprite.frame = _anim_row * hframes
	add_child(_anim_sprite)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if _anim_sprite != null and _anim_hframes > 1:
		_anim_age += delta
		_anim_sprite.frame = _anim_row * _anim_hframes + (int(_anim_age * _anim_fps) % _anim_hframes)
	if lifetime <= 0.0:
		queue_free()


func _on_area(area: Area2D) -> void:
	if area is HurtboxComponent:
		(area as HurtboxComponent).receive(packet, global_position)
		FX.burst(get_parent(), global_position, Color(1, 1, 0.7), 5)
		queue_free()


func _on_body(_body: Node) -> void:
	queue_free()
