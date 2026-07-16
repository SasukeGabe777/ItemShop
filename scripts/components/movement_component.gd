class_name MovementComponent
extends Node
## Velocity helper with acceleration, knockback and dash support for
## CharacterBody2D owners.

@export var max_speed: float = 120.0
@export var acceleration: float = 900.0
var knockback_velocity: Vector2 = Vector2.ZERO
var dash_velocity: Vector2 = Vector2.ZERO
var dash_time_left: float = 0.0


func apply(body: CharacterBody2D, wish_dir: Vector2, delta: float) -> void:
	var target := wish_dir.normalized() * max_speed
	if dash_time_left > 0.0:
		dash_time_left -= delta
		body.velocity = dash_velocity
	else:
		body.velocity = body.velocity.move_toward(target, acceleration * delta)
	if knockback_velocity.length() > 4.0:
		body.velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO
	body.move_and_slide()


func knockback(from_position: Vector2, to_position: Vector2, strength: float) -> void:
	knockback_velocity = (to_position - from_position).normalized() * strength


func dash(direction: Vector2, distance: float, duration: float = 0.18) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	dash_velocity = direction.normalized() * (distance / maxf(0.05, duration))
	dash_time_left = duration
