class_name TownPlayer
extends CharacterBody2D
## Hero walking around the Crossroads (and shop interior). Uses the supplied
## Omori sprite sheet via its manifest; falls back to a placeholder safely.

const SPEED := 110.0

var visual: CharacterVisual
var facing: Vector2 = Vector2.DOWN
var frozen: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	shape.position = Vector2(0, 2)
	add_child(shape)
	visual = CharacterVisual.new()
	add_child(visual)
	if not visual.setup_from_manifest("res://assets/hero/manifests/hero_faraway_overworld.json"):
		visual.setup_placeholder("hero", "crossroads", "#3858a8", 18)
	if visual.use_frames:
		visual.shadow.position = Vector2(0, 2)


func _physics_process(delta: float) -> void:
	if frozen:
		visual.face(facing, false)
		return
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if wish != Vector2.ZERO:
		facing = wish
	velocity = velocity.move_toward(wish.normalized() * SPEED, 900.0 * delta)
	move_and_slide()
	visual.face(facing, wish != Vector2.ZERO)


func nearest_interactable() -> InteractionComponent:
	var best: InteractionComponent = null
	var best_dist := 40.0
	var loop := Engine.get_main_loop() as SceneTree
	for node in loop.get_nodes_in_group("interactables"):
		var ic := node as InteractionComponent
		if ic == null:
			continue
		var d := ic.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = ic
	return best
