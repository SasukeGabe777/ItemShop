class_name PuppetSmoother
extends Node
## Drives a replicated puppet's position between network states: velocity
## extrapolation + exponential lerp, with a snap when the error is huge.
## Parent must be a Node2D whose own physics/AI is disabled.

const SNAP_DISTANCE := 80.0
const MAX_EXTRAPOLATE := 0.25

var target_pos := Vector2.ZERO
var target_vel := Vector2.ZERO
var _last_at := 0.0
var _has_target := false


func push_state(pos: Vector2, vel: Vector2) -> void:
	target_pos = pos
	target_vel = vel
	_last_at = Time.get_ticks_msec() / 1000.0
	_has_target = true
	var parent := get_parent() as Node2D
	if parent != null and parent.global_position.distance_to(pos) > SNAP_DISTANCE:
		parent.global_position = pos


## Scene-owned containment can sanitize both the rendered body and this cached
## network target. Without the latter, an invalid target received behind a
## closed door could become traversable later when that door opens.
func constrain_target(bounded: Vector2) -> void:
	if not _has_target:
		return
	if not is_equal_approx(target_pos.x, bounded.x):
		target_vel.x = 0.0
	if not is_equal_approx(target_pos.y, bounded.y):
		target_vel.y = 0.0
	target_pos = bounded


func _process(delta: float) -> void:
	if not _has_target:
		return
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var age := clampf(Time.get_ticks_msec() / 1000.0 - _last_at, 0.0, MAX_EXTRAPOLATE)
	var predicted := target_pos + target_vel * age
	parent.global_position = parent.global_position.lerp(
		predicted, 1.0 - exp(-delta * 14.0))
