class_name PatchFollower
extends Node2D
## Patch, the World Bridge fragment, tagging along behind the player as a
## sidekick. Follows at a short distance in town, shop and dungeons using the
## supplied patch sprite sheet; purely cosmetic (no collision, no input).

const FOLLOW_DISTANCE := 26.0
const CATCH_UP_DISTANCE := 220.0
const SPEED := 150.0

var target: Node2D
var visual: CharacterVisual
var _bob_time := 0.0


## Spawns a follower next to `player` under `parent`. Safe when the sprite
## sheet is missing — falls back to the patch placeholder art.
static func attach(parent: Node, player: Node2D) -> PatchFollower:
	var f := PatchFollower.new()
	f.target = player
	f.position = player.position + Vector2(-18, 10)
	parent.add_child(f)
	return f


func _ready() -> void:
	visual = CharacterVisual.new()
	add_child(visual)
	if not visual.setup_from_manifest("res://assets/shared/patch/manifests/patch.json"):
		visual.setup_placeholder("patch", "crossroads", "#66e0ff", 14)
	# Patch floats: lift the body a little and keep the shadow on the ground
	if visual.shadow != null:
		visual.shadow.modulate.a = 0.6


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	# hovering bob, always on — Patch never quite touches the ground
	_bob_time += delta * 4.0
	var body := visual.body_node()
	if body != null:
		body.position.y = -3.0 + sin(_bob_time) * 1.5
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist > CATCH_UP_DISTANCE:
		# scene changed or player teleported: snap next to them
		global_position = target.global_position + Vector2(-18, 10)
		visual.face(Vector2.DOWN, false)
		return
	if dist > FOLLOW_DISTANCE:
		var step := minf(SPEED * delta, dist - FOLLOW_DISTANCE + 1.0)
		global_position += to_target.normalized() * step
		visual.face(_cardinal(to_target), true)
	else:
		# at rest Patch looks wherever the player looks
		var player_facing: Variant = target.get("facing")
		visual.face(_cardinal(player_facing) if player_facing is Vector2 and player_facing != Vector2.ZERO else Vector2.DOWN, false)


## Snap a free direction to the nearest cardinal so the 4-way sheet always
## shows a clean walk cycle.
static func _cardinal(dir: Vector2) -> Vector2:
	if absf(dir.x) >= absf(dir.y):
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP
