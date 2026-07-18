extends ZoomCamera
## Camera with additive trauma shake, used by FX.shake via the group.
## Inherits mouse-wheel zoom from ZoomCamera.

var _trauma: float = 0.0


func add_shake(intensity: float) -> void:
	_trauma = minf(12.0, _trauma + intensity)


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - 18.0 * delta)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _trauma
	else:
		offset = Vector2.ZERO
