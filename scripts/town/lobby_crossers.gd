class_name LobbyCrossers
extends Node2D
## Ambient life in the Crossroads plaza: random franchise characters fade into
## view, amble a short way across, sometimes mutter a line, then fade out — as
## if travellers are passing through the crossroads. Purely cosmetic. It pulls
## visuals straight from the customer pool and never touches the shop's
## customer-spawning / demand systems, so it stays out of their way.

const MAX_ACTIVE := 2
const SPAWN_MIN := 2.2
const SPAWN_MAX := 5.0
const SPEED := 20.0
const FADE := 0.55
const TTL_MIN := 2.5
const TTL_MAX := 4.5
const LINE_CHANCE := 0.4
const MAX_ROUTE_ATTEMPTS := 64
# Ten 32px tiles around the rug at the plaza's center. The landmark footprints
# include their art/nameplates (not just their smaller physics rectangles), so
# travellers never fade in on top of one or walk through it during their visit.
const AREA := Rect2(160, 90, 320, 320)
const LANDMARK_FOOTPRINTS := [
	Rect2(122, 36, 156, 174),  # Item Shop
	Rect2(380, 54, 120, 156), # Market
	Rect2(148, 270, 104, 140), # Workshop
	Rect2(379, 274, 122, 136), # Adventurers' Guild
]
const ROUTE_DIRECTIONS := [
	Vector2.RIGHT,
	Vector2.LEFT,
	Vector2.UP,
	Vector2.DOWN,
	Vector2(0.70710678, 0.70710678),
	Vector2(-0.70710678, 0.70710678),
	Vector2(0.70710678, -0.70710678),
	Vector2(-0.70710678, -0.70710678),
]

const LINES := [
	"So this is the Crossroads...",
	"Which way to the market?",
	"Heard the item shop's the real deal.",
	"Just passing through.",
	"Long road behind me.",
	"Wonder what's on the shelves today.",
	"Every world meets right here.",
	"Mind the gates, traveller.",
	"Adventure's calling.",
	"Coin's tight this season.",
]

var _rng := RandomNumberGenerator.new()
var _next := 1.5
var _crossers: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	z_index = 2  # above the plaza floor and rug, below the HUD


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		if _crossers.size() < MAX_ACTIVE:
			_spawn()
		_next = _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
	for c in _crossers:
		# A fade tween can free the node between frames. Check the untyped
		# reference before assigning it to Node2D; assigning a freed object to
		# a typed variable itself raises an error before is_instance_valid().
		var node_ref: Variant = c.get("node")
		if node_ref == null or not is_instance_valid(node_ref):
			continue
		var node := node_ref as Node2D
		var dir: Vector2 = c["dir"]
		node.position += dir * SPEED * delta
		(c["visual"] as CharacterVisual).face(dir, true)
		c["life"] += delta
		if not c["fading"] and c["life"] >= c["ttl"]:
			c["fading"] = true
			var tw := node.create_tween()
			tw.tween_property(node, "modulate:a", 0.0, FADE)
			tw.tween_callback(node.queue_free)
	_crossers = _crossers.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))


func _spawn() -> void:
	var pool: Array = ContentDatabase.customer_visual_pool
	if pool.is_empty():
		return
	var entry: Dictionary = pool[_rng.randi() % pool.size()]
	var ttl := _rng.randf_range(TTL_MIN, TTL_MAX)
	var route := _pick_route(ttl)
	var node := Node2D.new()
	node.modulate.a = 0.0
	node.position = route["position"]
	var dir: Vector2 = route["dir"]
	var vis := CharacterVisual.new()
	var manifest := String(entry.get("manifest", ""))
	var static_path := String(entry.get("static", ""))
	if manifest == "" or not vis.setup_from_manifest(manifest):
		if static_path != "" and ResourceLoader.exists(static_path):
			vis.setup_static(load(static_path))
		else:
			vis.setup_placeholder(String(entry.get("slug", "cust")), String(entry.get("world", "")), "#c0c0c0", 15)
	# tame wildly-sized pool art so every traveller reads as a normal plaza-goer
	var h := vis.sprite_height()
	if h > 40.0:
		var s := 40.0 / h
		vis.scale = Vector2(s, s)
	node.add_child(vis)
	if String(entry.get("name", "")) != "":
		UIKit.floating_name(node, vis, String(entry.get("name", "")))
	add_child(node)
	var fade_in := node.create_tween()
	fade_in.tween_property(node, "modulate:a", 1.0, FADE)
	if _rng.randf() < LINE_CHANCE:
		_say(node, vis, LINES[_rng.randi() % LINES.size()])
	_crossers.append({
		"node": node, "visual": vis, "dir": dir,
		"life": 0.0, "ttl": ttl, "fading": false,
	})


## Pick both a spawn and a short route. Testing the complete segment keeps a
## valid spawn from immediately drifting through a landmark or out of the plaza.
func _pick_route(ttl: float) -> Dictionary:
	for _attempt in range(MAX_ROUTE_ATTEMPTS):
		var position := Vector2(
			_rng.randf_range(AREA.position.x, AREA.end.x),
			_rng.randf_range(AREA.position.y, AREA.end.y))
		var dir: Vector2 = ROUTE_DIRECTIONS[_rng.randi() % ROUTE_DIRECTIONS.size()]
		var destination := position + dir * SPEED * ttl
		if _route_is_clear(position, destination):
			return {"position": position, "dir": dir}
	# The center horizontal lane is always open, even if a pathological random
	# sequence misses every valid route during the bounded attempts above.
	return {"position": Vector2(320, 250), "dir": Vector2.RIGHT}


func _route_is_clear(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var checks := maxi(1, int(ceil(distance / 8.0)))
	for i in range(checks + 1):
		var point := from.lerp(to, float(i) / checks)
		if not _position_is_clear(point):
			return false
	return true


func _position_is_clear(position: Vector2) -> bool:
	if not AREA.has_point(position):
		return false
	for footprint: Rect2 in LANDMARK_FOOTPRINTS:
		if footprint.has_point(position):
			return false
	return true


## A brief speech bubble above the crosser's head, fading itself out well
## before the crosser leaves. Rides the crosser's node modulate, so it fades in
## with the character and out with them too.
func _say(node: Node2D, vis: CharacterVisual, text: String) -> void:
	var bubble := UIKit.panel()
	bubble.z_index = 6
	bubble.add_child(UIKit.label(text, 7))
	node.add_child(bubble)
	(func() -> void:
		if is_instance_valid(bubble):
			var top := vis.top_y() * vis.scale.y
			bubble.position = Vector2(-bubble.size.x / 2.0, top - bubble.size.y - 16.0)).call_deferred()
	var tw := bubble.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tw.tween_callback(bubble.queue_free)
