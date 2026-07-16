@tool
class_name CCSContentScan
extends RefCounted
## Editor-time mirror of autoload/content_database.gd. Autoload singletons are
## only instantiated while the game is actually running, not while the editor
## is idle, so the plugin cannot read the live ContentDatabase node — instead
## it re-parses res://data with the same rules. Keep this in sync by hand if
## content_database.gd's loading rules ever change.

const DATA_FILES := {
	"items": "res://data/items.json",
	"enemies": "res://data/enemies.json",
	"heroes": "res://data/heroes.json",
	"worlds": "res://data/worlds.json",
	"recipes": "res://data/recipes.json",
	"customers": "res://data/customers.json",
	"market_events": "res://data/market_events.json",
	"story_scenes": "res://data/story_scenes.json",
	"rooms": "res://data/rooms.json",
	"balance": "res://data/balance.json",
	"music_manifest": "res://data/music_manifest.json",
	"shop_furniture": "res://data/shop_furniture.json",
	"locations": "res://data/locations.json",
}

var items: Dictionary = {}
var items_raw: Array = []
var enemies: Dictionary = {}
var enemies_raw: Array = []
var bosses: Dictionary = {}
var bosses_raw: Array = []
var heroes: Dictionary = {}
var heroes_raw: Array = []
var npcs: Dictionary = {}
var npcs_raw: Array = []
var worlds: Dictionary = {}
var worlds_raw: Array = []
var world_order: Array[String] = []
var recipes: Dictionary = {}
var recipes_raw: Array = []
var archetypes: Dictionary = {}
var archetypes_raw: Array = []
var named_customers: Dictionary = {}
var named_customers_raw: Array = []
var market_events: Dictionary = {}
var market_events_raw: Array = []
var story_scenes: Dictionary = {}
var story_scenes_raw: Array = []
var rooms: Dictionary = {}
var rooms_raw: Array = []
var balance: Dictionary = {}
var music: Dictionary = {}
var furniture: Dictionary = {}
var furniture_raw: Array = []
var locations: Dictionary = {}
var locations_raw: Array = []

var missing_data_files: Array[String] = []
var invalid_json_files: Array[String] = []
var load_errors: Array[String] = []


func scan() -> void:
	items.clear(); items_raw.clear()
	enemies.clear(); enemies_raw.clear()
	bosses.clear(); bosses_raw.clear()
	heroes.clear(); heroes_raw.clear()
	npcs.clear(); npcs_raw.clear()
	worlds.clear(); worlds_raw.clear(); world_order.clear()
	recipes.clear(); recipes_raw.clear()
	archetypes.clear(); archetypes_raw.clear()
	named_customers.clear(); named_customers_raw.clear()
	market_events.clear(); market_events_raw.clear()
	story_scenes.clear(); story_scenes_raw.clear()
	rooms.clear(); rooms_raw.clear()
	balance.clear()
	music.clear()
	furniture.clear(); furniture_raw.clear()
	locations.clear(); locations_raw.clear()
	missing_data_files.clear()
	invalid_json_files.clear()
	load_errors.clear()

	var items_doc := _load_json("items")
	items_raw = items_doc.get("items", [])
	for it: Dictionary in items_raw:
		if it.has("id"):
			items[it["id"]] = it

	var en_doc := _load_json("enemies")
	enemies_raw = en_doc.get("enemies", [])
	for e: Dictionary in enemies_raw:
		if e.has("id"):
			enemies[e["id"]] = e
	bosses_raw = en_doc.get("bosses", [])
	for b: Dictionary in bosses_raw:
		if b.has("id"):
			bosses[b["id"]] = b

	var h_doc := _load_json("heroes")
	heroes_raw = h_doc.get("heroes", [])
	for h: Dictionary in heroes_raw:
		if h.has("id"):
			heroes[h["id"]] = h
	npcs_raw = h_doc.get("npcs", [])
	for n: Dictionary in npcs_raw:
		if n.has("id"):
			npcs[n["id"]] = n

	var w_doc := _load_json("worlds")
	worlds_raw = w_doc.get("worlds", [])
	for w: Dictionary in worlds_raw:
		if w.has("id"):
			worlds[w["id"]] = w
			world_order.append(String(w["id"]))

	var r_doc := _load_json("recipes")
	recipes_raw = r_doc.get("recipes", [])
	for r: Dictionary in recipes_raw:
		if r.has("id"):
			recipes[r["id"]] = r

	var c_doc := _load_json("customers")
	archetypes_raw = c_doc.get("archetypes", [])
	for a: Dictionary in archetypes_raw:
		if a.has("id"):
			archetypes[a["id"]] = a
	named_customers_raw = c_doc.get("named", [])
	for nc: Dictionary in named_customers_raw:
		if nc.has("id"):
			named_customers[nc["id"]] = nc

	var m_doc := _load_json("market_events")
	market_events_raw = m_doc.get("events", [])
	for ev: Dictionary in market_events_raw:
		if ev.has("id"):
			market_events[ev["id"]] = ev

	var s_doc := _load_json("story_scenes")
	story_scenes_raw = s_doc.get("scenes", [])
	for sc: Dictionary in story_scenes_raw:
		if sc.has("id"):
			story_scenes[sc["id"]] = sc

	var rm_doc := _load_json("rooms")
	rooms_raw = rm_doc.get("templates", [])
	for t: Dictionary in rooms_raw:
		if t.has("id"):
			rooms[t["id"]] = t

	var f_doc := _load_json("shop_furniture")
	furniture_raw = f_doc.get("furniture", [])
	for fu: Dictionary in furniture_raw:
		if fu.has("id"):
			furniture[fu["id"]] = fu

	var l_doc := _load_json("locations")
	locations_raw = l_doc.get("locations", [])
	for loc: Dictionary in locations_raw:
		if loc.has("id"):
			locations[loc["id"]] = loc

	balance = _load_json("balance")
	music = _load_json("music_manifest")


func customer_count() -> int:
	return archetypes.size() + named_customers.size()


func music_track_count() -> int:
	return (music.get("tracks", {}) as Dictionary).size()


func _load_json(key: String) -> Dictionary:
	var path: String = DATA_FILES[key]
	if not FileAccess.file_exists(path):
		missing_data_files.append(path)
		load_errors.append("missing %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		invalid_json_files.append(path)
		load_errors.append("bad json %s" % path)
		return {}
	return parsed
