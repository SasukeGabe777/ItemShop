class_name Enemy
extends CharacterBody2D
## Data-driven enemy. Behavior comes from enemies.json; no franchise-specific
## logic lives here.

signal killed(enemy_id: String, at: Vector2)

var enemy_id: String = ""
var def: Dictionary = {}
var behavior: String = "chaser"
var target: Node2D
var health: HealthComponent
var movement: MovementComponent
var visual: CharacterVisual
var hurtbox: HurtboxComponent
var hit_radius: float = 10.0  # visual body radius, used for touch damage
var hitbox: HitboxComponent
var loot: LootTableComponent

var stun_time: float = 0.0
var _think_timer: float = 0.0
var _retarget_timer: float = 0.0
var _state: String = "idle"
var _state_time: float = 0.0
var _shots_cooldown: float = 0.0
var rng := RandomNumberGenerator.new()


func setup(id: String, player: Node2D) -> void:
	enemy_id = id
	def = ContentDatabase.get_enemy(id)
	behavior = String(def.get("behavior", "chaser"))
	target = player
	rng.randomize()
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var size := int(def.get("size", 14))
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = size * 0.45
	shape.shape = circle
	add_child(shape)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.setup(int(def.get("hp", 20)))
	health.died.connect(_on_died)
	add_child(health)

	movement = MovementComponent.new()
	movement.max_speed = float(def.get("spd", 90))
	add_child(movement)

	visual = CharacterVisual.new()
	add_child(visual)
	var world_id := String(def.get("world", ""))
	var manifest := "res://assets/franchises/%s/manifests/%s.json" % [world_id, id]
	if not visual.setup_from_manifest(manifest):
		visual.setup_placeholder(id, world_id, String(def.get("color", "#a0a0a0")), size)
	# real sprite sheets can be much larger than the data `size` tuned for
	# placeholders — measure the art so hurtboxes match what's on screen
	var vis := _visual_frame_size()
	# cap the rendered height (playtest 2026-07-22: boss rips filled a third
	# of the 640x360 view and read overpixelated). Bosses get a taller cap so
	# they still loom; rank-and-file art already sits well under its cap.
	var height_cap := 84.0 if def.has("attacks") else 44.0
	if vis.y > height_cap:
		var vscale := height_cap / vis.y
		visual.scale = Vector2(vscale, vscale)
		vis *= vscale
	var body_h := maxf(float(size), vis.y * 0.8)
	var body_w := maxf(float(size), vis.x * 0.8)
	hit_radius = maxf(body_w, body_h) * 0.5

	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	var hshape := CollisionShape2D.new()
	# match the hurtbox to the visible sprite body: a box across the whole body,
	# not a small center circle. Wide/tall enemies (e.g. the DBZ dinosaur) were
	# only hittable near their center — beams and swings passed beside them.
	var hrect := RectangleShape2D.new()
	hrect.size = Vector2(body_w, body_h)
	hshape.shape = hrect
	# sprite pivot sits at the feet; center the box on the body
	hshape.position = Vector2(0, -body_h * 0.5)
	hurtbox.add_child(hshape)
	hurtbox.hit_received.connect(_on_hit)
	add_child(hurtbox)

	hitbox = HitboxComponent.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 16
	var ashape := CollisionShape2D.new()
	var acircle := CircleShape2D.new()
	acircle.radius = maxf(size * 0.5, minf(body_w, body_h) * 0.45)
	ashape.shape = acircle
	ashape.position = Vector2(0, -body_h * 0.35)
	hitbox.add_child(ashape)
	add_child(hitbox)

	loot = LootTableComponent.new()
	loot.enemy_id = id
	add_child(loot)
	_think_timer = rng.randf_range(0.0, 0.5)


func _visual_frame_size() -> Vector2:
	if visual == null or not visual.use_frames or visual.animated == null:
		return Vector2.ZERO
	var frames := visual.animated.sprite_frames
	var anim := StringName("idle_down")
	if not frames.has_animation(anim):
		anim = frames.get_animation_names()[0]
	var tex := frames.get_frame_texture(anim, 0)
	return tex.get_size() if tex != null else Vector2.ZERO


func take_packet(packet: Dictionary, from_position: Vector2) -> void:
	hurtbox.receive(packet, from_position)


## Held in place by a thrown item (Deku Nut and friends). Enemies carry no
## status component, so the timer lives here.
func apply_stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds)
	if visual != null:
		FX.flash(visual.body_node(), Color(1.0, 1.0, 0.5))


func _physics_process(delta: float) -> void:
	if health.dead or target == null or not is_instance_valid(target):
		return
	if stun_time > 0.0:
		stun_time -= delta
		movement.apply(self, Vector2.ZERO, delta)
		return
	# co-op: chase whichever living hero is closest
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = 0.5
		_retarget_nearest_hero()
	_shots_cooldown = maxf(0.0, _shots_cooldown - delta)
	_state_time -= delta
	var wish := _behavior_direction(delta)
	movement.apply(self, wish, delta)
	visual.face(wish if wish != Vector2.ZERO else (target.global_position - global_position), wish != Vector2.ZERO)
	_touch_damage()


func _retarget_nearest_hero() -> void:
	var best: Node2D = null
	var best_d := INF
	for h in get_tree().get_nodes_in_group("combat_hero"):
		if h is CombatHero and is_instance_valid(h) and not (h as CombatHero).health.dead:
			var d := (h as Node2D).global_position.distance_squared_to(global_position)
			if d < best_d:
				best_d = d
				best = h
	if best != null:
		target = best


func _to_player() -> Vector2:
	return target.global_position - global_position


func _behavior_direction(delta: float) -> Vector2:
	var to_p := _to_player()
	var dist := to_p.length()
	match behavior:
		"chaser":
			return to_p
		"tank":
			movement.max_speed = float(def.get("spd", 60))
			return to_p
		"lunger":
			if _state == "lunge":
				if _state_time <= 0.0:
					_state = "idle"
				return Vector2.ZERO  # dash handled by movement.dash
			if dist < 90.0 and _state_time <= 0.0:
				_state = "lunge"
				_state_time = 0.6
				movement.dash(to_p, dist + 20.0, 0.25)
				return Vector2.ZERO
			return to_p if dist > 60.0 else Vector2.ZERO
		"shooter", "skitter_shooter":
			if _shots_cooldown <= 0.0 and dist < 220.0:
				_shoot(to_p)
				_shots_cooldown = rng.randf_range(1.2, 2.2)
			if behavior == "skitter_shooter":
				if _state_time <= 0.0:
					_state_time = rng.randf_range(0.5, 1.0)
					_state = ["left", "right", "back", "stop"][rng.randi() % 4]
				match _state:
					"left": return to_p.orthogonal()
					"right": return -to_p.orthogonal()
					"back": return -to_p
					_: return Vector2.ZERO
			return to_p if dist > 140.0 else (-to_p if dist < 80.0 else Vector2.ZERO)
		"bomber":
			if dist < 26.0:
				_explode()
				return Vector2.ZERO
			movement.max_speed = float(def.get("spd", 100)) * 1.2
			return to_p
		"shy_ghost":
			# advances only when player faces away — approximated by movement dir
			var player_moving_away := true
			if target is CharacterBody2D:
				var pv := (target as CharacterBody2D).velocity
				player_moving_away = pv == Vector2.ZERO or pv.angle_to(-to_p) > PI / 2.0
			return to_p if player_moving_away else Vector2.ZERO
		"swooper":
			if _state_time <= 0.0:
				_state_time = rng.randf_range(0.8, 1.4)
				_state = "swoop" if rng.randf() < 0.6 else "circle"
			return to_p if _state == "swoop" else to_p.orthogonal()
		"creeper":
			movement.max_speed = float(def.get("spd", 35))
			return to_p
		"ambusher":
			if _state == "idle" and dist < 110.0:
				_state = "burst"
				_state_time = 1.2
				movement.dash(to_p, dist * 0.8, 0.3)
			elif _state == "burst" and _state_time <= 0.0:
				_state = "idle"
			return to_p if _state == "burst" else Vector2.ZERO
		"splitter", "teleporter":
			if behavior == "teleporter" and _state_time <= 0.0 and dist < 200.0 and rng.randf() < 0.4 * delta * 10.0:
				global_position = target.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * 60.0
				_state_time = 1.5
				FX.burst(get_parent(), global_position, Color(0.6, 0.7, 1.0), 6)
			return to_p
		"shell":
			if _state == "spin":
				if _state_time <= 0.0:
					_state = "idle"
				return _to_player().normalized().rotated(rng.randf_range(-0.2, 0.2))
			if dist < 70.0 and _state_time <= 0.0:
				_state = "spin"
				_state_time = 1.5
				movement.max_speed = float(def.get("spd", 90)) * 2.0
			else:
				movement.max_speed = float(def.get("spd", 90))
			return to_p
	return to_p


func _touch_damage() -> void:
	if _shots_cooldown > 0.0 and behavior != "shooter" and behavior != "skitter_shooter":
		return
	var dist := _to_player().length()
	if dist < (hit_radius + 9.0):
		hitbox.begin_swing({"damage": int(def.get("atk", 5)), "knockback": 160.0, "source": self})
		get_tree().create_timer(0.1).timeout.connect(hitbox.end_swing)
		if behavior != "shooter" and behavior != "skitter_shooter":
			_shots_cooldown = 0.7


func _shoot(direction: Vector2) -> void:
	var p := Projectile.new()
	p.setup({"damage": int(def.get("atk", 5)), "knockback": 100.0, "source": self},
		direction, 150.0, Color(String(def.get("color", "#ffffff"))).lightened(0.3), 16)
	p.global_position = global_position
	get_parent().add_child(p)


func _explode() -> void:
	if health.dead:
		return
	FX.burst(get_parent(), global_position, Color(1, 0.6, 0.2), 20)
	FX.shake(4.0)
	if _to_player().length() < 40.0 and target.has_node("HurtboxComponent"):
		(target.get_node("HurtboxComponent") as HurtboxComponent).receive(
			{"damage": int(def.get("atk", 10)) * 2, "knockback": 220.0, "source": self}, global_position)
	health.take_damage(99999, self)


func _on_hit(packet: Dictionary, from_position: Vector2) -> void:
	movement.knockback(from_position, global_position, float(packet.get("knockback", 120)))
	FX.flash(visual.body_node(), Color(1, 1, 1))
	FX.hit_pause(get_tree())
	FX.damage_number(get_parent(), global_position, int(packet.get("damage", 0)))
	FX.burst(get_parent(), global_position, Color(1, 0.9, 0.6), 6)
	var src: Variant = packet.get("source")
	if src is CombatHero:
		(src as CombatHero).on_enemy_hit()


func _on_died() -> void:
	if behavior == "splitter" and int(def.get("size", 14)) > 10 and not has_meta("split_child"):
		for i in range(2):
			var child := Enemy.new()
			child.set_meta("split_child", true)
			get_parent().add_child(child)
			child.setup(enemy_id, target)
			child.health.setup(int(def.get("hp", 20)) / 3)
			child.global_position = global_position + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
	var drops := loot.roll()
	killed.emit(enemy_id, global_position)
	# bosses get a bigger release than rank-and-file heartless
	FX.enemy_death(get_parent(), global_position, 1.6 if not def.get("attacks", []).is_empty() else 1.0)
	for item_id: String in drops["items"]:
		var pickup := LootPickup.new()
		pickup.setup_item(item_id)
		pickup.global_position = global_position + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		get_parent().call_deferred("add_child", pickup)
	if int(drops["gold"]) > 0:
		var gold_pickup := LootPickup.new()
		gold_pickup.setup_gold(int(drops["gold"]))
		gold_pickup.global_position = global_position
		get_parent().call_deferred("add_child", gold_pickup)
	queue_free()
