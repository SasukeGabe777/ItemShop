extends Node
## Split-screen camera glue: keeps P2's SubViewport camera on their body
## (with P2's OWN zoom, driven by their triggers) and offsets P1's root
## camera so P1 reads centered in the visible left half.

const MIN_ZOOM := 0.9
const MAX_ZOOM := 3.2
const HOLD_ZOOM_RATE := 1.6

var cam: Camera2D
var target: Node2D
var p1: Node2D


func _process(delta: float) -> void:
	if cam != null and is_instance_valid(cam) and target != null and is_instance_valid(target):
		# P2's triggers control only P2's half
		var dir := 0.0
		if Input.is_action_pressed("p2_zoom_in"):
			dir += 1.0
		if Input.is_action_pressed("p2_zoom_out"):
			dir -= 1.0
		if dir != 0.0:
			MultiplayerState.p2_zoom = clampf(
				MultiplayerState.p2_zoom * (1.0 + dir * (HOLD_ZOOM_RATE - 1.0) * delta), MIN_ZOOM, MAX_ZOOM)
		# the physical-pixel factor keeps P2's world scale identical to P1's
		cam.zoom = Vector2.ONE * (MultiplayerState.p2_zoom * MultiplayerState.p2_zoom_factor)
		cam.global_position = target.global_position
	if p1 != null and is_instance_valid(p1):
		var p1_cam: Camera2D = null
		for child in p1.get_children():
			if child is Camera2D:
				p1_cam = child
				break
		if p1_cam != null:
			var view_w := p1_cam.get_viewport_rect().size.x
			p1_cam.offset = Vector2(view_w / (4.0 * p1_cam.zoom.x), 0)
