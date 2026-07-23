class_name GuildPanel
extends CanvasLayer
## Adventurers' Guild: hero profiles, friendship, equipment loadouts.
## Direct equipping unlocks at the friendship level from balance.json.

signal closed()

## These source manifests currently point idle_down at a non-forward pose.
## Keep the correction local to Guild portraits so gameplay animation data
## (including dungeon-owned content) remains unchanged.
const GUILD_IDLE_FRAME_OVERRIDES := {
	"charmander": 3,
	"sora": 56,
}

var vb: VBoxContainer
var detail: VBoxContainer
var portrait: TextureRect
var portrait_name: Label
var _hero_portrait_cache: Dictionary = {}


func _ready() -> void:
	layer = 40
	var parts := UIKit.modal(self, "Adventurers' Guild")
	vb = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var roster_parts := UIKit.scroll_list(Vector2(130, 230))
	row.add_child(roster_parts[0])
	var roster: VBoxContainer = roster_parts[1]
	# the selected hero, drawn big between the roster and their profile
	var portrait_box := VBoxContainer.new()
	portrait_box.custom_minimum_size = Vector2(110, 230)
	portrait_box.add_theme_constant_override("separation", 4)
	portrait_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(portrait_box)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(110, 110)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_box.add_child(portrait)
	portrait_name = UIKit.label("", 10, UIKit.COL_ACCENT)
	portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_box.add_child(portrait_name)
	var detail_parts := UIKit.scroll_list(Vector2(250, 230))
	row.add_child(detail_parts[0])
	detail = detail_parts[1]
	for world_id in BridgeManager.accessible_worlds():
		var w := ContentDatabase.get_world(world_id)
		if bool(w.get("final", false)):
			continue
		var hid := String(w.get("hero", ""))
		roster.add_child(UIKit.button("%s (%s)" % [String(ContentDatabase.get_hero(hid).get("name", hid)), String(w.get("name", ""))],
			func() -> void: _show_hero(hid)))
	detail.add_child(UIKit.label("Select a hero.", 10, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Close", func() -> void:
		closed.emit()
		queue_free()))


## Canonical forward idle, cropped only to its visible pixels. The square
## portrait box then gives every hero the same longest edge without distorting
## proportions.
func _hero_texture(hero_id: String) -> Texture2D:
	if _hero_portrait_cache.has(hero_id):
		return _hero_portrait_cache[hero_id]
	var hero := ContentDatabase.get_hero(hero_id)
	var world := String(hero.get("world", "crossroads"))
	var manifest_path := "res://assets/franchises/%s/manifests/%s.json" % [world, hero_id]
	var frames := SpriteFramesBuilder.from_manifest_path(manifest_path)
	var texture: Texture2D = null
	if GUILD_IDLE_FRAME_OVERRIDES.has(hero_id):
		texture = _crop_visible(_manifest_frame(manifest_path,
			int(GUILD_IDLE_FRAME_OVERRIDES[hero_id])))
	elif frames != null and frames.has_animation("idle_down") \
			and frames.get_frame_count("idle_down") > 0:
		texture = _crop_visible(frames.get_frame_texture("idle_down", 0))
	if texture == null:
		texture = ContentDatabase.entity_texture(hero_id, world,
			String(hero.get("color", "#c0c0c0")), 24)
	_hero_portrait_cache[hero_id] = texture
	return texture


func _manifest_frame(manifest_path: String, frame_index: int) -> Texture2D:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return null
	var manifest: Dictionary = parsed
	var grid: Dictionary = manifest.get("grid", {})
	var frame_width := int(grid.get("frame_width", 0))
	var frame_height := int(grid.get("frame_height", 0))
	var columns := int(grid.get("columns", 0))
	var rows := int(grid.get("rows", 0))
	if frame_width <= 0 or frame_height <= 0 or columns <= 0 or rows <= 0 \
			or frame_index < 0 or frame_index >= columns * rows:
		return null
	var sheet := load(String(manifest.get("sheet", ""))) as Texture2D
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(
		(frame_index % columns) * frame_width,
		(frame_index / columns) * frame_height,
		frame_width,
		frame_height)
	return atlas


func _crop_visible(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	return ImageTexture.create_from_image(image.get_region(used))


func _show_hero(hero_id: String) -> void:
	for child in detail.get_children():
		child.queue_free()
	var hero := ContentDatabase.get_hero(hero_id)
	var stats := InventoryManager.hero_stats(hero_id)
	portrait.texture = _hero_texture(hero_id)
	portrait_name.text = String(hero.get("name", hero_id))
	detail.add_child(UIKit.header(String(hero.get("name", hero_id))))
	var bio := UIKit.label(String(hero.get("bio", "")), 9, UIKit.COL_DIM)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.custom_minimum_size = Vector2(230, 0)
	detail.add_child(bio)
	var line := UIKit.label("\"%s\"" % String(hero.get("guild_line", "")), 9)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(230, 0)
	detail.add_child(line)
	var lvl := RelationshipManager.friendship_level(hero_id)
	var bond_row := HBoxContainer.new()
	var bond_art := UIKit.bond_icon(maxi(1, lvl), Vector2(48, 48))
	if lvl == 0:
		bond_art.modulate = Color(1, 1, 1, 0.35)
	bond_row.add_child(bond_art)
	var bond_text := UIKit.label("Friendship: New" if lvl == 0 else "Friendship Lv.%d (%d pts)" % [lvl, RelationshipManager.points(hero_id)], 9)
	bond_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bond_row.add_child(bond_text)
	detail.add_child(bond_row)
	if not RelationshipManager.can_equip_directly(hero_id):
		detail.add_child(UIKit.label("Direct equip unlocks at Lv.%d" % int(ContentDatabase.bal("friendship", {}).get("equip_unlock_level", 3)), 8, UIKit.COL_DIM))
	var stats_row := HBoxContainer.new()
	var stats_label := UIKit.label("HP %d  ATK %d  DEF %d  SPD %d | hire" % [
		int(stats["hp"]), int(stats["atk"]), int(stats["def"]), int(stats["spd"])], 10, UIKit.COL_ACCENT)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(stats_label)
	stats_row.add_child(UIKit.gold_icon("small", Vector2(17, 14)))
	stats_row.add_child(UIKit.label("%d" % int(hero.get("hire_cost", 100)), 10, UIKit.COL_ACCENT))
	detail.add_child(stats_row)
	detail.add_child(UIKit.hsep())
	var eq: Dictionary = InventoryManager.hero_equipment.get(hero_id, {})
	for slot in ["weapon", "armor", "accessory", "charm"]:
		var current := String(eq.get(slot, ""))
		var row := HBoxContainer.new()
		var lbl := UIKit.label("%s: %s" % [slot.capitalize(), ContentDatabase.item_name(current) if current != "" else "—"])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if RelationshipManager.can_equip_directly(hero_id):
			row.add_child(UIKit.button("Change", func() -> void: _pick_equipment(hero_id, slot)))
		detail.add_child(row)


func _pick_equipment(hero_id: String, slot: String) -> void:
	var parts := UIKit.modal(self, "Equip %s — %s" % [String(ContentDatabase.get_hero(hero_id).get("name", "")), slot])
	var pick_layer: CanvasLayer = parts[0]
	var pvb: VBoxContainer = parts[1]
	var list_parts := UIKit.scroll_list(Vector2(320, 180))
	pvb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	var options: Array[String] = []
	for id in InventoryManager.sorted_ids("price"):
		var it := ContentDatabase.get_item(id)
		var cat := String(it.get("category", ""))
		var islot := String(it.get("slot", ""))
		var ok := false
		if slot == "weapon":
			ok = cat == "weapon" and String(it.get("weapon_type", "")) == String(ContentDatabase.get_hero(hero_id).get("weapon_type", ""))
		elif slot == "armor":
			ok = cat == "armor"
		else:
			ok = cat == "accessory" and (islot == slot or (islot in ["accessory", "charm"] and slot in ["accessory", "charm"]))
		if ok:
			options.append(id)
	if options.is_empty():
		list.add_child(UIKit.label("Nothing suitable in storage.", 10, UIKit.COL_DIM))
	for id in options:
		var stats: Dictionary = ContentDatabase.get_item(id).get("stats", {})
		list.add_child(UIKit.item_row(id, "(atk %+d def %+d spd %+d)" % [int(stats.get("atk", 0)), int(stats.get("def", 0)), int(stats.get("spd", 0))],
			"Equip", func() -> void:
				if InventoryManager.equip(hero_id, slot, id):
					AudioManager.play_sfx("equip_hero_item")
					pick_layer.queue_free()
					_show_hero(hero_id)
					# the pad's focus died with the pick modal — land it back
					# on the rebuilt equipment rows
					UIKit.focus_first_button(detail)))
	pvb.add_child(UIKit.button("Unequip", func() -> void:
		InventoryManager.equip(hero_id, slot, "")
		pick_layer.queue_free()
		_show_hero(hero_id)
		UIKit.focus_first_button(detail)))
	pvb.add_child(UIKit.button("Cancel", func() -> void: pick_layer.queue_free()))
