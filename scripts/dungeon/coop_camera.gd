extends Camera2D
## Shared co-op dungeon camera: sits on the midpoint between both heroes,
## defaults to showing the whole room, and only Player 1's triggers (or the
## mouse wheel / -+ keys) adjust its zoom. Takes FX.shake trauma like the
## solo camera.

const MIN_ZOOM := 0.55
const MAX_ZOOM := 2.5
const HOLD_ZOOM_RATE := 1.6

static var coop_zoom: float = 0.0  # sticks for the session; 0 = fit the room

var hero_a: Node2D
var hero_b: Node2D
var _trauma: float = 0.0


func add_shake(intensity: float) -> void:
	_trauma = minf(12.0, _trauma + intensity)


func _ready() -> void:
	add_to_group("shake_camera")
	var room := Vector2(ContentDatabase.room_grid) * 32.0
	if coop_zoom <= 0.0:
		# fit the whole room (plus wall margin) on screen for both players
		var view := get_viewport_rect().size
		coop_zoom = clampf(minf(view.x / (room.x + 64.0), view.y / (room.y + 96.0)), MIN_ZOOM, 1.2)
	zoom = Vector2.ONE * coop_zoom
	# never show the void beyond the walls
	limit_left = -48
	limit_top = -64
	limit_right = int(room.x) + 48
	limit_bottom = int(room.y) + 48


func _process(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("zoom_in"):
		dir += 1.0
	if Input.is_action_pressed("zoom_out"):
		dir -= 1.0
	if dir != 0.0:
		coop_zoom = clampf(coop_zoom * (1.0 + dir * (HOLD_ZOOM_RATE - 1.0) * delta), MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * coop_zoom
	var points: Array[Vector2] = []
	if hero_a != null and is_instance_valid(hero_a):
		points.append(hero_a.global_position)
	if hero_b != null and is_instance_valid(hero_b):
		points.append(hero_b.global_position)
	if not points.is_empty():
		var mid := Vector2.ZERO
		for p in points:
			mid += p
		global_position = mid / points.size()
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - 18.0 * delta)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _trauma
	else:
		offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			coop_zoom = clampf(coop_zoom * 1.1, MIN_ZOOM, MAX_ZOOM)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			coop_zoom = clampf(coop_zoom / 1.1, MIN_ZOOM, MAX_ZOOM)
