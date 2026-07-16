extends Node2D
## Windowed live-combat test: spawns Sora vs a boss, drives inputs
## programmatically, verifies damage, loot drops and boss death.

var hero: CombatHero
var boss: Boss
var elapsed: float = 0.0
var boss_died: bool = false
var hero_was_hit: bool = false
var reported: bool = false


func _ready() -> void:
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	DungeonManager.reset()
	DungeonManager.plan_expedition("kingdom_hearts", "sora", [])
	var floor_poly := Polygon2D.new()
	floor_poly.polygon = PackedVector2Array([Vector2.ZERO, Vector2(640, 0), Vector2(640, 384), Vector2(0, 384)])
	floor_poly.color = Color("#2c3050")
	floor_poly.z_index = -10
	add_child(floor_poly)
	hero = CombatHero.new()
	add_child(hero)
	hero.setup("sora", ["kh_elixir", "kh_elixir", "kh_elixir"])
	hero.position = Vector2(200, 200)
	hero.health.damaged.connect(func(_a: int, _s: Node) -> void: hero_was_hit = true)
	boss = Boss.new()
	add_child(boss)
	boss.setup("corrupted_fat_bandit", hero)
	boss.position = Vector2(300, 200)
	boss.health.setup(100)  # shortened fight for the smoke test
	boss.killed.connect(func(_id: String, _at: Vector2) -> void: boss_died = true)
	boss.health.damaged.connect(func(a: int, _s: Node) -> void:
		print("t=%.1f boss took %d (hp %d) dist %.0f" % [elapsed, a, boss.health.hp, hero.global_position.distance_to(boss.global_position)]))


func _physics_process(delta: float) -> void:
	elapsed += delta
	if reported:
		return
	if elapsed > 70.0:
		_report()
		return
	# drive the hero: chase the boss, attack whenever in reach
	if boss != null and is_instance_valid(boss) and not boss.health.dead:
		var to_boss := boss.global_position - hero.global_position
		var dist := to_boss.length()
		if dist > 40.0:
			Input.action_press("move_right" if to_boss.x > 0 else "move_left")
			Input.action_press("move_down" if to_boss.y > 0 else "move_up")
		else:
			for a in ["move_right", "move_left", "move_down", "move_up"]:
				Input.action_release(a)
		# alternate press/release so is_action_just_pressed fires repeatedly
		if dist < 60.0 and Engine.get_physics_frames() % 4 < 2:
			Input.action_press("attack")
		else:
			Input.action_release("attack")
		if hero.meter >= 40.0:
			Input.action_press("special")
		else:
			Input.action_release("special")
		if hero.health.hp < 50 and not hero.consumables.is_empty() and Engine.get_physics_frames() % 6 < 3:
			Input.action_press("use_item")
		else:
			Input.action_release("use_item")
		if hero.health.dead:
			_report()
	elif boss_died:
		for a in ["attack", "special", "use_item"]:
			Input.action_release(a)
		# walk to the nearest dropped pickup so it magnetizes and banks
		var nearest: Node2D = null
		var best := 1e9
		for node in get_children():
			if node is LootPickup and is_instance_valid(node):
				var d: float = (node as Node2D).global_position.distance_to(hero.global_position)
				if d < best:
					best = d
					nearest = node
		if nearest != null:
			var to_loot: Vector2 = nearest.global_position - hero.global_position
			if to_loot.x != 0.0:
				Input.action_press("move_right" if to_loot.x > 0 else "move_left")
			if to_loot.y != 0.0:
				Input.action_press("move_down" if to_loot.y > 0 else "move_up")
		else:
			for a in ["move_right", "move_left", "move_down", "move_up"]:
				Input.action_release(a)
			if not DungeonManager.run_loot.is_empty() or DungeonManager.run_gold > 0:
				_report()


func _report() -> void:
	reported = true
	var failures: Array[String] = []
	print("swings=%d hits=%d" % [hero.get_meta("swings", 0), hero.get_meta("hits", 0)])
	if not boss_died:
		failures.append("boss not defeated in time (hp left %d)" % (boss.health.hp if is_instance_valid(boss) else -1))
	var got_loot := not DungeonManager.run_loot.is_empty() or DungeonManager.run_gold > 0
	if boss_died and not got_loot:
		failures.append("no loot banked after boss kill")
	if failures.is_empty():
		print("LIVE_COMBAT_PASS (boss died=%s, loot=%s, gold=%d, hero hit=%s, hero hp=%d)" % [
			boss_died, DungeonManager.run_loot, DungeonManager.run_gold, hero_was_hit, hero.health.hp])
	else:
		for f_msg in failures:
			printerr("LIVE_COMBAT_FAIL: " + f_msg)
	get_tree().quit(0 if failures.is_empty() else 1)
