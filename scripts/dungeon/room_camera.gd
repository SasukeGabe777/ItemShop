extends Camera2D
## Dungeon camera that always keeps the complete room below the HUD.
##
## Dungeon rooms are 640x384 while the design viewport is only 640x360.
## A following camera therefore hid the north edge behind the HUD. Fit the
## room into the safe play area so every enemy and the exit remain visible.

const SIDE_MARGIN := 8.0
const BOTTOM_MARGIN := 4.0

var safe_top := 58.0
var _trauma := 0.0


func _ready() -> void:
	add_to_group("shake_camera")
	get_viewport().size_changed.connect(_fit_room)
	_fit_room.call_deferred()


func add_shake(intensity: float) -> void:
	_trauma = minf(12.0, _trauma + intensity)


func _fit_room() -> void:
	var view := get_viewport_rect().size
	var room := Vector2(ContentDatabase.room_grid) * 32.0
	var available := Vector2(
		maxf(1.0, view.x - SIDE_MARGIN * 2.0),
		maxf(1.0, view.y - safe_top - BOTTOM_MARGIN))
	var fit := minf(available.x / room.x, available.y / room.y)
	zoom = Vector2.ONE * fit

	# Camera2D maps its world position to the viewport center. Move that world
	# position upward so the room is centered below the HUD instead.
	var safe_center := Vector2(
		view.x * 0.5,
		safe_top + (view.y - safe_top - BOTTOM_MARGIN) * 0.5)
	var screen_shift := safe_center - view * 0.5
	global_position = room * 0.5 - screen_shift / fit


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - 18.0 * delta)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _trauma
	else:
		offset = Vector2.ZERO
