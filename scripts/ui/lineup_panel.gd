class_name LineupPanel
extends CanvasLayer
## Online expedition lineup. Opens on EVERY machine when the host announces a
## world; each player picks their OWN hero + consumable belt and readies up.
## The host launches once everyone is ready (GatesPanel.depart_party).

var world_id: String
var _chosen: Array = []
var _status: Label


func setup(world: String, _is_slice: bool = false) -> void:
	world_id = world


func _ready() -> void:
	layer = 44
	var parts := UIKit.modal(self, "Expedition: %s"
		% String(ContentDatabase.get_world(world_id).get("location", world_id)))
	var dvb: VBoxContainer = parts[1]
	var w := ContentDatabase.get_world(world_id)
	dvb.add_child(UIKit.label(String(w.get("dungeon_desc", "")), 9, UIKit.COL_DIM))

	var hero_options := GatesPanel.hero_options_for(world_id)
	var hero_pick := OptionButton.new()
	for hid in hero_options:
		var st := InventoryManager.hero_stats(hid)
		hero_pick.add_item("%s — %dg (HP %d ATK %d)" % [
			String(ContentDatabase.get_hero(hid).get("name", hid)),
			int(ContentDatabase.get_hero(hid).get("hire_cost", 100)),
			int(st["hp"]), int(st["atk"])])
	# default P2..P5 to a different hero than P1 so twins differ, like couch did
	var seat := PartyState.local_index()
	if hero_options.size() > 1 and seat > 1:
		hero_pick.selected = (seat - 1) % hero_options.size()
	dvb.add_child(UIKit.label("%s's hero:" % PartyState.pname(seat)))
	dvb.add_child(hero_pick)

	# consumable belt (advisory stock check — the host re-validates at depart)
	var max_slots := int(ContentDatabase.bal("dungeon", {}).get("consumable_slots", 2))
	var consum_ids: Array[String] = []
	var consum_labels: Array[String] = []
	for id in InventoryManager.sorted_ids("name"):
		var it := ContentDatabase.get_item(id)
		if String(it.get("category", "")) in ["consumable", "food"] \
				and ContentDatabase.is_field_usable(id):
			consum_ids.append(id)
			var fx := ContentDatabase.item_effect_summary(id)
			consum_labels.append("%s x%d%s" % [ContentDatabase.item_name(id),
				InventoryManager.count(id), " — %s" % fx if fx != "" else ""])
	dvb.add_child(UIKit.label("Your consumables (up to %d):" % max_slots))
	var belt_lbl := UIKit.label("(none)", 9, UIKit.COL_DIM)
	var belt_row := HBoxContainer.new()
	var pick := OptionButton.new()
	for t in consum_labels:
		pick.add_item(t)
	belt_row.add_child(pick)
	belt_row.add_child(UIKit.button("Add", func() -> void:
		if _chosen.size() >= max_slots or consum_ids.is_empty():
			return
		_chosen.append(consum_ids[pick.selected])
		var names: Array[String] = []
		for c in _chosen:
			names.append(ContentDatabase.item_name(String(c)))
		belt_lbl.text = ", ".join(names)))
	belt_row.add_child(UIKit.button("Clear", func() -> void:
		_chosen.clear()
		belt_lbl.text = "(none)"))
	dvb.add_child(belt_row)
	dvb.add_child(belt_lbl)

	_status = UIKit.label("", 9, UIKit.COL_ACCENT)
	dvb.add_child(_status)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override("separation", 12)
	var ready_btn := UIKit.button("Ready — depart when all are set", func() -> void: pass)
	ready_btn.pressed.connect(func() -> void:
		ready_btn.disabled = true
		hero_pick.disabled = true
		_status.text = "Waiting for the rest of the party..."
		Net.request("lineup.set", {"hero_id": hero_options[hero_pick.selected],
			"consumables": _chosen}))
	go_row.add_child(ready_btn)
	# any player can back the whole party out of the lineup
	go_row.add_child(UIKit.button("Cancel", func() -> void:
		Net.request("lineup.cancel")))
	dvb.add_child(go_row)


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text
