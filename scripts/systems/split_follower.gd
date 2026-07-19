extends Node
## Split-screen camera glue: keeps P2's SubViewport camera on their body and
## offsets P1's root camera so P1 reads centered in the visible left half.

var cam: Camera2D
var target: Node2D
var p1: Node2D


func _process(_delta: float) -> void:
	if cam != null and is_instance_valid(cam) and target != null and is_instance_valid(target):
		cam.zoom = Vector2.ONE * ZoomCamera.preferred_zoom
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
