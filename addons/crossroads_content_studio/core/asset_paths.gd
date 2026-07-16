@tool
class_name CCSAssetPaths
extends RefCounted
## Path conventions shared with autoload/content_database.gd. Kept in one
## place so the plugin never hardcodes a franchise name.

const FRANCHISES_ROOT := "res://assets/franchises"
const SHARED_ROOT := "res://assets/shared"
const UI_ROOT := "res://assets/shared/ui"
const PLACEHOLDERS_ROOT := "res://assets/shared/placeholders"
const IMPORT_QUEUE_ROOT := "res://assets/import_queue"

const DATA_ITEMS := "res://data/items.json"
const DATA_HEROES := "res://data/heroes.json"
const DATA_CUSTOMERS := "res://data/customers.json"
const DATA_ENEMIES := "res://data/enemies.json"
const DATA_FURNITURE := "res://data/shop_furniture.json"
const DATA_LOCATIONS := "res://data/locations.json"

const UI_SUBFOLDERS := [
	"backgrounds",
	"buttons",
	"panels",
	"cursors",
	"fonts",
	"icons",
]


static func entity_processed_path(world_id: String, entity_id: String) -> String:
	return "%s/%s/processed/%s.png" % [FRANCHISES_ROOT, world_id, entity_id]


static func item_processed_path(world_id: String, item_id: String) -> String:
	return "%s/%s/processed/items/%s.png" % [FRANCHISES_ROOT, world_id, item_id]


static func shared_placeholder_path(entity_id: String) -> String:
	return "%s/%s.png" % [PLACEHOLDERS_ROOT, entity_id]


static func franchise_dir(world_id: String) -> String:
	return "%s/%s" % [FRANCHISES_ROOT, world_id]


static func franchise_raw_dir(world_id: String) -> String:
	return "%s/%s/raw" % [FRANCHISES_ROOT, world_id]


static func franchise_processed_dir(world_id: String) -> String:
	return "%s/%s/processed" % [FRANCHISES_ROOT, world_id]


static func franchise_processed_items_dir(world_id: String) -> String:
	return "%s/%s/processed/items" % [FRANCHISES_ROOT, world_id]


static func franchise_manifests_dir(world_id: String) -> String:
	return "%s/%s/manifests" % [FRANCHISES_ROOT, world_id]


## Where the runtime (CharacterVisual/SpriteFramesBuilder) reads animations.
static func manifest_path(world_id: String, entity_id: String) -> String:
	return "%s/%s/manifests/%s.json" % [FRANCHISES_ROOT, world_id, entity_id]


## Where the factory stores the copied sheet a manifest points at.
static func sheet_processed_path(world_id: String, entity_id: String) -> String:
	return "%s/%s/processed/sheets/%s.png" % [FRANCHISES_ROOT, world_id, entity_id]


static func tileset_dir(world_id: String) -> String:
	return "%s/%s/processed/tilesets" % [FRANCHISES_ROOT, world_id]


static func tileset_json_path(world_id: String, tileset_id: String) -> String:
	return "%s/%s/processed/tilesets/%s.json" % [FRANCHISES_ROOT, world_id, tileset_id]


static func tileset_sheet_path(world_id: String, tileset_id: String) -> String:
	return "%s/%s/processed/tilesets/%s.png" % [FRANCHISES_ROOT, world_id, tileset_id]


## Every folder the factory works with for one world; created on demand.
static func world_folder_set(world_id: String) -> Array[String]:
	var base := franchise_dir(world_id)
	return [
		IMPORT_QUEUE_ROOT,
		"%s/raw" % base,
		"%s/processed" % base,
		"%s/processed/items" % base,
		"%s/processed/sheets" % base,
		"%s/processed/heroes" % base,
		"%s/processed/customers" % base,
		"%s/processed/enemies" % base,
		"%s/processed/tilesets" % base,
		"%s/processed/locations" % base,
		"%s/manifests" % base,
	]


## Every franchise/world id that currently has an assets/franchises/<id> folder
## or is referenced by content data, discovered at runtime (never hardcoded).
static func known_world_ids(extra: Array = []) -> Array[String]:
	var ids: Dictionary = {}
	var dir := DirAccess.open(FRANCHISES_ROOT)
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if dir.current_is_dir() and not name.begins_with("."):
				ids[name] = true
			name = dir.get_next()
		dir.list_dir_end()
	for id in extra:
		ids[String(id)] = true
	var out: Array[String] = []
	for id in ids:
		out.append(String(id))
	out.sort()
	return out
