class_name TownPlayer
extends CharacterBody2D
## Hero walking around the Crossroads (and shop interior). Uses the supplied
## Omori sprite sheet via its manifest; falls back to a placeholder safely.

const SPEED := 110.0

var visual: CharacterVisual
var facing: Vector2 = Vector2.DOWN
var frozen: bool = false
var input_prefix: String = ""  # "p2_" for the second local player
var is_puppet: bool = false    # online: a remote player's body, driven by Replica
## Online: which walking-avatar manifest to render (set before add_child).
## Empty = the historical faraway hero.
var manifest_override: String = ""
var dev_speed_multiplier: float = 1.0
var dev_collision_enabled: bool = true


## Online remote body: no input, no physics — the PuppetSmoother owns the
## position and _process animates from its streamed velocity.
func make_puppet() -> void:
	is_puppet = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0


func _process(_delta: float) -> void:
	if not is_puppet:
		return
	var sm := get_node_or_null("PuppetSmoother") as PuppetSmoother
	if sm == null or visual == null:
		return
	var moving := sm.target_vel.length() > 5.0
	if moving:
		facing = sm.target_vel.normalized()
	visual.face(facing, moving)


func _ready() -> void:
	add_to_group("dev_player")
	set_meta("dev_object_type", "player")
	set_meta("dev_content_id", "hero")
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
	var mp := manifest_override if manifest_override != "" \
		else "res://assets/hero/manifests/hero_faraway_overworld.json"
	if not visual.setup_from_manifest(mp):
		visual.setup_placeholder("hero", "crossroads", "#3858a8", 18)
	if visual.use_frames:
		visual.shadow.position = Vector2(0, 2)


func _physics_process(delta: float) -> void:
	if frozen:
		visual.face(facing, false)
		return
	var wish := Input.get_vector(input_prefix + "move_left", input_prefix + "move_right",
		input_prefix + "move_up", input_prefix + "move_down")
	if wish != Vector2.ZERO:
		facing = wish
	velocity = velocity.move_toward(wish.normalized() * SPEED * dev_speed_multiplier, 900.0 * delta)
	move_and_slide()
	visual.face(facing, wish != Vector2.ZERO)


func set_dev_speed_multiplier(value: float) -> void:
	dev_speed_multiplier = clampf(value, 0.1, 5.0)


func set_dev_collision_enabled(enabled: bool) -> void:
	dev_collision_enabled = enabled
	collision_mask = 1 if enabled else 0
	collision_layer = 2 if enabled else 0


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
