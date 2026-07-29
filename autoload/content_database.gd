extends Node
## ContentDatabase: loads every data pack from res://data. All game content is
## data-driven; no franchise content is hardcoded in systems.

signal missing_asset_fallback(kind: String, content_id: String, expected_path: String)

var items: Dictionary = {}
var enemies: Dictionary = {}
var bosses: Dictionary = {}
var heroes: Dictionary = {}
var npcs: Dictionary = {}
var worlds: Dictionary = {}
var world_order: Array[String] = []
var recipes: Dictionary = {}
var archetypes: Dictionary = {}
var named_customers: Dictionary = {}
var market_events: Dictionary = {}
var booms: Dictionary = {}
var boom_daily_roll_chance := 0.0
var boom_max_customers_per_session := 28
var expedition_booms: Dictionary = {}
var expedition_boom_daily_roll_chance := 0.0
var story_scenes: Dictionary = {}
var rooms: Dictionary = {}
var room_grid: Vector2i = Vector2i(20, 12)
var room_cell: int = 32
var balance: Dictionary = {}
var music: Dictionary = {}
var furniture: Dictionary = {}
var locations: Dictionary = {}
var customer_visual_pool: Array = []
var live_items: Array[String] = []    # sellable items with real icon art
var _live_sub_cache: Dictionary = {}

var load_errors: Array[String] = []

const ENCYCLOPEDIA_CATEGORIES := ["Items", "Enemies", "Bosses", "Heroes", "NPCs", "Customers"]


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	load_errors.clear()
	var items_doc: Dictionary = _load_json("res://data/items.json")
	for it: Dictionary in items_doc.get("items", []):
		items[it["id"]] = it
	var en_doc: Dictionary = _load_json("res://data/enemies.json")
	for e: Dictionary in en_doc.get("enemies", []):
		enemies[e["id"]] = e
	for b: Dictionary in en_doc.get("bosses", []):
		bosses[b["id"]] = b
	var h_doc: Dictionary = _load_json("res://data/heroes.json")
	for h: Dictionary in h_doc.get("heroes", []):
		heroes[h["id"]] = h
	for n: Dictionary in h_doc.get("npcs", []):
		npcs[n["id"]] = n
	var w_doc: Dictionary = _load_json("res://data/worlds.json")
	for w: Dictionary in w_doc.get("worlds", []):
		worlds[w["id"]] = w
		world_order.append(w["id"])
	var r_doc: Dictionary = _load_json("res://data/recipes.json")
	for r: Dictionary in r_doc.get("recipes", []):
		recipes[r["id"]] = r
	var c_doc: Dictionary = _load_json("res://data/customers.json")
	for a: Dictionary in c_doc.get("archetypes", []):
		archetypes[a["id"]] = a
	for nc: Dictionary in c_doc.get("named", []):
		named_customers[nc["id"]] = nc
	var m_doc: Dictionary = _load_json("res://data/market_events.json")
	for ev: Dictionary in m_doc.get("events", []):
		market_events[ev["id"]] = ev
	var boom_doc: Dictionary = _load_json("res://data/booms.json")
	for boom: Dictionary in boom_doc.get("booms", []):
		booms[boom["id"]] = boom
	boom_daily_roll_chance = float(boom_doc.get("daily_roll_chance", 0.0))
	boom_max_customers_per_session = int(boom_doc.get("max_customers_per_session", 28))
	for boom: Dictionary in boom_doc.get("expedition_booms", []):
		expedition_booms[boom["id"]] = boom
	expedition_boom_daily_roll_chance = float(
		boom_doc.get("expedition_daily_roll_chance", 0.0))
	var s_doc: Dictionary = _load_json("res://data/story_scenes.json")
	for sc: Dictionary in s_doc.get("scenes", []):
		story_scenes[sc["id"]] = sc
	var rm_doc: Dictionary = _load_json("res://data/rooms.json")
	for t: Dictionary in rm_doc.get("templates", []):
		rooms[t["id"]] = t
	var grid: Array = rm_doc.get("grid", [20, 12])
	room_grid = Vector2i(int(grid[0]), int(grid[1]))
	room_cell = int(rm_doc.get("cell_size", 32))
	var f_doc: Dictionary = _load_json("res://data/shop_furniture.json")
	for fu: Dictionary in f_doc.get("furniture", []):
		furniture[fu["id"]] = fu
	var l_doc: Dictionary = _load_json("res://data/locations.json")
	for loc: Dictionary in l_doc.get("locations", []):
		locations[loc["id"]] = loc
	balance = _load_json("res://data/balance.json")
	music = _load_json("res://data/music_manifest.json")
	customer_visual_pool = _load_json("res://data/customer_visuals.json").get("pool", [])
	_build_live_items()
	if load_errors.is_empty():
		print("[ContentDatabase] loaded: %d items, %d enemies, %d bosses, %d heroes, %d worlds, %d recipes, %d archetypes, %d named customers, %d events, %d shop booms, %d expedition booms, %d scenes, %d rooms" % [
			items.size(), enemies.size(), bosses.size(), heroes.size(), worlds.size(),
			recipes.size(), archetypes.size(), named_customers.size(), market_events.size(),
			booms.size(), expedition_booms.size(), story_scenes.size(), rooms.size()])
	else:
		push_error("[ContentDatabase] load errors: %s" % ", ".join(load_errors))


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("missing %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		load_errors.append("bad json %s" % path)
		return {}
	return parsed


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))


func item_price(id: String) -> int:
	return int(get_item(id).get("price", 0))


## Sprite storage is independent from gameplay origin. A few corrected legacy
## items still use art under assets/franchises/crossover while correctly
## participating in their source world's Booms, progression, and customers.
func item_asset_world(id: String) -> String:
	var item := get_item(id)
	return String(item.get("asset_world", item.get("world", "crossroads")))


func item_world_ids(id: String) -> Array[String]:
	var item := get_item(id)
	var out: Array[String] = []
	var primary := String(item.get("world", ""))
	if primary != "" and primary != "crossover":
		out.append(primary)
	for raw: Variant in item.get("world_affinities", []):
		var world_id := String(raw)
		if world_id != "" and world_id not in out:
			out.append(world_id)
	return out


func item_matches_world(id: String, world_id: String) -> bool:
	return world_id != "" and world_id in item_world_ids(id)


func item_sources(id: String) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in get_item(id).get("acquisition", ["market"]):
		var source := String(raw)
		if source != "" and source not in out:
			out.append(source)
	return out


func item_unlock_chapter(id: String) -> int:
	var item := get_item(id)
	var explicit := int(item.get("unlock_chapter", 1))
	var world_chapters: Array[int] = []
	for world_id: String in item_world_ids(id):
		var world := get_world(world_id)
		if not world.is_empty():
			world_chapters.append(int(world.get("chapter", 1)))
	if world_chapters.is_empty():
		return explicit
	var first_world: int = world_chapters.min()
	return maxi(explicit, first_world)


func is_item_unlocked(id: String, chapter: int = TimeManager.chapter) -> bool:
	return id in live_items and item_unlock_chapter(id) <= chapter \
		and not item_sources(id).is_empty()


func unlocked_live_items(chapter: int = TimeManager.chapter) -> Array[String]:
	var out: Array[String] = []
	for id: String in live_items:
		if is_item_unlocked(id, chapter):
			out.append(id)
	out.sort()
	return out


func item_has_source(id: String, source: String) -> bool:
	return source in item_sources(id)


func live_items_for_source(source: String, world_id: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in live_items:
		if not item_has_source(id, source):
			continue
		if world_id != "" and not item_matches_world(id, world_id):
			continue
		out.append(id)
	out.sort()
	return out


func expedition_chest_pool(world_id: String) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in get_world(world_id).get("market_goods", []):
		var item_id := String(raw)
		if item_id in live_items and item_id not in out:
			out.append(item_id)
	for item_id: String in live_items_for_source("expedition_chest", world_id):
		if item_id not in out:
			out.append(item_id)
	out.sort()
	return out


## Effect keys CombatHero._use_consumable actually acts on. Items whose only
## effects are outside this list (poke balls' `capture`, escape ropes'
## `escape`, rare candy's `level_up`) would burn an item slot and do nothing,
## so they are kept out of the expedition picker — they remain sellable stock.
const FIELD_EFFECTS := ["heal", "meter", "buff_atk", "buff_def", "invincible",
	"aoe_damage", "ranged_damage", "stun", "self_damage", "revive"]


## True when taking this item into a dungeon has any effect at all.
func is_field_usable(id: String) -> bool:
	var fx: Dictionary = get_item(id).get("effect", {})
	for k: String in fx:
		if k in FIELD_EFFECTS:
			return true
	return false


## Short human-readable summary of what a consumable does when used in a
## dungeon ("heals 100", "+30 meter"). Shown in the expedition picker and the
## run HUD so a player can tell a 40 HP potion from a 200 HP one before
## spending a slot on it. Mirrors CombatHero._use_consumable — keep in sync.
func item_effect_summary(id: String) -> String:
	var fx: Dictionary = get_item(id).get("effect", {})
	if fx.is_empty():
		return ""
	var parts: Array[String] = []
	if fx.has("heal"):
		parts.append("heals %d" % int(fx["heal"]))
	if fx.has("revive"):
		parts.append("revives")
	if fx.has("meter"):
		parts.append("+%d meter" % int(fx["meter"]))
	if fx.has("buff_atk"):
		parts.append("+%d ATK" % int(fx["buff_atk"]))
	if fx.has("buff_def"):
		parts.append("+%d DEF" % int(fx["buff_def"]))
	if fx.has("invincible"):
		parts.append("%.1fs invincible" % float(fx["invincible"]))
	if fx.has("aoe_damage"):
		parts.append("%d blast" % int(fx["aoe_damage"]))
	if fx.has("ranged_damage"):
		parts.append("%d ranged" % int(fx["ranged_damage"]))
	if fx.has("stun"):
		parts.append("stuns %.1fs" % float(fx["stun"]))
	if fx.has("self_damage"):
		parts.append("HURTS you %d" % int(fx["self_damage"]))
	if parts.is_empty():
		return "no combat use"
	return ", ".join(parts)


func get_enemy(id: String) -> Dictionary:
	if enemies.has(id):
		return enemies[id]
	return bosses.get(id, {})


func get_hero(id: String) -> Dictionary:
	return heroes.get(id, {})


func get_world(id: String) -> Dictionary:
	return worlds.get(id, {})


func world_for_chapter(chapter: int) -> Dictionary:
	for id: String in world_order:
		if int(worlds[id].get("chapter", 0)) == chapter:
			return worlds[id]
	return {}


func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


func recipes_for_chapter(chapter: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in recipes:
		var r: Dictionary = recipes[id]
		if int(r.get("unlock_chapter", 1)) > chapter:
			continue
		# only recipes whose output and every ingredient are live items —
		# no filler art in the workshop
		if not is_live_item(String(r.get("output", ""))):
			continue
		var all_live := true
		for ing: String in r.get("inputs", {}):
			if not is_live_item(ing):
				all_live = false
				break
		if all_live:
			out.append(r)
	return out


func get_archetype(id: String) -> Dictionary:
	return archetypes.get(id, {})


func get_named_customer(id: String) -> Dictionary:
	return named_customers.get(id, {})


## Complete, data-driven encyclopedia registry. Discovery and campaign access
## are deliberately handled by the UI so adding content never requires
## editing a second hardcoded list here or in the handbook.
func encyclopedia_categories() -> Array[String]:
	var out: Array[String] = []
	out.assign(ENCYCLOPEDIA_CATEGORIES)
	return out


func encyclopedia_catalog(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match category:
		"Items":
			for id: String in items:
				var data: Dictionary = items[id]
				out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"Enemies":
			for id: String in enemies:
				var data: Dictionary = enemies[id]
				out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"Bosses":
			for id: String in bosses:
				var data: Dictionary = bosses[id]
				out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"Heroes":
			for id: String in heroes:
				var data: Dictionary = heroes[id]
				out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"NPCs":
			for id: String in npcs:
				var data: Dictionary = npcs[id]
				out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"Customers":
			out = _encyclopedia_customers()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).nocasecmp_to(String(b["name"])) < 0)
	return out


func _encyclopedia_customers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_visual_identity: Dictionary = {}
	for raw: Variant in customer_visual_pool:
		var data: Dictionary = raw
		var identity := _customer_visual_identity(data)
		if by_visual_identity.has(identity):
			continue
		var slug := String(data.get("slug", "customer"))
		var entry := {
			"id": identity,
			"name": String(data.get("name", slug.capitalize())),
			"data": data,
			"relationship_id": "walkin_%s" % slug,
			"discovery_ids": ["walkin_%s" % slug],
		}
		by_visual_identity[identity] = entry
		out.append(entry)

	# Authored customers and the large visual pool are separate data packs.
	# Merge matches into one entry, then retain any authored customer that has
	# no pool art so characters never silently disappear from the encyclopedia.
	for named_id: String in named_customers:
		var named: Dictionary = named_customers[named_id]
		var visual := customer_pool_entry_by_name(String(named.get("name", "")))
		if not visual.is_empty():
			var identity := _customer_visual_identity(visual)
			if by_visual_identity.has(identity):
				var matched: Dictionary = by_visual_identity[identity]
				matched["id"] = named_id
				matched["name"] = String(named.get("name", matched["name"]))
				matched["relationship_id"] = named_id
				matched["authored_data"] = named
				var discovery_ids: Array = matched.get("discovery_ids", [])
				if named_id not in discovery_ids:
					discovery_ids.append(named_id)
				continue
		var synthetic: Dictionary = named.duplicate(true)
		synthetic["slug"] = named_id
		out.append({
			"id": named_id,
			"name": String(named.get("name", named_id)),
			"data": synthetic,
			"authored_data": named,
			"relationship_id": named_id,
			"discovery_ids": [named_id],
			"visual_entity": _encyclopedia_entity_for_customer(named),
		})
	return out


func _customer_visual_identity(data: Dictionary) -> String:
	return "%s:%s" % [String(data.get("world", "")), String(data.get("slug", ""))]


func _encyclopedia_entity_for_customer(customer: Dictionary) -> Dictionary:
	var wanted := _catalog_name_key(String(customer.get("name", "")))
	for kind in ["Heroes", "NPCs"]:
		var table: Dictionary = heroes if kind == "Heroes" else npcs
		for id: String in table:
			var data: Dictionary = table[id]
			if _catalog_name_key(String(data.get("name", ""))) == wanted:
				return {"category": kind, "id": id, "data": data}
	return {}


func _catalog_name_key(value: String) -> String:
	return value.to_lower().replace(" ", "_").replace(".", "")


func get_scene_data(id: String) -> Dictionary:
	return story_scenes.get(id, {})


func get_furniture(id: String) -> Dictionary:
	return furniture.get(id, {})


## Stable pool entry ({slug, name, world, static, manifest}) for a customer
## without a dedicated spritesheet: the same key always maps to the same
## pool character (salt varies walk-in duplicates).
func customer_pool_entry(key: String, salt: int = 0) -> Dictionary:
	if customer_visual_pool.is_empty():
		return {}
	return customer_visual_pool[absi((key + str(salt)).hash()) % customer_visual_pool.size()]


## Pool entry whose character name matches a named customer (e.g. the
## "Kakashi" customer gets the kakashi pool sprite). Empty when no match.
func customer_pool_entry_by_name(cname: String) -> Dictionary:
	if cname == "":
		return {}
	var want := cname.to_lower().replace(" ", "_").replace(".", "")
	for e: Dictionary in customer_visual_pool:
		if String(e.get("slug", "")) == want or String(e.get("name", "")).to_lower() == cname.to_lower():
			return e
	# partial: "Donald" matches donald_duck
	for e: Dictionary in customer_visual_pool:
		var slug := String(e.get("slug", ""))
		if slug != "" and (slug.begins_with(want + "_") or want.begins_with(slug + "_")):
			return e
	return {}


func customer_pool_texture(key: String, salt: int = 0) -> Texture2D:
	var path := String(customer_pool_entry(key, salt).get("static", ""))
	return load(path) if path != "" and ResourceLoader.exists(path) else null


func get_location(id: String) -> Dictionary:
	return locations.get(id, {})


func room_templates_by_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var room_ids: Array[String] = []
	room_ids.assign(rooms.keys())
	room_ids.sort()
	for id: String in room_ids:
		if String(rooms[id].get("kind", "")) == kind:
			out.append(rooms[id])
	return out


func bal(key: String, def: Variant = null) -> Variant:
	return balance.get(key, def)


## Resolve a display texture for an entity (hero/npc/enemy/customer).
## Priority: processed franchise art -> generated placeholder.
func entity_texture(entity_id: String, world_id: String, color_hex: String, size: int = 16) -> Texture2D:
	var candidates: Array[String] = [
		"res://assets/franchises/%s/processed/%s.png" % [world_id, entity_id],
		"res://assets/shared/placeholders/%s.png" % entity_id,
	]
	for p: String in candidates:
		if ResourceLoader.exists(p):
			return load(p)
	missing_asset_fallback.emit("entity", entity_id, candidates[0])
	return PlaceholderFactory.character_texture(entity_id, Color(color_hex), size)


## The live catalog: only items with uploaded icon art circulate in the
## economy (market, loot, orders, crafting). Quest items (sellable=false)
## live outside the catalog and are never filtered or substituted.
func _build_live_items() -> void:
	live_items.clear()
	_live_sub_cache.clear()
	for id: String in items:
		var it: Dictionary = items[id]
		if it.get("sellable", true) == false:
			continue
		if ResourceLoader.exists("res://assets/franchises/%s/processed/items/%s.png" % [
				item_asset_world(id), id]):
			live_items.append(id)
	live_items.sort()


func is_live_item(id: String) -> bool:
	return id in live_items


## Maps a spriteless catalog item to the closest-priced live item (same
## world preferred) so loot tables and starting stock keep their value
## without putting filler art in front of the player.
func live_substitute(id: String) -> String:
	if id in live_items or not items.has(id):
		return id
	var it := get_item(id)
	if it.get("sellable", true) == false:
		return id
	if _live_sub_cache.has(id):
		return String(_live_sub_cache[id])
	var price := int(it.get("price", 100))
	var world := String(it.get("world", ""))
	var best := ""
	var best_cost := 1 << 30
	for cand: String in live_items:
		var cit := get_item(cand)
		var cost := absi(int(cit.get("price", 100)) - price)
		if String(cit.get("world", "")) != world:
			cost += 60  # prefer same-world stand-ins when prices are close
		if cost < best_cost:
			best_cost = cost
			best = cand
	_live_sub_cache[id] = best if best != "" else id
	return String(_live_sub_cache[id])


func item_texture(item_id: String) -> Texture2D:
	var it := get_item(item_id)
	var world_id := item_asset_world(item_id)
	var p := "res://assets/franchises/%s/processed/items/%s.png" % [world_id, item_id]
	if ResourceLoader.exists(p):
		return load(p)
	missing_asset_fallback.emit("item", item_id, p)
	return PlaceholderFactory.item_texture(item_id, String(it.get("category", "material")))
