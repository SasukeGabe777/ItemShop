class_name Projectile
extends Area2D
## Simple projectile used by hero specials and shooter enemies.

var velocity: Vector2 = Vector2.ZERO
var packet: Dictionary = {}
var lifetime: float = 2.0


func setup(damage_packet: Dictionary, direction: Vector2, speed: float, color: Color, target_layer: int) -> void:
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
	sprite.texture = PlaceholderFactory.flat_texture(color, 6, 6)
	add_child(sprite)
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area(area: Area2D) -> void:
	if area is HurtboxComponent:
		(area as HurtboxComponent).receive(packet, global_position)
		FX.burst(get_parent(), global_position, Color(1, 1, 0.7), 5)
		queue_free()


func _on_body(_body: Node) -> void:
	queue_free()
