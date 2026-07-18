class_name ShopCustomer
extends CharacterBody2D
## A visible customer inside the shop: walks in, browses display furniture,
## then asks to negotiate, places an order, or leaves. Logic in CustomerBrain.

signal negotiate_requested(customer: Dictionary, item_id: String)
signal order_requested(customer: Dictionary)
signal left(me: ShopCustomer)

var data: Dictionary = {}
var brain: CustomerBrain
var visual: CharacterVisual
var _waypoints: Array[Vector2] = []
var _exit_pos: Vector2
var _speed := 70.0
var _leaving := false
var _paused_for_negotiation := false
var _leg_target := Vector2.INF
var _leg_axis := -1  # 0 = walking out x, 1 = walking out y


func setup(cust: Dictionary, browse_points: Array[Vector2], exit_pos: Vector2, preferred_browse_point: Vector2 = Vector2.INF) -> void:
	data = cust
	_exit_pos = exit_pos
	collision_layer = 0
	collision_mask = 0
	visual = CharacterVisual.new()
	add_child(visual)
	# named hero customers use their real spritesheet when one is wired up
	var sprite_id := String(cust.get("hero_ref", ""))
	if sprite_id == "":
		sprite_id = String(cust.get("id", "cust"))
	var manifest := "res://assets/franchises/%s/manifests/%s.json" % [String(cust.get("world", "")), sprite_id]
	if not visual.setup_from_manifest(manifest):
		# no real sheet: draw a character from the customer pool. Named
		# customers get their own character when the pool has them (or a
		# stable stand-in); walk-ins vary per spawn and take on the pool
		# character's name — the archetype stays as their title.
		var named := bool(cust.get("named", false))
		var entry: Dictionary = {}
		if named:
			# named customers only ever use their OWN character's art — a
			# placeholder beats Princess Peach walking around in Vegeta's body
			entry = ContentDatabase.customer_pool_entry_by_name(String(cust.get("name", "")))
		else:
			entry = ContentDatabase.customer_pool_entry(String(cust.get("id", "cust")), int(get_instance_id() % 1000))
			if String(entry.get("name", "")) != "":
				cust["name"] = String(entry.get("name", ""))
		var pool_manifest := String(entry.get("manifest", ""))
		var static_path := String(entry.get("static", ""))
		if pool_manifest != "" and visual.setup_from_manifest(pool_manifest):
			pass
		elif static_path != "" and ResourceLoader.exists(static_path):
			visual.setup_static(load(static_path))
		else:
			visual.setup_placeholder(String(cust.get("id", "cust")), String(cust.get("world", "")), String(cust.get("color", "#c0c0c0")), 15)
	if String(cust.get("name", "")) != "":
		var tag := UIKit.label(String(cust.get("name", "")), 8, UIKit.COL_ACCENT)
		tag.position = Vector2(-20, -34)
		add_child(tag)
	brain = CustomerBrain.new()
	brain.setup(cust)
	brain.wants_to_negotiate.connect(func(c: Dictionary, item: String) -> void:
		_paused_for_negotiation = true
		negotiate_requested.emit(c, item))
	brain.wants_to_order.connect(func(c: Dictionary) -> void: order_requested.emit(c))
	brain.leaving.connect(_start_leaving)
	add_child(brain)
	var count := 1 + randi() % 3
	var random_stops := count - 1 if preferred_browse_point != Vector2.INF else count
	for i in range(random_stops):
		_waypoints.append(browse_points[randi() % browse_points.size()] + Vector2(randf_range(-8, 8), randf_range(10, 18)))
	if preferred_browse_point != Vector2.INF:
		_waypoints.append(preferred_browse_point + Vector2(randf_range(-5, 5), randf_range(10, 14)))


## First frame of whatever this customer looks like, for the negotiation
## portrait — matches the sprite walking around the shop.
func portrait_texture() -> Texture2D:
	if visual == null:
		return null
	if visual.static_sprite != null:
		return visual.static_sprite.texture
	if visual.animated != null and visual.animated.sprite_frames != null:
		var frames := visual.animated.sprite_frames
		var anim := StringName("idle_down")
		if not frames.has_animation(anim):
			anim = frames.get_animation_names()[0]
		return frames.get_frame_texture(anim, 0)
	return null


func resume_after_negotiation() -> void:
	_paused_for_negotiation = false
	brain.finish_negotiation()


func _physics_process(delta: float) -> void:
	if _paused_for_negotiation:
		visual.face(Vector2.DOWN, false)
		return
	brain.tick(delta)
	var target := _exit_pos if _leaving else (_waypoints[0] if not _waypoints.is_empty() else position)
	var to_target := target - position
	if to_target.length() < 4.0:
		if _leaving:
			left.emit(self)
			queue_free()
			return
		if not _waypoints.is_empty():
			_waypoints.remove_at(0)
			if _waypoints.is_empty():
				brain.begin_browsing()
		visual.face(Vector2.UP if not _leaving else Vector2.DOWN, false)
		return
	# cardinal-only movement: walk one axis at a time (L-shaped paths) —
	# diagonal walking looks wrong with most of the 4-direction sheets
	if target != _leg_target:
		_leg_target = target
		_leg_axis = -1
	if _leg_axis == 0 and absf(to_target.x) <= 2.0:
		_leg_axis = -1
	elif _leg_axis == 1 and absf(to_target.y) <= 2.0:
		_leg_axis = -1
	if _leg_axis == -1:
		_leg_axis = 0 if absf(to_target.x) >= absf(to_target.y) else 1
	var step := Vector2(signf(to_target.x), 0.0) if _leg_axis == 0 else Vector2(0.0, signf(to_target.y))
	velocity = step * _speed
	move_and_slide()
	visual.face(step, true)


func _start_leaving() -> void:
	_leaving = true
