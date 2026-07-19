extends Node
## Split-screen camera glue: keeps P2's SubViewport camera on their body and
## offsets P1's root camera so P1 reads centered in the visible top half.

var cam: Camera2D
var target: Node2D
var p1: Node2D


func _process(_delta: float) -> void:
	if cam != null and is_instance_valid(cam) and target != null and is_instance_valid(target):
		cam.zoom = Vector2.ONE * ZoomCamera.preferred_zoom
		cam.global_position = target.global_position
	if p1 != null and is_instance_valid(p1):
		var p1_cam := p1.get_node_or_null("ZoomCamera") as Camera2D
		if p1_cam == null:
			for child in p1.get_children():
				if child is Camera2D:
					p1_cam = child
					break
		if p1_cam != null:
			var view_h := p1_cam.get_viewport_rect().size.y
			p1_cam.offset = Vector2(0, view_h / (4.0 * p1_cam.zoom.y))
