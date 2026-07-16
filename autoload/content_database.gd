extends Node
## ContentDatabase: loads every data pack from res://data. All game content is
## data-driven; no franchise content is hardcoded in systems.

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
var story_scenes: Dictionary = {}
var rooms: Dictionary = {}
var room_grid: Vector2i = Vector2i(20, 12)
var room_cell: int = 32
var balance: Dictionary = {}
var music: Dictionary = {}

var load_errors: Array[String] = []


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
	var s_doc: Dictionary = _load_json("res://data/story_scenes.json")
	for sc: Dictionary in s_doc.get("scenes", []):
		story_scenes[sc["id"]] = sc
	var rm_doc: Dictionary = _load_json("res://data/rooms.json")
	for t: Dictionary in rm_doc.get("templates", []):
		rooms[t["id"]] = t
	var grid: Array = rm_doc.get("grid", [20, 12])
	room_grid = Vector2i(int(grid[0]), int(grid[1]))
	room_cell = int(rm_doc.get("cell_size", 32))
	balance = _load_json("res://data/balance.json")
	music = _load_json("res://data/music_manifest.json")
	if load_errors.is_empty():
		print("[ContentDatabase] loaded: %d items, %d enemies, %d bosses, %d heroes, %d worlds, %d recipes, %d archetypes, %d named customers, %d events, %d scenes, %d rooms" % [
			items.size(), enemies.size(), bosses.size(), heroes.size(), worlds.size(),
			recipes.size(), archetypes.size(), named_customers.size(), market_events.size(),
			story_scenes.size(), rooms.size()])
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


func get_enemy(id: String) -> Dictionary:
	if enemies.has(id):
		return enemies[id]
	return bosses.get(id, {})


func get_hero(id: String) -> Dictionary:
	return heroes.get(id, {})


func get_world(id: String) -> Dictionary:
	return worlds.get(id, {})


func world_for_chapter(chapter: int) -> Dictionary:
	for id: String in worlds:
		if int(worlds[id].get("chapter", 0)) == chapter:
			return worlds[id]
	return {}


func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


func recipes_for_chapter(chapter: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in recipes:
		if int(recipes[id].get("unlock_chapter", 1)) <= chapter:
			out.append(recipes[id])
	return out


func get_archetype(id: String) -> Dictionary:
	return archetypes.get(id, {})


func get_named_customer(id: String) -> Dictionary:
	return named_customers.get(id, {})


func get_scene_data(id: String) -> Dictionary:
	return story_scenes.get(id, {})


func room_templates_by_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in rooms:
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
	return PlaceholderFactory.character_texture(entity_id, Color(color_hex), size)


func item_texture(item_id: String) -> Texture2D:
	var it := get_item(item_id)
	var world_id := String(it.get("world", "crossroads"))
	var p := "res://assets/franchises/%s/processed/items/%s.png" % [world_id, item_id]
	if ResourceLoader.exists(p):
		return load(p)
	return PlaceholderFactory.item_texture(item_id, String(it.get("category", "material")))
