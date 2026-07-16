class_name Boss
extends Enemy
## Boss: an Enemy with telegraphed attack patterns and phases. Attack names in
## enemies.json map onto four parameterized archetypes so every boss stays
## data-driven while feeling distinct (speed/size/damage/color vary).

signal boss_hp_changed(hp: int, max_hp: int)

var attack_names: Array = []
var telegraph_time: float = 0.7
var _attack_cooldown: float = 2.0
var _telegraph: Node2D
var phases: int = 1
var _phase: int = 1


func setup(id: String, player: Node2D) -> void:
	super.setup(id, player)
	attack_names = def.get("attacks", [])
	telegraph_time = float(def.get("telegraph", 0.7))
	phases = int(def.get("phases", 1))
	health.damaged.connect(func(_a: int, _s: Node) -> void:
		boss_hp_changed.emit(health.hp, health.max_hp)
		_check_phase())
	add_to_group("boss")


func _check_phase() -> void:
	var ratio := float(health.hp) / float(health.max_hp)
	var next_phase := phases - int(floor(ratio * phases)) if ratio > 0.0 else phases
	next_phase = clampi(next_phase, 1, phases)
	if next_phase > _phase:
		_phase = next_phase
		FX.shake(8.0)
		FX.burst(get_parent(), global_position, Color(1, 0.3, 0.3), 30)
		_attack_cooldown = 0.5  # enraged: attack sooner


func _physics_process(delta: float) -> void:
	if health.dead or target == null or not is_instance_valid(target):
		return
	_attack_cooldown -= delta * (1.0 + 0.35 * (_phase - 1))
	if _attack_cooldown <= 0.0 and _state != "telegraph":
		_start_attack()
	if _state == "telegraph":
		_state_time -= delta
		if _state_time <= 0.0:
			_state = "idle"
			_execute_attack()
		return  # stands still while telegraphing
	super._physics_process(delta)


func _start_attack() -> void:
	if attack_names.is_empty():
		_attack_cooldown = 2.0
		return
	_state = "telegraph"
	_state_time = telegraph_time
	set_meta("pending_attack", attack_names[rng.randi() % attack_names.size()])
	# telegraph visual: pulsing warning ring
	_telegraph = Node2D.new()
	var ring := Sprite2D.new()
	var size := int(def.get("size", 30)) * 3
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c + 0.5, y - c + 0.5).length()
			if d < c and d > c - 3.0:
				img.set_pixel(x, y, Color(1, 0.25, 0.2, 0.8))
	ring.texture = ImageTexture.create_from_image(img)
	_telegraph.add_child(ring)
	add_child(_telegraph)
	var tw := _telegraph.create_tween().set_loops()
	tw.tween_property(_telegraph, "scale", Vector2(0.6, 0.6), 0.18)
	tw.tween_property(_telegraph, "scale", Vector2(1.0, 1.0), 0.18)
	FX.flash(visual.body_node(), Color(1, 0.4, 0.3))


func _execute_attack() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
		_telegraph = null
	var attack := String(get_meta("pending_attack", ""))
	_attack_cooldown = rng.randf_range(1.6, 2.6)
	var idx := attack_names.find(attack)
	match idx % 4:
		0:  # heavy slam: close-range AOE burst
			_slam()
		1:  # projectile volley
			_volley()
		2:  # charge dash / pull
			_charge()
		3:  # summon minions or storm
			_summon_or_storm()


func _slam() -> void:
	FX.shake(float(ContentDatabase.bal("dungeon", {}).get("shake_heavy", 6.0)))
	FX.burst(get_parent(), global_position, Color(String(def.get("color", "#ffffff"))), 26)
	if _to_player().length() < float(def.get("size", 30)) * 2.2:
		(target.get_node("HurtboxComponent") as HurtboxComponent).receive(
			{"damage": int(def.get("atk", 15)), "knockback": 260.0, "source": self}, global_position)


func _volley() -> void:
	var count := 6 + _phase * 2
	for i in range(count):
		var ang := TAU * float(i) / float(count)
		var p := Projectile.new()
		p.setup({"damage": int(def.get("atk", 15)) / 2 + 2, "knockback": 120.0, "source": self},
			Vector2.RIGHT.rotated(ang), 130.0, Color(String(def.get("color", "#ffffff"))).lightened(0.4), 16)
		p.global_position = global_position
		get_parent().add_child(p)


func _charge() -> void:
	movement.dash(_to_player(), _to_player().length() + 40.0, 0.35)
	hitbox.begin_swing({"damage": int(def.get("atk", 15)), "knockback": 240.0, "source": self})
	get_tree().create_timer(0.4).timeout.connect(hitbox.end_swing)
	FX.attack_trail(get_parent(), global_position, target.global_position, Color(1, 0.5, 0.4))


func _summon_or_storm() -> void:
	var world_id := String(def.get("world", ""))
	var minions: Array = ContentDatabase.get_world(world_id).get("enemies", [])
	if not minions.is_empty() and get_tree().get_nodes_in_group("enemies").size() < 7:
		for i in range(2):
			var minion := Enemy.new()
			get_parent().add_child(minion)
			minion.setup(String(minions[rng.randi() % minions.size()]), target)
			minion.global_position = global_position + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
	else:
		# targeted storm: three projectiles aimed at the player
		for i in range(3):
			var p := Projectile.new()
			var spread := (i - 1) * 0.25
			p.setup({"damage": int(def.get("atk", 15)) / 2 + 3, "knockback": 140.0, "source": self},
				_to_player().rotated(spread), 190.0, Color(0.8, 0.6, 1.0), 16)
			p.global_position = global_position
			get_parent().add_child(p)
