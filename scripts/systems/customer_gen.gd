class_name CustomerGen
## Builds runtime customer instances for shop sessions. Mixes archetype walk-ins
## with named franchise characters from connected worlds.

static var rng := RandomNumberGenerator.new()


## A runtime customer dictionary:
## {id, name, archetype, budget, hero_ref, color, quirk, line, named}
static func generate_session_customers() -> Array[Dictionary]:
	var shop_cfg: Dictionary = ContentDatabase.bal("shop", {})
	var appeal := InventoryManager.shop_appeal()
	var appeal_total := 0
	for k: String in appeal:
		appeal_total += int(appeal[k])
	var base := int(shop_cfg.get("customers_per_session_base", 4))
	var per := float(shop_cfg.get("customers_per_session_per_appeal", 0.08))
	var n := base + int(floor(appeal_total * per)) + (1 if GameState.shop_level >= 2 else 0)
	n = clampi(n, 2, 9)
	var out: Array[Dictionary] = []
	for i in range(n):
		if rng.randf() < 0.35:
			var named := _pick_named()
			if not named.is_empty():
				out.append(named)
				continue
		out.append(_make_walk_in())
	# the vertical-slice onboarding customer leads the day but never replaces
	# the crowd — a failed scripted sale must not starve the shop of business
	var onboarding_customer := _vertical_slice_customer()
	if not onboarding_customer.is_empty():
		out.insert(0, onboarding_customer)
	return out


## Keep the two sales that bookend the first expedition deterministic. This is
## data-selected and still uses the normal customer, browsing and negotiation AI.
static func _vertical_slice_customer() -> Dictionary:
	var cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	var active_flag := String(cfg.get("active_flag", ""))
	if active_flag == "" or not GameState.has_flag(active_flag):
		return {}
	var customer_id := String(cfg.get("customer_id", ""))
	var src := ContentDatabase.get_named_customer(customer_id)
	if src.is_empty():
		return {}
	var starter_flag := String(cfg.get("starter_sale_flag", ""))
	if starter_flag != "" and not GameState.has_flag(starter_flag):
		return runtime_named(src)
	var completion_flag := String(cfg.get("completion_flag", ""))
	var reward_sale_flag := String(cfg.get("reward_sale_flag", ""))
	var reward_item_id := String(cfg.get("reward_item_id", ""))
	if (
		completion_flag != "" and GameState.has_flag(completion_flag)
		and reward_sale_flag != "" and not GameState.has_flag(reward_sale_flag)
		and reward_item_id in InventoryManager.displayed_ids()
	):
		return runtime_named(src)
	return {}


static func _pick_named() -> Dictionary:
	var pool: Array[Dictionary] = []
	for id: String in ContentDatabase.named_customers:
		var c: Dictionary = ContentDatabase.named_customers[id]
		if int(c.get("chapter", 1)) > TimeManager.chapter:
			continue
		var unlock := String(c.get("unlock", ""))
		if unlock == "boss_defeated":
			var world := String(c.get("world", ""))
			if not BridgeManager.has_shard(world):
				continue
		pool.append(c)
	if pool.is_empty():
		return {}
	var c: Dictionary = pool[rng.randi() % pool.size()]
	return runtime_named(c)


## Public adapter used by development tooling to summon a specific named
## customer without duplicating the live budget/archetype conversion.
static func runtime_named(c: Dictionary) -> Dictionary:
	var arch: Dictionary = ContentDatabase.get_archetype(String(c.get("archetype", "adventurer")))
	var brange: Array = arch.get("budget", [100, 500])
	var mult := float(c.get("budget_mult", 1.0))
	# budgets ride prosperity so late-game repair goals stay reachable
	var chapter_scale := MarketManager.prosperity() * (1.0 + float(ContentDatabase.bal("customer_budget_chapter_scale", 0.25)) * (TimeManager.chapter - 1))
	return {
		"id": String(c["id"]), "name": String(c["name"]),
		"archetype": String(c.get("archetype", "adventurer")),
		"budget": int(rng.randi_range(int(brange[0]), int(brange[1])) * mult * chapter_scale),
		"hero_ref": String(c.get("hero_ref", "")),
		"color": String(c.get("color", ContentDatabase.get_hero(String(c.get("hero_ref", ""))).get("color", "#c0c0c0"))),
		"quirk": String(c.get("quirk", "")), "line": String(c.get("line", "")),
		"named": true, "world": String(c.get("world", "")),
	}


static func _make_walk_in() -> Dictionary:
	var ids: Array = ContentDatabase.archetypes.keys()
	var arch_id := String(ids[rng.randi() % ids.size()])
	var arch: Dictionary = ContentDatabase.get_archetype(arch_id)
	var brange: Array = arch.get("budget", [100, 500])
	var chapter_scale := 1.0 + (TimeManager.chapter - 1) * 0.85
	return {
		"id": "walkin_%s" % arch_id, "name": String(arch.get("name", arch_id)),
		"archetype": arch_id,
		"budget": int(rng.randi_range(int(brange[0]), int(brange[1])) * chapter_scale),
		"hero_ref": "", "color": String(arch.get("color", "#c0c0c0")),
		"quirk": "", "line": "", "named": false, "world": "",
	}


static func likes_item(cust: Dictionary, item_id: String) -> bool:
	var arch: Dictionary = ContentDatabase.get_archetype(String(cust.get("archetype", "")))
	var it := ContentDatabase.get_item(item_id)
	var tags: Array = it.get("tags", [])
	for t in arch.get("likes_tags", []):
		if String(t) in tags:
			return true
	if String(it.get("category", "")) in arch.get("likes_categories", []):
		return true
	# named characters prefer goods from their own world
	if String(cust.get("world", "")) != "" and String(it.get("world", "")) == String(cust.get("world", "")):
		return true
	return false


## Pick which displayed item this customer wants (weighted by preference and
## window placement). Returns "" when nothing interests them.
static func pick_interest(cust: Dictionary) -> String:
	var best := ""
	var best_score := 0.0
	for slot in range(InventoryManager.display.size()):
		var id := String(InventoryManager.display[slot])
		if id == "":
			continue
		var it := ContentDatabase.get_item(id)
		if it.get("sellable", true) == false:
			continue
		var price := MarketManager.market_value(id)
		if price > int(cust.get("budget", 0)) * 1.6:
			continue
		var score := rng.randf_range(0.4, 1.0)
		if likes_item(cust, id):
			score += 0.8
		# placement bonus now comes from the furniture the item sits on
		# (classic window bonus + per-furniture attention modifier)
		score += ShopFurnitureManager.slot_attention_bonus(slot)
		# affordable sweet spot
		if price < int(cust.get("budget", 0)) * 0.9:
			score += 0.2
		if score > best_score:
			best_score = score
			best = id
	return best


## Chance the customer places an order instead of (or after) buying.
static func maybe_make_order(cust: Dictionary) -> Dictionary:
	var cfg: Dictionary = ContentDatabase.bal("orders", {})
	if rng.randf() > float(cfg.get("chance_per_customer", 0.22)):
		return {}
	var arch: Dictionary = ContentDatabase.get_archetype(String(cust.get("archetype", "")))
	var kind := "category"
	var target := ""
	var roll := rng.randf()
	if roll < 0.35 and not arch.get("likes_tags", []).is_empty():
		kind = "tag"
		var tags: Array = arch.get("likes_tags", [])
		target = String(tags[rng.randi() % tags.size()])
	elif roll < 0.6 and String(cust.get("world", "")) != "":
		kind = "world"
		target = String(cust.get("world", ""))
	elif roll < 0.85:
		kind = "category"
		var cats: Array = arch.get("likes_categories", [])
		target = String(cats[rng.randi() % cats.size()]) if not cats.is_empty() else "consumable"
	else:
		kind = "item"
		var goods := MarketManager.wholesale_catalog()
		if goods.is_empty():
			return {}
		target = goods[rng.randi() % goods.size()]
	if target == "":
		return {}
	var qty := rng.randi_range(1, 3)
	var reward_each := _order_reward(kind, target)
	return InventoryManager.add_order(String(cust.get("id", "")), kind, target, qty, reward_each)


static func _order_reward(kind: String, target: String) -> int:
	var cfg: Dictionary = ContentDatabase.bal("orders", {})
	var markup := float(cfg.get("reward_markup", 1.5))
	if kind == "item":
		return int(round(MarketManager.market_value(target) * markup))
	# estimate from a mid-priced matching item
	var prices: Array[int] = []
	for id: String in ContentDatabase.items:
		var it: Dictionary = ContentDatabase.items[id]
		if it.get("sellable", true) == false:
			continue
		var hit := false
		match kind:
			"category": hit = String(it.get("category", "")) == target
			"tag": hit = target in it.get("tags", [])
			"world": hit = String(it.get("world", "")) == target
		if hit:
			prices.append(int(it.get("price", 0)))
	if prices.is_empty():
		return 100
	prices.sort()
	return int(round(prices[prices.size() / 2] * markup))


## When a hero buys equipment from the shop, they equip it if it beats their
## current gear. Visible in the guild profile and future dungeon stats.
static func try_hero_autoequip(hero_id: String, item_id: String) -> bool:
	var it := ContentDatabase.get_item(item_id)
	var cat := String(it.get("category", ""))
	var slot := ""
	if cat == "weapon":
		var hero := ContentDatabase.get_hero(hero_id)
		if String(it.get("weapon_type", "")) != String(hero.get("weapon_type", "")):
			return false
		slot = "weapon"
	elif cat == "armor":
		slot = "armor"
	elif cat == "accessory":
		slot = String(it.get("slot", "accessory"))
	else:
		return false
	var eq: Dictionary = InventoryManager.hero_equipment.get(hero_id, {})
	var current := String(eq.get(slot, ""))
	if _gear_score(item_id) > _gear_score(current):
		eq[slot] = item_id
		InventoryManager.hero_equipment[hero_id] = eq
		InventoryManager.equipment_changed.emit(hero_id)
		return true
	return false


static func _gear_score(item_id: String) -> int:
	if item_id == "":
		return -1
	var stats: Dictionary = ContentDatabase.get_item(item_id).get("stats", {})
	return int(stats.get("atk", 0)) * 2 + int(stats.get("def", 0)) * 2 + int(stats.get("spd", 0)) + int(ContentDatabase.item_price(item_id)) / 200
