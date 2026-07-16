extends Node
## DungeonManager: expedition planning, room layout generation from handcrafted
## templates, and a deterministic logic-level expedition simulator used by
## tests and the economy simulation.

signal expedition_finished(result: Dictionary)

var pending: Dictionary = {}     # {world_id, hero_id, consumables: Array}
var run_loot: Dictionary = {}    # item_id -> qty gathered during a live run
var run_gold: int = 0
var rng := RandomNumberGenerator.new()


func reset() -> void:
	pending.clear()
	run_loot.clear()
	run_gold = 0
	rng.randomize()


func plan_expedition(world_id: String, hero_id: String, consumables: Array = []) -> void:
	pending = {"world_id": world_id, "hero_id": hero_id, "consumables": consumables.duplicate()}
	run_loot.clear()
	run_gold = 0


## Generate the run's room sequence from handcrafted templates.
func generate_layout(world_id: String, seed_value: int = -1) -> Array[Dictionary]:
	var w := ContentDatabase.get_world(world_id)
	var room_count := int(w.get("rooms", 5))
	var lrng := RandomNumberGenerator.new()
	lrng.seed = seed_value if seed_value >= 0 else randi()
	var starts := ContentDatabase.room_templates_by_kind("start")
	var combats := ContentDatabase.room_templates_by_kind("combat")
	var treasures := ContentDatabase.room_templates_by_kind("treasure")
	var boss_rooms := ContentDatabase.room_templates_by_kind("boss")
	var layout: Array[Dictionary] = []
	layout.append(_room_entry(starts[lrng.randi() % starts.size()], world_id, lrng, 0))
	var middle := maxi(1, room_count - 2)
	var treasure_at := lrng.randi_range(0, middle - 1) if middle > 1 else -1
	for i in range(middle):
		if i == treasure_at:
			layout.append(_room_entry(treasures[lrng.randi() % treasures.size()], world_id, lrng, i + 1))
		else:
			layout.append(_room_entry(combats[lrng.randi() % combats.size()], world_id, lrng, i + 1))
	layout.append(_room_entry(boss_rooms[lrng.randi() % boss_rooms.size()], world_id, lrng, room_count - 1))
	return layout


func _room_entry(template: Dictionary, world_id: String, lrng: RandomNumberGenerator, depth: int) -> Dictionary:
	var w := ContentDatabase.get_world(world_id)
	var pool: Array = w.get("enemies", [])
	var spawn_list: Array = []
	var kind := String(template.get("kind", "combat"))
	if kind == "boss":
		spawn_list.append(String(w.get("boss", "")))
	else:
		for p in template.get("spawns", []):
			if pool.is_empty():
				break
			spawn_list.append(String(pool[lrng.randi() % pool.size()]))
	return {"template": template, "kind": kind, "enemies": spawn_list, "depth": depth}


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
			out.append(String(entry[0]))
	return out


func roll_gold(enemy_id: String) -> int:
	var e := ContentDatabase.get_enemy(enemy_id)
	var g: Array = e.get("gold", [0, 0])
	return rng.randi_range(int(g[0]), int(g[1]))


## Apply a finished run's spoils and notify.
func finish_expedition(success: bool, boss_defeated: bool, hp_left: int) -> Dictionary:
	var world_id := String(pending.get("world_id", ""))
	for id: String in run_loot:
		InventoryManager.add_item(id, int(run_loot[id]))
	EconomyManager.add_gold(run_gold)
	GameState.add_stat("expeditions")
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
		"loot": run_loot.duplicate(), "gold": run_gold, "hp_left": hp_left,
	}
	run_loot.clear()
	run_gold = 0
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
		for enemy_id: String in room["enemies"]:
			var e := ContentDatabase.get_enemy(enemy_id)
			if e.is_empty():
				continue
			var ehp := int(e.get("hp", 20))
			var eatk := int(e.get("atk", 5))
			var espd := int(e.get("spd", 90))
			# Hits to kill vs hits taken: speed advantage reduces damage taken.
			var hero_dps := float(atk) * (1.3 + float(spd) / 200.0)
			var seconds := float(ehp) / maxf(1.0, hero_dps)
			var dodge_factor := clampf(1.0 - float(spd - espd) / 400.0, 0.35, 1.25)
			var incoming := float(eatk) * 0.8 * seconds * dodge_factor * srng.randf_range(0.75, 1.25)
			var mitigated := incoming * (1.0 - clampf(float(def) / 60.0, 0.0, 0.6))
			hp -= int(round(mitigated))
			if hp <= 0 and not heals.is_empty():
				var heal_id := String(heals.pop_back())
				var fx: Dictionary = ContentDatabase.get_item(heal_id).get("effect", {})
				hp = mini(int(stats["hp"]), maxi(1, int(fx.get("heal", 40))))
			if hp <= 0:
				return {"success": false, "boss_defeated": boss_defeated, "loot": loot, "gold": gold, "hp_left": 0}
			gold += srng.randi_range(int(e.get("gold", [0, 0])[0]), int(e.get("gold", [0, 0])[1]))
			for entry in e.get("loot", []):
				if srng.randf() < float(entry[1]):
					loot[String(entry[0])] = int(loot.get(String(entry[0]), 0)) + 1
			if String(room["kind"]) == "boss":
				boss_defeated = true
		if String(room["kind"]) == "treasure":
			var w := ContentDatabase.get_world(world_id)
			var goods: Array = w.get("market_goods", [])
			if not goods.is_empty():
				var prize := String(goods[srng.randi() % goods.size()])
				loot[prize] = int(loot.get(prize, 0)) + 1
	return {"success": true, "boss_defeated": boss_defeated, "loot": loot, "gold": gold, "hp_left": hp}
