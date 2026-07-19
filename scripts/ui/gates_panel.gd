class_name GatesPanel
extends CanvasLayer
## The World Bridge gates: gate status, repairs, and launching expeditions
## (hero hire + consumables + 2-period confirmation).

signal closed()

var vb: VBoxContainer
var content: VBoxContainer


func _ready() -> void:
	layer = 40
	var parts := UIKit.modal(self, "World Bridge Gates")
	vb = parts[1]
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	vb.add_child(content)
	vb.add_child(UIKit.hsep())
	vb.add_child(UIKit.button("Close", func() -> void:
		closed.emit()
		queue_free()))
	_fill()


func _fill() -> void:
	UIKit.rebuild_list(content, _fill_rows)


func _fill_rows() -> void:
	# the broken bridge itself: one plank per chapter world, lit when repaired
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 4)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(7):
		var world := ContentDatabase.world_for_chapter(i + 1)
		var repaired := BridgeManager.is_repaired(String(world.get("id", "")))
		var plank := ColorRect.new()
		plank.custom_minimum_size = Vector2(44, 10)
		plank.color = Color(String(world.get("accent_color", "#888888"))) if repaired else Color("#2a2d3f")
		plank.tooltip_text = "%s — %s" % [String(world.get("name", "?")), "repaired" if repaired else "broken"]
		plank.mouse_filter = Control.MOUSE_FILTER_STOP
		strip.add_child(plank)
	content.add_child(strip)
	content.add_child(UIKit.hsep())
	for world_id in ContentDatabase.world_order:
		var w := ContentDatabase.get_world(world_id)
		var final := bool(w.get("final", false))
		var chap := int(w.get("chapter", 99))
		var row := HBoxContainer.new()
		var status := ""
		if final:
			if TimeManager.chapter < 8:
				continue
			status = "THE FADE AWAITS" if not BridgeManager.fade_defeated else "quiet now"
		elif BridgeManager.is_repaired(world_id):
			status = "CONNECTED"
		elif chap == TimeManager.chapter:
			status = "shard %s | repair %dg" % ["OK" if BridgeManager.has_shard(world_id) else "needed", BridgeManager.repair_cost(world_id)]
		elif chap < TimeManager.chapter:
			status = "shard %s | repair %dg (overdue)" % ["OK" if BridgeManager.has_shard(world_id) else "needed", BridgeManager.repair_cost(world_id)]
		else:
			row.add_child(UIKit.label("Ch.%d  %s — sealed" % [chap, String(w.get("name", world_id))], 10, UIKit.COL_DIM))
			content.add_child(row)
			continue
		var wins := int(GameState.stats.get("expedition_wins_%s" % world_id, 0))
		var mastered := wins >= 3
		var lbl_text := "Ch.%d  %s — %s" % [chap, String(w.get("name", world_id)), status] if not final else "FINAL  %s — %s" % [String(w.get("name", "")), status]
		if mastered:
			lbl_text = "★ " + lbl_text
		var lbl := UIKit.label(lbl_text)
		if mastered:
			# three boss kills: the dungeon is fully mastered — gold it
			lbl.add_theme_color_override("font_color", UIKit.COL_ACCENT)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var accessible := world_id in BridgeManager.accessible_worlds()
		if accessible:
			var exp_btn := UIKit.button("★ Expedition" if mastered else "Expedition", func() -> void: _expedition_dialog(world_id))
			if mastered:
				exp_btn.add_theme_color_override("font_color", UIKit.COL_ACCENT)
			row.add_child(exp_btn)
		if not final and not BridgeManager.is_repaired(world_id) and BridgeManager.has_shard(world_id):
			var can_pay := EconomyManager.can_afford(BridgeManager.repair_cost(world_id))
			var pay_btn := UIKit.button("Pay repair", func() -> void:
				if BridgeManager.pay_repair(world_id):
					AudioManager.play_stinger("victory_stinger")
					SaveManager.checkpoint_chapter()
					_fill()
					closed.emit())
			pay_btn.disabled = not can_pay
			row.add_child(pay_btn)
		content.add_child(row)


func _expedition_dialog(world_id: String) -> void:
	var parts := UIKit.modal(self, "Expedition: %s" % String(ContentDatabase.get_world(world_id).get("location", world_id)))
	var dlg_layer: CanvasLayer = parts[0]
	var dvb: VBoxContainer = parts[1]
	var w := ContentDatabase.get_world(world_id)
	dvb.add_child(UIKit.label(String(w.get("dungeon_desc", "")), 9, UIKit.COL_DIM))
	var slice_cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	var completion_flag := String(slice_cfg.get("completion_flag", ""))
	var first_vertical_slice := (
		world_id == String(slice_cfg.get("world_id", ""))
		and completion_flag != ""
		and not GameState.has_flag(completion_flag)
	)
	if first_vertical_slice:
		dvb.add_child(UIKit.label("FIRST EXPEDITION: two short rooms, one Shadow, then return with its Lucid Shard.", 9, UIKit.COL_GOOD))
	var final := bool(w.get("final", false))
	# hero choice: world hero by default; any met hero for the final dungeon;
	# repaired worlds' heroes are also available anywhere (crossover hiring)
	var hero_options: Array[String] = []
	if final:
		for wid in ContentDatabase.world_order:
			var ww := ContentDatabase.get_world(wid)
			if not bool(ww.get("final", false)) and BridgeManager.is_repaired(wid):
				hero_options.append(String(ww.get("hero", "")))
	else:
		# a world may field several of its own heroes (Mario AND Luigi)
		for hid: Variant in w.get("heroes", [w.get("hero", "")]):
			hero_options.append(String(hid))
		for wid in ContentDatabase.world_order:
			var ww := ContentDatabase.get_world(wid)
			if wid != world_id and not bool(ww.get("final", false)) and BridgeManager.is_repaired(wid):
				hero_options.append(String(ww.get("hero", "")))
	if hero_options.is_empty():
		hero_options.append(String(ContentDatabase.world_for_chapter(1).get("hero", "sora")))
	var hero_pick := OptionButton.new()
	for hid in hero_options:
		var stats := InventoryManager.hero_stats(hid)
		hero_pick.add_item("%s — %dg (HP %d ATK %d)" % [String(ContentDatabase.get_hero(hid).get("name", hid)),
			int(ContentDatabase.get_hero(hid).get("hire_cost", 100)), int(stats["hp"]), int(stats["atk"])])
	dvb.add_child(UIKit.label("Hire a hero:"))
	dvb.add_child(hero_pick)
	dvb.add_child(UIKit.label("Bring consumables (up to %d):" % int(ContentDatabase.bal("dungeon", {}).get("consumable_slots", 2))))
	var chosen: Array = []
	var chosen_lbl := UIKit.label("(none)", 9, UIKit.COL_DIM)
	var pick_row := HBoxContainer.new()
	var consum_pick := OptionButton.new()
	var consum_ids: Array[String] = []
	for id in InventoryManager.sorted_ids("name"):
		var it := ContentDatabase.get_item(id)
		if String(it.get("category", "")) in ["consumable", "food"]:
			consum_ids.append(id)
			consum_pick.add_item("%s x%d" % [ContentDatabase.item_name(id), InventoryManager.count(id)])
	pick_row.add_child(consum_pick)
	pick_row.add_child(UIKit.button("Add", func() -> void:
		var max_slots := int(ContentDatabase.bal("dungeon", {}).get("consumable_slots", 2))
		if chosen.size() >= max_slots or consum_ids.is_empty():
			return
		var id := consum_ids[consum_pick.selected]
		var already := chosen.count(id)
		if InventoryManager.count(id) > already:
			chosen.append(id)
			var names: Array[String] = []
			for c in chosen:
				names.append(ContentDatabase.item_name(String(c)))
			chosen_lbl.text = ", ".join(names)))
	dvb.add_child(pick_row)
	dvb.add_child(chosen_lbl)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override("separation", 12)
	var depart_label := "Depart: Short Traverse Town Run (2 periods)" if first_vertical_slice else "Depart (2 periods)"
	go_row.add_child(UIKit.button(depart_label, func() -> void:
		var hid := hero_options[hero_pick.selected]
		var fee := int(ContentDatabase.get_hero(hid).get("hire_cost", 100))
		if not EconomyManager.can_afford(fee):
			chosen_lbl.text = "Not enough gold for the hire fee (%dg)!" % fee
			return
		dlg_layer.queue_free()
		UIKit.confirm_time_cost(self, "The expedition", TimeManager.activity_cost("dungeon"), func() -> void:
			EconomyManager.spend_gold(fee)
			for c in chosen:
				InventoryManager.remove_item(String(c))
			if GameState.meet_hero(hid):
				StoryEventManager.fire("hero_met", {"hero": hid})
			DungeonManager.plan_expedition(world_id, hid, chosen, first_vertical_slice)
			AudioManager.play_sfx("enter_expedition")
			var events := TimeManager.advance(TimeManager.activity_cost("dungeon"))
			if "deadline_failed" in events:
				SceneRouter.go("story", {"failure": true})
			elif StoryEventManager.has_pending():
				SceneRouter.go("story", {"return_to": "dungeon"})
			else:
				SceneRouter.go("dungeon"))))
	go_row.add_child(UIKit.button("Cancel", func() -> void: dlg_layer.queue_free()))
	dvb.add_child(go_row)
