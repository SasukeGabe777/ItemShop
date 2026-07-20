extends Node2D
## Probe: consumables. Verifies every selectable consumable/food item has an
## effect the engine actually implements, that using a healing item raises HP,
## that Player 2 receives their own belt in a co-op run, and that the effect
## summary shown in the picker is non-empty.

const HANDLED := ["heal", "meter", "buff_atk", "buff_def", "invincible",
	"aoe_damage", "ranged_damage", "stun", "self_damage", "revive"]


func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_campaign()

	# --- every selectable item does something the engine implements ---------
	var selectable: Array[String] = []
	for id: String in ContentDatabase.items:
		var cat := String(ContentDatabase.get_item(id).get("category", ""))
		if cat in ["consumable", "food"]:
			selectable.append(id)
	var no_effect: Array[String] = []
	var unhandled: Array[String] = []
	var no_summary: Array[String] = []
	for id in selectable:
		var fx: Dictionary = ContentDatabase.get_item(id).get("effect", {})
		if fx.is_empty():
			no_effect.append(id)
			continue
		var ok := false
		for k: String in fx:
			if k in HANDLED:
				ok = true
			else:
				if not unhandled.has("%s:%s" % [id, k]):
					unhandled.append("%s:%s" % [id, k])
		if not ok:
			no_effect.append(id)
		if ContentDatabase.item_effect_summary(id) == "":
			no_summary.append(id)
	print("CONSUM selectable: ", selectable.size())
	print("CONSUM without a working effect: ", no_effect)
	print("CONSUM effect keys the engine ignores: ", unhandled)
	print("CONSUM without a picker summary: ", no_summary)
	# what the expedition picker will actually offer
	var offered: Array[String] = []
	var dead_offered: Array[String] = []
	for id in selectable:
		if ContentDatabase.is_field_usable(id):
			offered.append(id)
			if not ContentDatabase.get_item(id).get("effect", {}).has("heal") \
					and ContentDatabase.item_effect_summary(id) == "":
				dead_offered.append(id)
	print("CONSUM offered by picker: ", offered.size(), " of ", selectable.size())
	print("CONSUM offered but useless: ", dead_offered)
	var healers := 0
	for id in offered:
		if ContentDatabase.get_item(id).get("effect", {}).has("heal"):
			healers += 1
	print("CONSUM healing items offered: ", healers)

	# --- healing actually heals, for a hero at low HP -----------------------
	var hero := CombatHero.new()
	add_child(hero)
	hero.setup("sora", ["hi_potion", "oran_berry"])
	hero.health.take_damage(hero.health.max_hp - 5, self)
	var before := hero.health.hp
	hero._use_consumable()
	var after := hero.health.hp
	print("HEAL hi_potion: %d -> %d (+%d), belt now %s" % [before, after, after - before, hero.consumables])
	var before2 := hero.health.hp
	hero.health.take_damage(after - 5, self)
	hero._use_consumable()
	print("HEAL oran_berry: %d -> %d, belt now %s" % [5, hero.health.hp, hero.consumables])

	# a formerly-dead item now works
	var hero3 := CombatHero.new()
	add_child(hero3)
	hero3.setup("sora", ["super_potion"])
	hero3.health.take_damage(hero3.health.max_hp - 5, self)
	var b3 := hero3.health.hp
	hero3._use_consumable()
	print("HEAL super_potion (was a no-op): %d -> %d" % [b3, hero3.health.hp])

	# --- co-op: player 2 gets their own belt --------------------------------
	MultiplayerState.enabled = true
	DungeonManager.plan_expedition("kingdom_hearts", "sora", ["hi_potion"], false,
		"donald" if not ContentDatabase.get_hero("donald").is_empty() else "sora", ["ff_potion", "oran_berry"])
	print("PLAN p1 belt: ", DungeonManager.pending.get("consumables"))
	print("PLAN p2 belt: ", DungeonManager.pending.get("consumables2"))

	var prober := Node.new()
	prober.set_script(preload("res://tests/consumable_shot_stage.gd"))
	get_tree().root.add_child(prober)
	TimeManager.reset(1)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	SceneRouter.go("dungeon")
