class_name ShopCustomer
extends CharacterBody2D
## A visible customer inside the shop: walks in, browses display furniture,
## then asks to negotiate, places an order, or leaves. Logic in CustomerBrain.

signal negotiate_requested(customer: Dictionary, item_id: String)
signal order_requested(customer: Dictionary, direct_boom_request: bool)
signal boom_disappointed(customer: Dictionary)
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
var _leg_axis := -1
var _active_emote: Sprite2D


func setup(cust: Dictionary, browse_points: Array[Vector2], exit_pos: Vector2, preferred_browse_point: Vector2 = Vector2.INF) -> void:
	data = cust
	_exit_pos = exit_pos
	collision_layer = 0
	collision_mask = 0
	visual = CharacterVisual.new()
	add_child(visual)
	var sprite_id := String(cust.get("hero_ref", ""))
	if sprite_id == "":
		sprite_id = String(cust.get("id", "cust"))
	var manifest := "res://assets/franchises/%s/manifests/%s.json" % [String(cust.get("world", "")), sprite_id]
	if not visual.setup_from_manifest(manifest):
		var entry: Dictionary = {}
		if String(cust.get("visual_slug", "")) != "":
			entry = {
				"slug": String(cust.get("visual_slug", "")),
				"manifest": String(cust.get("visual_manifest", "")),
				"static": String(cust.get("visual_static", "")),
			}
		elif bool(cust.get("named", false)):
			entry = ContentDatabase.customer_pool_entry_by_name(String(cust.get("name", "")))
		else:
			entry = ContentDatabase.customer_pool_entry(String(cust.get("id", "cust")), int(get_instance_id() % 1000))
		var pool_manifest := String(entry.get("manifest", ""))
		var static_path := String(entry.get("static", ""))
		if pool_manifest != "" and visual.setup_from_manifest(pool_manifest):
			pass
		elif static_path != "" and ResourceLoader.exists(static_path):
			visual.setup_static(load(static_path))
		else:
			visual.setup_placeholder(String(cust.get("id", "cust")), String(cust.get("world", "")), String(cust.get("color", "#c0c0c0")), 15)
	if String(cust.get("name", "")) != "":
		UIKit.floating_name(self, visual, String(cust.get("name", "")))
	brain = CustomerBrain.new()
	brain.setup(cust)
	brain.wants_to_negotiate.connect(func(c: Dictionary, item: String) -> void:
		_paused_for_negotiation = true
		negotiate_requested.emit(c, item))
	brain.wants_to_order.connect(func(c: Dictionary, direct: bool) -> void: order_requested.emit(c, direct))
	brain.disappointed.connect(func(c: Dictionary) -> void: boom_disappointed.emit(c))
	brain.leaving.connect(_start_leaving)
	add_child(brain)
	var count := 1 + randi() % 3
	var random_stops := count - 1 if preferred_browse_point != Vector2.INF else count
	for i in range(random_stops):
		_waypoints.append(browse_points[randi() % browse_points.size()] + Vector2(randf_range(-8, 8), randf_range(10, 18)))
	if preferred_browse_point != Vector2.INF:
		_waypoints.append(preferred_browse_point + Vector2(randf_range(-5, 5), randf_range(10, 14)))
	_show_arrival_emote.call_deferred()


func _show_arrival_emote() -> void:
	if String(data.get("boom_id", "")) != "":
		show_emote("boom", 1.8)
	elif String(data.get("archetype", "")) == "wealthy_fan":
		show_emote("wealthy", 1.8)
	else:
		var mood := RelationshipManager.mood(String(data.get("id", "")))
		show_emote("happy" if mood > 0.2 else ("unhappy" if mood < -0.2 else "neutral"), 1.8)


## Brief customer reaction above their head. A new reaction replaces an old
## one, so arrival mood, negotiation feedback, and departure never overlap.
func show_emote(kind: String, duration: float = 1.35) -> void:
	if is_instance_valid(_active_emote):
		_active_emote.queue_free()
	var tex := UIKit.emote_texture(kind)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.name = "CustomerEmote_%s" % kind
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE
	spr.z_index = 30
	var top := visual.top_y() * visual.scale.y if visual != null else -24.0
	spr.position = Vector2(0, top - 14.0)
	add_child(spr)
	_active_emote = spr
	var move_tween := spr.create_tween()
	move_tween.tween_property(spr, "position:y", spr.position.y - 5.0, duration).set_trans(Tween.TRANS_SINE)
	var fade_tween := spr.create_tween()
	fade_tween.tween_interval(maxf(0.1, duration - 0.3))
	fade_tween.tween_property(spr, "modulate:a", 0.0, 0.3)
	fade_tween.tween_callback(spr.queue_free)


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
