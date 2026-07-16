class_name GuildPanel
extends CanvasLayer
## Adventurers' Guild: hero profiles, friendship, equipment loadouts.
## Direct equipping unlocks at the friendship level from balance.json.

signal closed()

var vb: VBoxContainer
var detail: VBoxContainer


func _ready() -> void:
	layer = 40
	var parts := UIKit.modal(self, "Adventurers' Guild")
	vb = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var roster_parts := UIKit.scroll_list(Vector2(140, 230))
	row.add_child(roster_parts[0])
	var roster: VBoxContainer = roster_parts[1]
	var detail_parts := UIKit.scroll_list(Vector2(260, 230))
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


func _show_hero(hero_id: String) -> void:
	for child in detail.get_children():
		child.queue_free()
	var hero := ContentDatabase.get_hero(hero_id)
	var stats := InventoryManager.hero_stats(hero_id)
	detail.add_child(UIKit.header(String(hero.get("name", hero_id))))
	detail.add_child(UIKit.label(String(hero.get("bio", "")), 9, UIKit.COL_DIM))
	detail.add_child(UIKit.label("\"%s\"" % String(hero.get("guild_line", "")), 9))
	var lvl := RelationshipManager.friendship_level(hero_id)
	detail.add_child(UIKit.label("Friendship: Lv.%d (%d pts) %s" % [lvl, RelationshipManager.points(hero_id),
		"" if RelationshipManager.can_equip_directly(hero_id) else "— equip unlocks at Lv.%d" % int(ContentDatabase.bal("friendship", {}).get("equip_unlock_level", 3))], 9))
	detail.add_child(UIKit.label("HP %d  ATK %d  DEF %d  SPD %d | hire %dg" % [
		int(stats["hp"]), int(stats["atk"]), int(stats["def"]), int(stats["spd"]), int(hero.get("hire_cost", 100))], 10, UIKit.COL_ACCENT))
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
					pick_layer.queue_free()
					_show_hero(hero_id)))
	pvb.add_child(UIKit.button("Unequip", func() -> void:
		InventoryManager.equip(hero_id, slot, "")
		pick_layer.queue_free()
		_show_hero(hero_id)))
	pvb.add_child(UIKit.button("Cancel", func() -> void: pick_layer.queue_free()))
