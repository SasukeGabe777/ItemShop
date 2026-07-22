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
	if BoomManager.is_active():
		n = clampi(int(round(n * BoomManager.traffic_multiplier())), 2, ContentDatabase.boom_max_customers_per_session)
	var out: Array[Dictionary] = []
	var used_identities: Dictionary = {}
	for i in range(n):
		if rng.randf() < BoomManager.named_chance():
			var named := _pick_named(used_identities)
			if not named.is_empty():
				out.append(named)
				used_identities[_identity_key(named)] = true
				continue
		var walk_in := _make_walk_in(used_identities)
		out.append(walk_in)
		used_identities[_identity_key(walk_in)] = true
	# the vertical-slice onboarding customer leads the day but never replaces
	# the crowd — a failed scripted sale must not starve the shop of business
	var onboarding_customer := _vertical_slice_customer()
	if not onboarding_customer.is_empty():
		var onboarding_key := _identity_key(onboarding_customer)
		for i in range(out.size() - 1, -1, -1):
			if _identity_key(out[i]) == onboarding_key:
				out.remove_at(i)
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


static func _pick_named(used_identities: Dictionary = {}) -> Dictionary:
	var pool: Array[Dictionary] = []
	var weights: Array[float] = []
	var total := 0.0
	for id: String in ContentDatabase.named_customers:
		var c: Dictionary = ContentDatabase.named_customers[id]
		var candidate := runtime_named(c)
		if used_identities.has(_identity_key(candidate)):
			continue
		if int(c.get("chapter", 1)) > TimeManager.chapter:
			continue
		var unlock := String(c.get("unlock", ""))
		if unlock == "boss_defeated":
			var world := String(c.get("world", ""))
			if not BridgeManager.has_shard(world):
				continue
		pool.append(c)
		var weight := BoomManager.customer_weight(String(c.get("archetype", "adventurer")), String(c.get("world", "")))
		weights.append(weight)
		total += weight
	if pool.is_empty():
		return {}
	var pick := rng.randf_range(0.0, total)
	for i in range(pool.size()):
		pick -= weights[i]
		if pick <= 0.0:
			return runtime_named(pool[i])
	return runtime_named(pool[-1])


## Public adapter used by development tooling to summon a specific named
## customer without duplicating the live budget/archetype conversion.
static func runtime_named(c: Dictionary) -> Dictionary:
	var arch: Dictionary = ContentDatabase.get_archetype(String(c.get("archetype", "adventurer")))
	var brange: Array = arch.get("budget", [100, 500])
	var mult := float(c.get("budget_mult", 1.0))
	# budgets ride prosperity so late-game repair goals stay reachable
	var chapter_scale := MarketManager.prosperity() * (1.0 + float(ContentDatabase.bal("customer_budget_chapter_scale", 0.25)) * (TimeManager.chapter - 1))
	var runtime := {
		"id": String(c["id"]), "name": String(c["name"]),
		"archetype": String(c.get("archetype", "adventurer")),
		"budget": int(rng.randi_range(int(brange[0]), int(brange[1])) * mult * chapter_scale),
		"hero_ref": String(c.get("hero_ref", "")),
		"color": String(c.get("color", ContentDatabase.get_hero(String(c.get("hero_ref", ""))).get("color", "#c0c0c0"))),
		"quirk": String(c.get("quirk", "")), "line": String(c.get("line", "")),
		"named": true, "world": String(c.get("world", "")),
	}
	var entry := ContentDatabase.customer_pool_entry_by_name(String(c.get("name", "")))
	if not entry.is_empty():
		_apply_visual_identity(runtime, entry)
	elif String(runtime.get("hero_ref", "")) != "":
		runtime["visual_slug"] = "hero_%s" % String(runtime["hero_ref"])
	return BoomManager.apply_to_customer(runtime)


## How many currently boosted market-event goods this archetype likes. The day
## briefing advertises these shoppers, so walk-in generation must honor it.
static func event_match_count(arch: Dictionary) -> int:
	var count := 0
	var effects: Dictionary = MarketManager.event_effects()
	for key: String in effects:
		if float(effects[key]) <= 1.0:
			continue
		if key.begins_with("tag:") and key.trim_prefix("tag:") in arch.get("likes_tags", []):
			count += 1
		elif key.begins_with("cat:") and key.trim_prefix("cat:") in arch.get("likes_categories", []):
			count += 1
	return count


static func _make_walk_in(used_identities: Dictionary = {}) -> Dictionary:
	# The visual identity is selected first, then mapped to one stable archetype.
	# A Moogle therefore remains the same Moogle merchant every time instead of
	# appearing later as an unrelated Collector or Bargain Hunter.
	var candidates: Array[Dictionary] = []
	for raw: Variant in ContentDatabase.customer_visual_pool:
		var entry: Dictionary = raw
		if not used_identities.has(String(entry.get("slug", ""))):
			candidates.append(entry)
	if candidates.is_empty():
		for raw: Variant in ContentDatabase.customer_visual_pool:
			var entry: Dictionary = raw
			candidates.append(entry)
	if candidates.is_empty():
		return _fallback_walk_in()
	var weights: Array[int] = []
	var total := 0
	for entry: Dictionary in candidates:
		var candidate_arch := _identity_archetype(entry)
		var w := int(round((10 + 18 * event_match_count(ContentDatabase.get_archetype(candidate_arch))) \
			* BoomManager.customer_weight(candidate_arch, String(entry.get("world", "")))))
		w = maxi(1, w)
		weights.append(w)
		total += w
	var chosen := candidates[0]
	var pick := rng.randi_range(1, total)
	for i in range(candidates.size()):
		pick -= weights[i]
		if pick <= 0:
			chosen = candidates[i]
			break
	var arch_id := _identity_archetype(chosen)
	var arch: Dictionary = ContentDatabase.get_archetype(arch_id)
	var brange: Array = arch.get("budget", [100, 500])
	var chapter_scale := 1.0 + (TimeManager.chapter - 1) * 0.85
	var runtime := {
		"id": "walkin_%s" % String(chosen.get("slug", arch_id)),
		"name": String(chosen.get("name", arch.get("name", arch_id))),
		"archetype": arch_id,
		"budget": int(rng.randi_range(int(brange[0]), int(brange[1])) * chapter_scale),
		"hero_ref": "", "color": String(arch.get("color", "#c0c0c0")),
		"quirk": "", "line": "", "named": false, "world": String(chosen.get("world", "")),
	}
	_apply_visual_identity(runtime, chosen)
	return BoomManager.apply_to_customer(runtime)


static func _fallback_walk_in() -> Dictionary:
	var ids: Array = ContentDatabase.archetypes.keys()
	ids.sort()
	var arch_id := String(ids[0]) if not ids.is_empty() else "adventurer"
	var arch := ContentDatabase.get_archetype(arch_id)
	return {
		"id": "walkin_%s" % arch_id, "name": String(arch.get("name", arch_id)),
		"archetype": arch_id, "budget": 250, "hero_ref": "",
		"color": String(arch.get("color", "#c0c0c0")), "quirk": "", "line": "",
		"named": false, "world": "", "visual_slug": arch_id,
	}


static func _identity_key(cust: Dictionary) -> String:
	return String(cust.get("visual_slug", cust.get("id", "")))


static func _apply_visual_identity(runtime: Dictionary, entry: Dictionary) -> void:
	runtime["visual_slug"] = String(entry.get("slug", runtime.get("id", "")))
	runtime["visual_static"] = String(entry.get("static", ""))
	runtime["visual_manifest"] = String(entry.get("manifest", ""))


## Every pool character owns one archetype for the lifetime of the game.
## Named customers inherit their authored archetype; the rest are distributed
## deterministically across the available archetypes by their visual slug.
static func _identity_archetype(entry: Dictionary) -> String:
	var explicit := String(entry.get("archetype", ""))
	if explicit != "" and ContentDatabase.archetypes.has(explicit):
		return explicit
	var slug := String(entry.get("slug", ""))
	for id: String in ContentDatabase.named_customers:
		var named: Dictionary = ContentDatabase.named_customers[id]
		var match := ContentDatabase.customer_pool_entry_by_name(String(named.get("name", "")))
		if String(match.get("slug", "")) == slug:
			return String(named.get("archetype", "adventurer"))
	var ids: Array = ContentDatabase.archetypes.keys()
	ids.sort()
	if ids.is_empty():
		return "adventurer"
	return String(ids[absi(slug.hash()) % ids.size()])


static func likes_item(cust: Dictionary, item_id: String) -> bool:
	if BoomManager.item_match_score(item_id) > 0.0:
		return true
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


## Pick the exact display slot this customer wants to visit. Keeping the slot
## is important when the same item is stocked on two pieces of furniture: the
## customer-attention bonus belongs to the stand, not to the item globally.
## Returns {slot, item_id, score}, or {} when nothing interests them.
static func pick_interest_slot(cust: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0
	for slot in range(InventoryManager.display.size()):
		var id := String(InventoryManager.display[slot])
		if id == "":
			continue
		var it := ContentDatabase.get_item(id)
		if it.get("sellable", true) == false:
			continue
		var price := MarketManager.market_value(id) * BoomManager.purchase_quantity(cust, id)
		if price > int(cust.get("budget", 0)) * 1.6:
			continue
		var score := rng.randf_range(0.4, 1.0)
		if likes_item(cust, id):
			score += 0.8
		score += BoomManager.item_match_score(id) * 1.4
		# affordable sweet spot
		if price < int(cust.get("budget", 0)) * 0.9:
			score += 0.2
		# Attention is a literal multiplier: +0.5 furniture attention makes
		# this particular slot score 50% higher, while the classic +0.25
		# window placement makes it score 25% higher.
		score *= 1.0 + ShopFurnitureManager.slot_attention_bonus(slot)
		if score > best_score:
			best_score = score
			best = {"slot": slot, "item_id": id, "score": score}
	# A Boom shopper who finds none of the announced goods will usually ask
	# for them or leave disappointed instead of quietly buying random stock.
	if not best.is_empty() and BoomManager.is_active() and String(cust.get("boom_id", "")) == BoomManager.active_boom_id \
			and BoomManager.item_match_score(String(best["item_id"])) <= 0.0 and rng.randf() > BoomManager.off_theme_purchase_chance():
		return {}
	return best


## Compatibility adapter for negotiation and headless simulation callers that
## only need the item id. Shop movement uses pick_interest_slot() directly.
static func pick_interest(cust: Dictionary) -> String:
	var choice := pick_interest_slot(cust)
	return String(choice.get("item_id", ""))


## Chance the customer places an order instead of (or after) buying.
static func maybe_make_order(cust: Dictionary, direct_boom_request: bool = false) -> Dictionary:
	var cfg: Dictionary = ContentDatabase.bal("orders", {})
	var chance := float(cfg.get("chance_per_customer", 0.22))
	if BoomManager.is_active():
		chance = maxf(chance, BoomManager.request_frequency() * 0.35)
	if not direct_boom_request and rng.randf() > chance:
		return {}
	var arch: Dictionary = ContentDatabase.get_archetype(String(cust.get("archetype", "")))
	var kind := "category"
	var target := ""
	var boom_target := BoomManager.preferred_order_target() if direct_boom_request else {}
	if not boom_target.is_empty():
		kind = String(boom_target["kind"])
		target = String(boom_target["target"])
	else:
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
	var qty := rng.randi_range(1, maxi(3, int(cust.get("purchase_qty", 1))))
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
