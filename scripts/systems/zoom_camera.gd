class_name ZoomCamera
extends Camera2D
## Player-follow camera with zoom: mouse wheel, -/= keys, or the controller
## triggers (L2 out, R2 in). The chosen level sticks for the whole session
## (shared across town / shop / dungeon).

static var preferred_zoom: float = 1.5

const MIN_ZOOM := 0.9
const MAX_ZOOM := 3.2
const STEP := 1.1
const HOLD_ZOOM_RATE := 1.6  # zoom factor per second while an action is held


func _ready() -> void:
	zoom = Vector2.ONE * preferred_zoom


func _process(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("zoom_in"):
		dir += 1.0
	if Input.is_action_pressed("zoom_out"):
		dir -= 1.0
	if dir == 0.0:
		return
	preferred_zoom = clampf(preferred_zoom * (1.0 + dir * (HOLD_ZOOM_RATE - 1.0) * delta), MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * preferred_zoom


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var mb := event as InputEventMouseButton
	var factor := 0.0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		factor = STEP
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		factor = 1.0 / STEP
	if factor == 0.0:
		return
	preferred_zoom = clampf(preferred_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * preferred_zoom
