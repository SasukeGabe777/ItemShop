extends Node
## DungeonManager: expedition planning, room layout generation from handcrafted
## templates, and a deterministic logic-level expedition simulator used by
## tests and the economy simulation.

signal expedition_finished(result: Dictionary)

var pending: Dictionary = {}     # {world_id, hero_id, consumables: Array, vertical_slice: bool}
var run_loot: Dictionary = {}    # item_id -> qty gathered during a live run
var run_gold: int = 0
var run_kills: int = 0
var rng := RandomNumberGenerator.new()


func reset() -> void:
	pending.clear()
	run_loot.clear()
	run_gold = 0
	run_kills = 0
	rng.randomize()


func plan_expedition(world_id: String, hero_id: String, consumables: Array = [], vertical_slice: bool = false) -> void:
	pending = {
		"world_id": world_id, "hero_id": hero_id,
		"consumables": consumables.duplicate(), "vertical_slice": vertical_slice,
	}
	run_loot.clear()
	run_gold = 0
	run_kills = 0


## Generate the run's room sequence from handcrafted templates.
func generate_layout(world_id: String, seed_value: int = -1, vertical_slice: bool = false) -> Array[Dictionary]:
	if vertical_slice:
		var slice_layout := _vertical_slice_layout(world_id)
		if not slice_layout.is_empty():
			return slice_layout
	var w := ContentDatabase.get_world(world_id)
	var room_count := int(w.get("rooms", 5))
	var lrng := RandomNumberGenerator.new()
	lrng.seed = seed_value if seed_value >= 0 else randi()
	var starts := ContentDatabase.room_templates_by_kind("start")
	var combats := ContentDatabase.room_templates_by_kind("combat")
	var treasures := ContentDatabase.room_templates_by_kind("treasure")
	var boss_rooms := ContentDatabase.room_templates_by_kind("boss")
	# each run fields a different warband drawn from the world's full roster —
	# shadows are the Fade's foot soldiers and always march
	var full_pool: Array = w.get("enemies", [])
	var run_pool: Array = []
	if "shadow_heartless" in full_pool:
		run_pool.append("shadow_heartless")
	var others: Array = full_pool.filter(func(e: Variant) -> bool: return not (e in run_pool))
	for i in range(others.size() - 1, 0, -1):
		var j := lrng.randi_range(0, i)
		var tmp: Variant = others[i]
		others[i] = others[j]
		others[j] = tmp
	for i in range(mini(4, others.size())):
		run_pool.append(others[i])
	var layout: Array[Dictionary] = []
	layout.append(_room_entry(starts[lrng.randi() % starts.size()], world_id, lrng, 0, run_pool))
	var middle := maxi(1, room_count - 2)
	var treasure_at := lrng.randi_range(0, middle - 1) if middle > 1 else -1
	for i in range(middle):
		if i == treasure_at:
			layout.append(_room_entry(treasures[lrng.randi() % treasures.size()], world_id, lrng, i + 1, run_pool))
		else:
			layout.append(_room_entry(combats[lrng.randi() % combats.size()], world_id, lrng, i + 1, run_pool))
	layout.append(_room_entry(boss_rooms[lrng.randi() % boss_rooms.size()], world_id, lrng, room_count - 1, run_pool))
	return layout


## The first playable expedition is a deliberately small, data-selected preset.
## It still uses the regular room schema and live dungeon scene.
func _vertical_slice_layout(world_id: String) -> Array[Dictionary]:
	var cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	if world_id != String(cfg.get("world_id", "")):
		return []
	var start: Dictionary = ContentDatabase.rooms.get(String(cfg.get("start_room_id", "")), {})
	var combat: Dictionary = ContentDatabase.rooms.get(String(cfg.get("combat_room_id", "")), {})
	var enemy_id := String(cfg.get("enemy_id", ""))
	if start.is_empty() or combat.is_empty() or ContentDatabase.get_enemy(enemy_id).is_empty():
		push_warning("[DungeonManager] vertical-slice content is incomplete; using the normal layout")
		return []
	return [
		{"template": start, "kind": "start", "enemies": [], "depth": 0},
		{"template": combat, "kind": "combat", "enemies": [enemy_id], "depth": 1},
	]


func _room_entry(template: Dictionary, world_id: String, lrng: RandomNumberGenerator, depth: int, pool_override: Array = []) -> Dictionary:
	var w := ContentDatabase.get_world(world_id)
	var pool: Array = pool_override if not pool_override.is_empty() else w.get("enemies", [])
	var spawn_list: Array = []
	var kind := String(template.get("kind", "combat"))
	if kind == "boss":
		spawn_list.append(boss_for_world(world_id))
	else:
		for p in template.get("spawns", []):
			if pool.is_empty():
				break
			spawn_list.append(String(pool[lrng.randi() % pool.size()]))
		# the Fade's shadows always show up somewhere in a fight
		if not spawn_list.is_empty() and "shadow_heartless" in pool and not ("shadow_heartless" in spawn_list):
			spawn_list[0] = "shadow_heartless"
	return {"template": template, "kind": kind, "enemies": spawn_list, "depth": depth}


## The boss escalates with each completed expedition: worlds may define a
## "boss_rotation" list walked by the number of boss kills there.
func boss_for_world(world_id: String) -> String:
	var w := ContentDatabase.get_world(world_id)
	var rotation: Array = w.get("boss_rotation", [])
	if rotation.is_empty():
		return String(w.get("boss", ""))
	var wins := int(GameState.stats.get("expedition_wins_%s" % world_id, 0))
	return String(rotation[mini(wins, rotation.size() - 1)])


func add_run_loot(item_id: String, qty: int = 1) -> void:
	if item_id == "":
		return
	run_loot[item_id] = int(run_loot.get(item_id, 0)) + qty


## Roll an enemy's loot table. Returns array of item ids.
func roll_loot(enemy_id: String, bonus: float = 0.0) -> Array[String]:
	var e := ContentDatabase.get_enemy(enemy_id)
	var out: Array[String] = []
	for entry in e.get("loot", []):
		var chance := float(entry[1]) * (1.0 + bonus)
		if rng.randf() < chance:
			# loot tables may name retired filler items; drop the live stand-in
			out.append(ContentDatabase.live_substitute(String(entry[0])))
	return out


func roll_gold(enemy_id: String) -> int:
	var e := ContentDatabase.get_enemy(enemy_id)
	var g: Array = e.get("gold", [0, 0])
	return int(round(rng.randi_range(int(g[0]), int(g[1])) * MarketManager.prosperity()))


## Apply a finished run's spoils and notify.
func finish_expedition(success: bool, boss_defeated: bool, hp_left: int) -> Dictionary:
	var world_id := String(pending.get("world_id", ""))
	var vertical_slice := bool(pending.get("vertical_slice", false))
	for id: String in run_loot:
		InventoryManager.add_item(id, int(run_loot[id]))
	EconomyManager.add_gold(run_gold)
	GameState.add_stat("expeditions")
	if boss_defeated:
		# drives the boss rotation and the gates panel's mastery star
		GameState.add_stat("expedition_wins_%s" % world_id)
	if success and vertical_slice:
		var slice_cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
		var completion_flag := String(slice_cfg.get("completion_flag", ""))
		if completion_flag != "":
			GameState.set_flag(completion_flag)
	if boss_defeated:
		if world_id == "null_archive":
			BridgeManager.defeat_fade()
			StoryEventManager.fire("boss_defeated", {"chapter": 8})
		else:
			var had := BridgeManager.has_shard(world_id)
			BridgeManager.collect_shard(world_id)
			if not had:
				StoryEventManager.fire("boss_defeated", {"chapter": int(ContentDatabase.get_world(world_id).get("chapter", 0))})
	var result := {
		"success": success, "boss_defeated": boss_defeated, "world_id": world_id,
		"vertical_slice": vertical_slice,
		"loot": run_loot.duplicate(), "gold": run_gold, "hp_left": hp_left,
		"kills": run_kills,
	}
	run_loot.clear()
	run_gold = 0
	run_kills = 0
	pending.clear()
	expedition_finished.emit(result)
	return result


## Deterministic, logic-level expedition simulation (no scene). Used by the
## headless test suite and the 35-day economy sim; mirrors combat math closely
## enough for balance work.
func simulate_expedition(world_id: String, hero_id: String, seed_value: int = 1, consumables: Array = []) -> Dictionary:
	var srng := RandomNumberGenerator.new()
	srng.seed = seed_value
	var stats := InventoryManager.hero_stats(hero_id)
	var hp := int(stats["hp"])
	var atk := int(stats["atk"])
	var def := int(stats["def"])
	var spd := int(stats["spd"])
	var loot: Dictionary = {}
	var gold := 0
	var heals: Array = consumables.duplicate()
	var layout := generate_layout(world_id, seed_value)
	var boss_defeated := false
	for room in layout:
		var is_boss_room := String(room["kind"]) == "boss"
		for enemy_id: String in room["enemies"]:
			var e := ContentDatabase.get_enemy(enemy_id)
			if e.is_empty():
				continue
			var ehp := int(e.get("hp", 20))
			var eatk := int(e.get("atk", 5))
			var espd := int(e.get("spd", 90))
			# Hits to kill vs hits taken: speed advantage reduces damage taken.
			# The 1.25 factor approximates specials/finishers earned over a fight.
			var hero_dps := float(atk) * (1.3 + float(spd) / 200.0) * 1.25
			var seconds := float(ehp) / maxf(1.0, hero_dps)
			var dodge_factor := clampf(1.0 - float(spd - espd) / 400.0, 0.3, 1.25)
			# trash mobs are easily kited; bosses force real exposure
			var exposure := 0.8 if is_boss_room else 0.4
			var incoming := float(eatk) * exposure * seconds * dodge_factor * srng.randf_range(0.75, 1.25)
			var mitigated := incoming * (1.0 - clampf(float(def) / 60.0, 0.0, 0.6))
			# a competent player never face-tanks a whole boss: cap what a single
			# enemy can deal across the fight to just over half the hero's health
			mitigated = minf(mitigated, float(stats["hp"]) * 0.55 * srng.randf_range(0.85, 1.15))
			hp -= int(round(mitigated))
			if hp <= 0 and not heals.is_empty():
				var heal_id := String(heals.pop_back())
				var fx: Dictionary = ContentDatabase.get_item(heal_id).get("effect", {})
				hp = mini(int(stats["hp"]), maxi(1, int(fx.get("heal", 40))))
			if hp <= 0:
				return {"success": false, "boss_defeated": boss_defeated, "loot": loot, "gold": gold, "hp_left": 0}
			gold += int(round(srng.randi_range(int(e.get("gold", [0, 0])[0]), int(e.get("gold", [0, 0])[1])) * MarketManager.prosperity()))
			for entry in e.get("loot", []):
				if srng.randf() < float(entry[1]):
					var lid := ContentDatabase.live_substitute(String(entry[0]))
					loot[lid] = int(loot.get(lid, 0)) + 1
			if String(room["kind"]) == "boss":
				boss_defeated = true
		if String(room["kind"]) == "treasure":
			var w := ContentDatabase.get_world(world_id)
			var goods: Array = w.get("market_goods", [])
			if not goods.is_empty():
				var prize := ContentDatabase.live_substitute(String(goods[srng.randi() % goods.size()]))
				loot[prize] = int(loot.get(prize, 0)) + 1
	return {"success": true, "boss_defeated": boss_defeated, "loot": loot, "gold": gold, "hp_left": hp}
