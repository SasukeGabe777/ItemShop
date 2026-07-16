@tool
class_name CCSValidator
extends RefCounted
## Content validation for the studio's Validation tab / Dashboard summary.
## Every check is read-only. Results are rows of
## {severity, type, id, message, path, category} where severity is ERROR,
## WARNING, or INFO, path is the expected asset/data path when one is
## relevant, and category is "structure", "asset", "reference", or "project"
## (lets the Dashboard count "missing assets" vs "broken references" without
## parsing message text).

const UI_THEME_PATH := "res://assets/shared/ui/game_theme.tres"
const PROJECT_ICON_PATH := "res://assets/shared/ui/icon.png"
const ASSET_CREDITS_PATH := "res://credits/ASSET_CREDITS.csv"
const MUSIC_CREDITS_PATH := "res://credits/MUSIC_CREDITS.csv"

## Item categories the game's systems understand (docs/EXPANSION.md) plus the
## factory's "misc" default for not-yet-categorized items.
const KNOWN_ITEM_CATEGORIES := ["weapon", "armor", "accessory", "consumable", "food", "material", "treasure", "key", "misc"]

## Reusable enemy AI behaviors implemented by scripts/entities/enemy.gd.
const KNOWN_BEHAVIORS := [
	"chaser", "tank", "lunger", "shooter", "skitter_shooter", "bomber",
	"shy_ghost", "swooper", "creeper", "ambusher", "splitter", "teleporter", "shell",
]

## Movement animations CharacterVisual.face() drives. _side may be replaced
## by an explicit _left/_right pair.
const MOVEMENT_ANIMS := ["idle_down", "idle_up", "walk_down", "walk_up"]

const LOCATION_TYPES := ["shop", "town", "dungeon_room", "story_scene"]
const MARKER_TYPES := [
	"player_spawn", "customer_spawn", "customer_exit", "shop_counter_area",
	"item_stand_slot", "door_exit", "dungeon_enemy_spawn", "dungeon_chest_spawn",
]


static func run(scan: CCSContentScan) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []

	for path in scan.missing_data_files:
		rows.append(_row("ERROR", "structure", "data_file", path.get_file(), "data file is missing", path))
	for path in scan.invalid_json_files:
		rows.append(_row("ERROR", "structure", "data_file", path.get_file(), "data file is not valid JSON", path))

	_check_duplicates(scan.items_raw, "item", rows)
	_check_duplicates(scan.enemies_raw, "enemy", rows)
	_check_duplicates(scan.bosses_raw, "boss", rows)
	_check_duplicates(scan.heroes_raw, "hero", rows)
	_check_duplicates(scan.npcs_raw, "npc", rows)
	_check_duplicates(scan.worlds_raw, "world", rows)
	_check_duplicates(scan.recipes_raw, "recipe", rows)
	_check_duplicates(scan.archetypes_raw, "customer_archetype", rows)
	_check_duplicates(scan.named_customers_raw, "named_customer", rows)
	_check_duplicates(scan.rooms_raw, "room_template", rows)
	_check_duplicates(scan.market_events_raw, "market_event", rows)
	_check_duplicates(scan.story_scenes_raw, "story_scene", rows)
	_check_duplicates(scan.furniture_raw, "furniture", rows)
	_check_duplicates(scan.locations_raw, "location", rows)

	_check_item_required_fields(scan, rows)
	_check_entity_visuals(scan.heroes_raw, "hero", scan, rows)
	_check_entity_visuals(scan.npcs_raw, "npc", scan, rows)
	_check_entity_visuals(scan.enemies_raw, "enemy", scan, rows)
	_check_entity_visuals(scan.bosses_raw, "boss", scan, rows)
	_check_item_icons(scan, rows)
	_check_recipe_references(scan, rows)
	_check_loot_references(scan.enemies_raw, "enemy", scan, rows)
	_check_loot_references(scan.bosses_raw, "boss", scan, rows)
	_check_referenced_worlds(scan, rows)
	_check_music_files(scan, rows)
	_check_project_files(rows)

	_check_item_categories(scan, rows)
	_check_entity_animations(scan.heroes_raw, "hero", rows)
	_check_enemy_animations(scan, rows)
	_check_enemy_behaviors(scan, rows)
	_check_named_customers(scan, rows)
	_check_furniture(scan, rows)
	_check_locations(scan, rows)

	return rows


static func _row(severity: String, category: String, type: String, id: String, message: String, path: String = "") -> Dictionary:
	return {"severity": severity, "category": category, "type": type, "id": id, "message": message, "path": path}


static func _check_duplicates(raw: Array, type_name: String, rows: Array[Dictionary]) -> void:
	var counts: Dictionary = {}
	for entry: Dictionary in raw:
		var id := str(entry.get("id", ""))
		if id == "":
			continue
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		if int(counts[id]) > 1:
			rows.append(_row("ERROR", "structure", type_name, str(id),
				"id appears %d times (duplicate)" % int(counts[id])))


static func _check_item_required_fields(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	var i := 0
	for it: Dictionary in scan.items_raw:
		var label := str(it.get("id", "item#%d" % i))
		for field in ["id", "name", "world", "category", "price"]:
			if not it.has(field) or str(it[field]) == "":
				rows.append(_row("ERROR", "structure", "item", label, "missing required field '%s'" % field))
		i += 1


## Priority mirrors ContentDatabase.entity_texture(): processed franchise art,
## a manifest-driven SpriteFrames sheet, then a shared placeholder image, then
## the procedurally generated fallback. Only the last case is worth flagging.
static func _check_entity_visuals(raw: Array, type_name: String, scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for entry: Dictionary in raw:
		var id := str(entry.get("id", ""))
		if id == "":
			continue
		var world := str(entry.get("world", ""))
		var processed := CCSAssetPaths.entity_processed_path(world, id)
		var manifest := "%s/manifests/%s.json" % [CCSAssetPaths.franchise_dir(world), id]
		var shared := CCSAssetPaths.shared_placeholder_path(id)
		if FileAccess.file_exists(processed) or FileAccess.file_exists(manifest) or FileAccess.file_exists(shared):
			continue
		rows.append(_row("WARNING", "asset", type_name, id,
			"no processed sprite or manifest found; falls back to a generated placeholder",
			processed))


static func _check_item_icons(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for it: Dictionary in scan.items_raw:
		var id := str(it.get("id", ""))
		if id == "":
			continue
		var world := str(it.get("world", "crossroads"))
		var path := CCSAssetPaths.item_processed_path(world, id)
		if not FileAccess.file_exists(path):
			rows.append(_row("WARNING", "asset", "item", id,
				"no processed item icon; falls back to a generated placeholder", path))


static func _check_recipe_references(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for r: Dictionary in scan.recipes_raw:
		var id := str(r.get("id", ""))
		var output := str(r.get("output", ""))
		if output != "" and not scan.items.has(output):
			rows.append(_row("ERROR", "reference", "recipe", id, "outputs unknown item '%s'" % output))
		var inputs: Dictionary = r.get("inputs", {})
		for input_id in inputs:
			if not scan.items.has(str(input_id)):
				rows.append(_row("ERROR", "reference", "recipe", id, "uses unknown item '%s'" % str(input_id)))


static func _check_loot_references(raw: Array, type_name: String, scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for entry: Dictionary in raw:
		var id := str(entry.get("id", ""))
		for drop in entry.get("loot", []):
			var item_id := str(drop[0])
			if not scan.items.has(item_id):
				rows.append(_row("ERROR", "reference", type_name, id, "loot references unknown item '%s'" % item_id))


static func _check_referenced_worlds(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	var sources: Array = [
		[scan.items_raw, "item"], [scan.heroes_raw, "hero"], [scan.npcs_raw, "npc"],
		[scan.enemies_raw, "enemy"], [scan.bosses_raw, "boss"],
		[scan.named_customers_raw, "named_customer"], [scan.locations_raw, "location"],
	]
	for pair in sources:
		var raw: Array = pair[0]
		var type_name: String = pair[1]
		for entry: Dictionary in raw:
			var world := str(entry.get("world", ""))
			if world == "" or scan.worlds.has(world):
				continue
			var key := "%s|%s" % [type_name, world]
			if seen.has(key):
				continue
			seen[key] = true
			rows.append(_row("WARNING", "reference", "world", world,
				"referenced by %s content but has no entry in worlds.json" % type_name))


static func _check_music_files(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	var tracks: Dictionary = scan.music.get("tracks", {})
	var formats: Array = scan.music.get("formats", ["ogg", "wav"])
	var default_dir := str(scan.music.get("default_dir", "res://assets/music/default/"))
	var project_override_dir := str(scan.music.get("project_override_dir", "res://assets/music/user_overrides/"))
	for track_id in tracks:
		var track_info: Dictionary = tracks[track_id] if tracks[track_id] is Dictionary else {}
		var file_base := str(track_info.get("file", track_id))
		var found := false
		for dir in [project_override_dir, default_dir]:
			for ext in formats:
				if FileAccess.file_exists("%s%s.%s" % [dir, file_base, str(ext)]):
					found = true
					break
			if found:
				break
		if not found:
			rows.append(_row("WARNING", "asset", "music", str(track_id),
				"no audio file found for this track in the default or override directories",
				"%s%s.%s" % [default_dir, file_base, str(formats[0]) if not formats.is_empty() else "ogg"]))


static func _check_item_categories(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for it: Dictionary in scan.items_raw:
		var cat := str(it.get("category", ""))
		if cat != "" and not (cat in KNOWN_ITEM_CATEGORIES):
			rows.append(_row("WARNING", "structure", "item", str(it.get("id", "")),
				"category '%s' is not one the game's systems understand (%s)" % [cat, ", ".join(KNOWN_ITEM_CATEGORIES)]))


static func _manifest_for(entry: Dictionary) -> Dictionary:
	var world := str(entry.get("world", ""))
	var id := str(entry.get("id", ""))
	var path := "%s/manifests/%s.json" % [CCSAssetPaths.franchise_dir(world), id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	return parsed if parsed is Dictionary else {}


static func _has_anim_frames(anims: Dictionary, name: String) -> bool:
	var spec: Dictionary = anims.get(name, {})
	return not ((spec.get("frames", []) as Array).is_empty() and (spec.get("rects", []) as Array).is_empty())


## Entities that DO have an animation manifest should cover the movement set
## CharacterVisual drives; sideways movement needs _side or a _left/_right pair.
static func _check_entity_animations(raw: Array, type_name: String, rows: Array[Dictionary]) -> void:
	for entry: Dictionary in raw:
		var manifest := _manifest_for(entry)
		if manifest.is_empty():
			continue
		var id := str(entry.get("id", ""))
		var anims: Dictionary = manifest.get("animations", {})
		var missing: Array[String] = []
		for a in MOVEMENT_ANIMS:
			if not _has_anim_frames(anims, a):
				missing.append(a)
		if not (_has_anim_frames(anims, "idle_side") or (_has_anim_frames(anims, "idle_left") and _has_anim_frames(anims, "idle_right"))):
			missing.append("idle_side (or idle_left+idle_right)")
		if not (_has_anim_frames(anims, "walk_side") or (_has_anim_frames(anims, "walk_left") and _has_anim_frames(anims, "walk_right"))):
			missing.append("walk_side (or walk_left+walk_right)")
		if not missing.is_empty():
			rows.append(_row("WARNING", "asset", type_name, id,
				"manifest is missing movement animations: %s" % ", ".join(missing)))
		var sheet := str(manifest.get("sheet", ""))
		if sheet != "" and not FileAccess.file_exists(sheet):
			rows.append(_row("ERROR", "asset", type_name, id, "manifest points at a missing sheet", sheet))


static func _check_enemy_animations(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for raw in [scan.enemies_raw, scan.bosses_raw]:
		for entry: Dictionary in raw:
			var manifest := _manifest_for(entry)
			if manifest.is_empty():
				continue
			var anims: Dictionary = manifest.get("animations", {})
			var missing: Array[String] = []
			for a in ["move", "attack", "defeat"]:
				if not _has_anim_frames(anims, a) and not _has_anim_frames(anims, "walk_down"):
					missing.append(a)
			if not missing.is_empty():
				rows.append(_row("WARNING", "asset", "enemy", str(entry.get("id", "")),
					"manifest is missing combat animations: %s" % ", ".join(missing)))
			var sheet := str(manifest.get("sheet", ""))
			if sheet != "" and not FileAccess.file_exists(sheet):
				rows.append(_row("ERROR", "asset", "enemy", str(entry.get("id", "")),
					"manifest points at a missing sheet", sheet))


static func _check_enemy_behaviors(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for entry: Dictionary in scan.enemies_raw:
		var b := str(entry.get("behavior", ""))
		if b != "" and not (b in KNOWN_BEHAVIORS):
			rows.append(_row("WARNING", "structure", "enemy", str(entry.get("id", "")),
				"behavior '%s' is not a known reusable AI type" % b))
	for entry: Dictionary in scan.bosses_raw:
		var b := str(entry.get("behavior", ""))
		if b != "" and not (b in KNOWN_BEHAVIORS) and not b.begins_with("boss"):
			rows.append(_row("WARNING", "structure", "boss", str(entry.get("id", "")),
				"behavior '%s' is not a known reusable AI type" % b))


static func _check_named_customers(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for entry: Dictionary in scan.named_customers_raw:
		var id := str(entry.get("id", ""))
		var arch := str(entry.get("archetype", ""))
		if arch == "":
			rows.append(_row("WARNING", "structure", "named_customer", id,
				"has no archetype — sessions will fall back to generic behavior"))
		elif not scan.archetypes.has(arch):
			rows.append(_row("ERROR", "reference", "named_customer", id,
				"references unknown archetype '%s'" % arch))
		# sprite resolution mirrors ShopCustomer.setup(): hero_ref art wins
		var sprite_id := str(entry.get("hero_ref", ""))
		if sprite_id == "":
			sprite_id = id
		var world := str(entry.get("world", ""))
		var manifest := "%s/manifests/%s.json" % [CCSAssetPaths.franchise_dir(world), sprite_id]
		var processed := CCSAssetPaths.entity_processed_path(world, sprite_id)
		var shared := CCSAssetPaths.shared_placeholder_path(sprite_id)
		if world != "" and not FileAccess.file_exists(manifest) and not FileAccess.file_exists(processed) and not FileAccess.file_exists(shared):
			rows.append(_row("WARNING", "asset", "named_customer", id,
				"no sprite/manifest for '%s'; falls back to a generated placeholder" % sprite_id, processed))


static func _check_furniture(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for entry: Dictionary in scan.furniture_raw:
		var id := str(entry.get("id", ""))
		var sprite := str(entry.get("sprite", ""))
		if sprite != "" and not FileAccess.file_exists(sprite):
			rows.append(_row("ERROR", "asset", "furniture", id, "custom sprite file is missing", sprite))
		var slots: Array = entry.get("display_slots", [])
		if slots.is_empty():
			rows.append(_row("WARNING", "structure", "furniture", id,
				"has zero display slots — customers can never inspect it"))
		for cat in entry.get("allowed_categories", []):
			if not (str(cat) in KNOWN_ITEM_CATEGORIES):
				rows.append(_row("WARNING", "structure", "furniture", id,
					"allowed category '%s' is not a known item category" % str(cat)))
		if not entry.has("size"):
			rows.append(_row("WARNING", "structure", "furniture", id,
				"has no size — placement validation will use a default footprint"))


static func _check_locations(scan: CCSContentScan, rows: Array[Dictionary]) -> void:
	for entry: Dictionary in scan.locations_raw:
		var id := str(entry.get("id", ""))
		var ltype := str(entry.get("location_type", ""))
		if not (ltype in LOCATION_TYPES):
			rows.append(_row("ERROR", "structure", "location", id, "invalid location_type '%s'" % ltype))
		var tileset := str(entry.get("tileset", ""))
		var tile_count := -1
		if tileset == "":
			rows.append(_row("WARNING", "asset", "location", id, "has no tileset — tiles cannot render"))
		elif not FileAccess.file_exists(tileset):
			rows.append(_row("ERROR", "asset", "location", id, "tileset file is missing", tileset))
		else:
			var parsed: Variant = JSON.parse_string(FileAccess.open(tileset, FileAccess.READ).get_as_text())
			if parsed is Dictionary:
				var meta: Dictionary = parsed
				tile_count = int(meta.get("columns", 0)) * int(meta.get("rows", 0))
				if not FileAccess.file_exists(str(meta.get("sheet", ""))):
					rows.append(_row("ERROR", "asset", "location", id, "tileset sheet PNG is missing", str(meta.get("sheet", ""))))
			else:
				rows.append(_row("ERROR", "structure", "location", id, "tileset JSON is invalid", tileset))
		var layer_defs: Dictionary = entry.get("layers", {})
		if tile_count >= 0:
			for layer_name in layer_defs:
				for t in layer_defs[layer_name]:
					if int(t) >= tile_count:
						rows.append(_row("ERROR", "reference", "location", id,
							"layer '%s' references tile %d but the tileset only has %d tiles" % [str(layer_name), int(t), tile_count]))
						break
		var counts := {}
		for m: Dictionary in entry.get("markers", []):
			var mt := str(m.get("type", ""))
			counts[mt] = int(counts.get(mt, 0)) + 1
			if not (mt in MARKER_TYPES):
				rows.append(_row("WARNING", "structure", "location", id, "unknown marker type '%s'" % mt))
			if mt == "door_exit":
				var target := str(m.get("target", ""))
				if target == "":
					rows.append(_row("WARNING", "reference", "location", id,
						"door_exit at (%d,%d) has no target location (unresolved exit)" % [int(m.get("x", 0)), int(m.get("y", 0))]))
				elif not scan.locations.has(target):
					rows.append(_row("ERROR", "reference", "location", id,
						"door_exit targets unknown location '%s'" % target))
		if int(counts.get("player_spawn", 0)) == 0 and ltype in ["shop", "town", "dungeon_room"]:
			rows.append(_row("ERROR", "structure", "location", id, "has no player_spawn marker"))
		if ltype == "shop":
			if int(counts.get("customer_spawn", 0)) == 0:
				rows.append(_row("ERROR", "structure", "location", id, "shop has no customer_spawn marker"))
			if int(counts.get("customer_exit", 0)) == 0:
				rows.append(_row("ERROR", "structure", "location", id, "shop has no customer_exit marker"))
			if int(counts.get("item_stand_slot", 0)) == 0:
				rows.append(_row("WARNING", "structure", "location", id, "shop has no item_stand_slot markers"))


static func _check_project_files(rows: Array[Dictionary]) -> void:
	if not FileAccess.file_exists(UI_THEME_PATH):
		rows.append(_row("ERROR", "project", "ui", "game_theme", "UI theme resource is missing", UI_THEME_PATH))
	if not FileAccess.file_exists(PROJECT_ICON_PATH):
		rows.append(_row("ERROR", "project", "ui", "icon", "project icon is missing", PROJECT_ICON_PATH))
	if not FileAccess.file_exists(ASSET_CREDITS_PATH):
		rows.append(_row("ERROR", "project", "credits", "ASSET_CREDITS", "asset credits file is missing", ASSET_CREDITS_PATH))
	if not FileAccess.file_exists(MUSIC_CREDITS_PATH):
		rows.append(_row("ERROR", "project", "credits", "MUSIC_CREDITS", "music credits file is missing", MUSIC_CREDITS_PATH))
