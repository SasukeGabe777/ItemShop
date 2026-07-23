class_name CombatHero
extends CharacterBody2D
## The shared dungeon controller. Every franchise hero uses the same scheme:
## move / attack / special / dodge-guard / consumable / finisher. Data from
## heroes.json + equipment makes each one feel different.

signal meter_changed(value: float)
signal hp_changed(hp: int, max_hp: int)
signal consumables_changed(items: Array)
signal defeated()

const LAYER_WALLS := 1
const LAYER_PLAYER_HURT := 16
const LAYER_ENEMY_HURT := 8

var hero_id: String = ""
var hero_def: Dictionary = {}
var stats: Dictionary = {}
var visual: CharacterVisual
var health: HealthComponent
var movement: MovementComponent
var status: StatusEffectComponent
var hurtbox: HurtboxComponent
var hitbox: HitboxComponent

var facing: Vector2 = Vector2.DOWN
var meter: float = 0.0
var combo_index: int = 0
var combo_reset_at: float = 0.0
var attack_lock: float = 0.0
var special_cooldown: float = 0.0
var guarding: bool = false
var consumables: Array = []
var revives_available: int = 0
var input_prefix: String = ""  # "p2_" for the second local player


func setup(id: String, consumable_items: Array = []) -> void:
	add_to_group("dev_player")
	add_to_group("combat_hero")
	set_meta("dev_object_type", "hero")
	set_meta("dev_content_id", id)
	hero_id = id
	hero_def = ContentDatabase.get_hero(id)
	stats = InventoryManager.hero_stats(id)
	consumables = consumable_items.duplicate()
	collision_layer = 2
	collision_mask = LAYER_WALLS
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.setup(int(stats["hp"]))
	health.died.connect(_on_died)
	add_child(health)

	movement = MovementComponent.new()
	movement.max_speed = float(stats["spd"])
	add_child(movement)

	status = StatusEffectComponent.new()
	add_child(status)

	visual = CharacterVisual.new()
	add_child(visual)
	var manifest := "res://assets/franchises/%s/manifests/%s.json" % [String(hero_def.get("world", "")), id]
	if not visual.setup_from_manifest(manifest):
		visual.setup_placeholder(id, String(hero_def.get("world", "")), String(hero_def.get("color", "#c0c0c0")), 18)

	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = LAYER_PLAYER_HURT
	hurtbox.collision_mask = 0
	var hshape := CollisionShape2D.new()
	var hcircle := CircleShape2D.new()
	hcircle.radius = 7.0
	hshape.shape = hcircle
	hurtbox.add_child(hshape)
	hurtbox.hit_received.connect(_on_hit)
	add_child(hurtbox)

	hitbox = HitboxComponent.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = LAYER_ENEMY_HURT
	var atk_shape := CollisionShape2D.new()
	var atk_circle := CircleShape2D.new()
	var basic: Dictionary = hero_def.get("combat", {}).get("basic", {})
	atk_circle.radius = float(basic.get("range", 26)) * 0.62
	atk_shape.shape = atk_circle
	hitbox.add_child(atk_shape)
	add_child(hitbox)
	hp_changed.emit(health.hp, health.max_hp)
	consumables_changed.emit(consumables)


func combat_def() -> Dictionary:
	return hero_def.get("combat", {})


func _physics_process(delta: float) -> void:
	if health.dead:
		return
	attack_lock = maxf(0.0, attack_lock - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	if Time.get_ticks_msec() / 1000.0 > combo_reset_at:
		combo_index = 0
	var wish := Vector2.ZERO
	if attack_lock <= 0.0 and not status.is_stunned():
		wish = Input.get_vector(input_prefix + "move_left", input_prefix + "move_right",
			input_prefix + "move_up", input_prefix + "move_down")
	if wish != Vector2.ZERO:
		facing = wish
	movement.max_speed = float(stats["spd"]) * (0.35 if guarding else 1.0)
	movement.apply(self, wish, delta)
	visual.face(facing, wish != Vector2.ZERO)
	_position_hitbox()
	if attack_lock <= 0.0 and not status.is_stunned():
		_read_combat_input()


func _position_hitbox() -> void:
	var basic: Dictionary = combat_def().get("basic", {})
	hitbox.position = facing.normalized() * float(basic.get("range", 26)) * 0.7


func _read_combat_input() -> void:
	if Input.is_action_just_pressed(input_prefix + "attack"):
		_do_basic_attack()
	elif Input.is_action_just_pressed(input_prefix + "special"):
		_do_special()
	elif Input.is_action_just_pressed(input_prefix + "dodge"):
		_do_dodge(true)
	elif Input.is_action_just_pressed(input_prefix + "use_item"):
		_use_consumable()
	elif Input.is_action_just_pressed(input_prefix + "finisher"):
		_do_finisher()
	var dodge: Dictionary = combat_def().get("dodge", {})
	if String(dodge.get("kind", "roll")) == "guard":
		var was := guarding
		guarding = Input.is_action_pressed(input_prefix + "dodge")
		hurtbox.guard_reduction = float(dodge.get("reduction", 0.75)) if guarding else 0.0
		if guarding != was and guarding:
			FX.flash(visual.body_node(), Color(0.6, 0.8, 1.0))
	else:
		guarding = false


func _attack_damage(mult: float) -> Dictionary:
	var atk := float(stats["atk"]) + status.attack_bonus()
	return {"damage": maxi(1, int(round(atk * mult))), "knockback": 140.0, "source": self}


func _do_basic_attack() -> void:
	var basic: Dictionary = combat_def().get("basic", {})
	var dmgs: Array = basic.get("dmg", [8, 8, 12])
	var hits := int(basic.get("hits", dmgs.size()))
	var idx := mini(combo_index, dmgs.size() - 1)
	var mult := float(dmgs[idx]) / 10.0
	combo_index = (combo_index + 1) % hits
	combo_reset_at = Time.get_ticks_msec() / 1000.0 + 0.9
	# lock matches the 3-frame swing at 10fps so every animation plays out
	attack_lock = 0.3 if idx < hits - 1 else 0.42
	visual.play_action("attack_%d" % (idx + 1), facing)
	AudioManager.play_sfx("attack_enemy_1" if idx % 2 == 0 else "attack_enemy_2", -5.0)
	set_meta("swings", int(get_meta("swings", 0)) + 1)
	hitbox.begin_swing(_attack_damage(mult))
	get_tree().create_timer(0.12).timeout.connect(hitbox.end_swing)
	# bare-fisted martial artists (Goku/Piccolo) have no weapon to leave an arc,
	# so the swoosh line just reads as a stray bar — skip it for them
	if String(hero_def.get("weapon_type", "")) != "martial":
		var color := Color(String(hero_def.get("color", "#ffffff")))
		var from := global_position + facing.rotated(-0.7) * 16.0
		var to := global_position + facing.rotated(0.7) * 16.0
		FX.attack_trail(get_parent(), from, to, color)
	_gain_meter(2.0)


func _do_special() -> void:
	var sp: Dictionary = combat_def().get("special", {})
	var cost := float(sp.get("cost", 30))
	if meter < cost or special_cooldown > 0.0:
		# always acknowledge the press — a silent no-op reads as "special is
		# not implemented" when the meter is simply empty
		if meter < cost:
			FX.flash(visual.body_node(), Color(0.35, 0.45, 0.9))
		return
	meter -= cost
	meter_changed.emit(meter)
	special_cooldown = 0.6
	attack_lock = 0.3
	# real special-move frames when the manifest has them (no-op otherwise)
	visual.play_action("special", facing)
	var kind := String(sp.get("kind", "burst"))
	var color := Color(String(hero_def.get("color", "#ffffff")))
	var dmg_ratio := float(sp.get("dmg", 20)) / 10.0
	match kind:
		"projectile":
			_spawn_projectile(float(sp.get("speed", 280)), dmg_ratio, color)
		"burst", "spin", "clones":
			var radius := float(sp.get("radius", 60))
			_aoe_damage(radius, dmg_ratio * (float(sp.get("count", 1)) if kind == "clones" else 1.0))
			FX.burst(get_parent(), global_position, color, 18)
			FX.shake(3.0)
		"dash":
			movement.dash(facing, float(sp.get("distance", 90)), 0.16)
			health.grant_iframes(0.2)
			hitbox.begin_swing(_attack_damage(dmg_ratio))
			get_tree().create_timer(0.25).timeout.connect(hitbox.end_swing)
			FX.attack_trail(get_parent(), global_position, global_position + facing * 40.0, color)
		"bomb":
			var bomb := Bomb.new()
			bomb.setup(_attack_damage(dmg_ratio), float(sp.get("radius", 60)),
				float(sp.get("fuse", 2.0)), CombatHero.LAYER_ENEMY_HURT)
			bomb.global_position = global_position + facing.normalized() * 12.0
			get_parent().add_child(bomb)
		"nova":
			# ring bursts around the body center, not the feet pivot
			var nova := Nova.new()
			nova.setup(_attack_damage(dmg_ratio), sp)
			nova.global_position = global_position + Vector2(0.0, -12.0)
			get_parent().add_child(nova)
			FX.shake(2.5)
		"beam":
			# hold the firing pose for the beam's grow+hold duration
			attack_lock = 0.6
			var beam := Beam.new()
			beam.setup(_attack_damage(dmg_ratio), facing, sp, CombatHero.LAYER_ENEMY_HURT)
			# origin at the hands/chest, not the feet pivot (was firing from the knee).
			# The side firing pose reaches further forward than the up/down poses,
			# so give horizontal beams more reach or they emerge from the torso.
			var reach := 18.0 if absf(facing.x) > 0.5 else 12.0
			beam.global_position = global_position + facing.normalized() * reach + Vector2(0.0, -24.0)
			get_parent().add_child(beam)
			FX.shake(2.0)


func _spawn_projectile(speed: float, dmg_ratio: float, color: Color) -> void:
	var p := Projectile.new()
	var sp: Dictionary = hero_def.get("combat", {}).get("special", {})
	var tex: Texture2D = null
	var tex_path := String(sp.get("sprite", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	p.setup(_attack_damage(dmg_ratio), facing, speed, color, CombatHero.LAYER_ENEMY_HURT, tex)
	p.global_position = global_position + facing * 10.0
	get_parent().add_child(p)


func _aoe_damage(radius: float, dmg_ratio: float) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy != null and is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= radius:
			if enemy.has_method("take_packet"):
				enemy.take_packet(_attack_damage(dmg_ratio), global_position)


func _do_dodge(pressed: bool) -> void:
	var dodge: Dictionary = combat_def().get("dodge", {})
	var kind := String(dodge.get("kind", "roll"))
	if kind == "guard" or not pressed:
		return
	# fly glides a touch longer than a snap roll so it doesn't cover ground too fast
	var dash_time := 0.22 if kind == "fly" else 0.16
	movement.dash(facing, float(dodge.get("distance", 70)), dash_time)
	health.grant_iframes(float(dodge.get("iframes", 0.35)))
	# real roll/fly frames when the manifest has them (play_action no-ops otherwise)
	visual.play_action("fly" if kind == "fly" else "roll", facing)
	if kind == "vanish":
		visual.modulate.a = 0.25
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(visual):
				visual.modulate.a = 1.0)
	else:
		FX.flash(visual.body_node(), Color(0.8, 0.8, 1.0))


func _use_consumable() -> void:
	if consumables.is_empty():
		return
	var id := String(consumables.pop_front())
	var fx: Dictionary = ContentDatabase.get_item(id).get("effect", {})
	if fx.has("heal"):
		health.heal(int(fx["heal"]))
	if fx.has("meter"):
		_gain_meter(float(fx["meter"]))
	if fx.has("buff_atk"):
		status.apply_effect("buff_atk", float(fx["buff_atk"]), 20.0)
	if fx.has("buff_def"):
		status.apply_effect("buff_def", float(fx["buff_def"]), 20.0)
	if fx.has("invincible"):
		health.grant_iframes(float(fx["invincible"]))
	if fx.has("aoe_damage"):
		_aoe_damage(90.0, float(fx["aoe_damage"]) / 10.0)
		FX.shake(5.0)
	if fx.has("ranged_damage"):
		var p := Projectile.new()
		p.setup(_attack_damage(float(fx["ranged_damage"]) / 10.0), facing.normalized(),
			320.0, Color(String(hero_def.get("color", "#ffffff"))), CombatHero.LAYER_ENEMY_HURT)
		p.global_position = global_position + facing.normalized() * 12.0
		get_parent().add_child(p)
	if fx.has("stun"):
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Node2D
			if e != null and is_instance_valid(e) and e.has_method("apply_stun") \
					and e.global_position.distance_to(global_position) <= 110.0:
				e.apply_stun(float(fx["stun"]))
	if fx.has("self_damage"):
		# trap items (the poison mushroom) — honest about being a bad idea
		health.take_damage(int(fx["self_damage"]), self)
		FX.flash(visual.body_node(), Color(0.6, 1.0, 0.4))
	if fx.has("revive"):
		revives_available += 1
	hp_changed.emit(health.hp, health.max_hp)
	consumables_changed.emit(consumables)
	FX.burst(get_parent(), global_position, Color(0.5, 1.0, 0.6), 8)


func _do_finisher() -> void:
	var mm := float(ContentDatabase.bal("dungeon", {}).get("meter_max", 100))
	if meter < mm:
		return
	meter = 0.0
	meter_changed.emit(meter)
	var fin: Dictionary = combat_def().get("finisher", {})
	var color := Color(String(hero_def.get("color", "#ffffff")))
	attack_lock = 0.5
	var radius := float(fin.get("radius", 90))
	if bool(fin.get("beam", false)):
		# beam: long forward strike
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var to_enemy := enemy.global_position - global_position
			if to_enemy.length() < radius * 2.2 and absf(facing.angle_to(to_enemy)) < 0.5:
				if enemy.has_method("take_packet"):
					enemy.take_packet(_attack_damage(float(fin.get("dmg", 80)) / 10.0), global_position)
		FX.attack_trail(get_parent(), global_position, global_position + facing * radius * 2.2, color)
	else:
		_aoe_damage(radius, float(fin.get("dmg", 80)) / 10.0)
	FX.burst(get_parent(), global_position, color, 30)
	FX.shake(float(ContentDatabase.bal("dungeon", {}).get("shake_heavy", 6.0)))
	FX.hit_pause(get_tree(), 120)


func _gain_meter(amount: float) -> void:
	var mm := float(ContentDatabase.bal("dungeon", {}).get("meter_max", 100))
	meter = minf(mm, meter + amount)
	meter_changed.emit(meter)


func on_enemy_hit() -> void:
	set_meta("hits", int(get_meta("hits", 0)) + 1)
	_gain_meter(float(ContentDatabase.bal("dungeon", {}).get("meter_gain_per_hit", 6)))


func on_enemy_killed() -> void:
	_gain_meter(float(ContentDatabase.bal("dungeon", {}).get("meter_gain_per_kill", 15)))


var _low_hp_warned: bool = false


func _on_hit(packet: Dictionary, from_position: Vector2) -> void:
	movement.knockback(from_position, global_position, float(packet.get("knockback", 120)))
	health.grant_iframes(float(ContentDatabase.bal("dungeon", {}).get("iframes_hurt", 0.8)))
	FX.flash(visual.body_node(), Color(1, 0.4, 0.4))
	FX.shake(2.5)
	FX.damage_number(get_parent(), global_position, int(packet.get("damage", 0)), Color(1, 0.5, 0.5))
	if packet.get("source") is Boss:
		AudioManager.play_sfx("enemy_boss_attack_you", -3.0)
	if health.hp <= health.max_hp * 0.25 and not _low_hp_warned:
		_low_hp_warned = true
		AudioManager.play_sfx("player_low_health")
	elif health.hp > health.max_hp * 0.4:
		_low_hp_warned = false
	hp_changed.emit(health.hp, health.max_hp)
	_blink_iframes()


func _blink_iframes() -> void:
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(visual, "modulate:a", 0.4, 0.08)
		tw.tween_property(visual, "modulate:a", 1.0, 0.08)


func _on_died() -> void:
	if revives_available > 0:
		revives_available -= 1
		var ratio := float(ContentDatabase.bal("dungeon", {}).get("revive_heal_ratio", 0.5))
		health.revive(ratio)
		FX.burst(get_parent(), global_position, Color(1, 0.95, 0.5), 24)
		hp_changed.emit(health.hp, health.max_hp)
		return
	AudioManager.play_sfx("player_death")
	visual.modulate = Color(0.5, 0.5, 0.5, 0.6)
	defeated.emit()
