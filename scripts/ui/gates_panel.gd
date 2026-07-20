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
	dvb.add_child(UIKit.label("Hire a hero:" if not MultiplayerState.enabled else "Player 1's hero:"))
	dvb.add_child(hero_pick)
	var hero_pick2: OptionButton = null
	if MultiplayerState.enabled:
		hero_pick2 = OptionButton.new()
		for hid in hero_options:
			var stats2 := InventoryManager.hero_stats(hid)
			hero_pick2.add_item("%s — %dg (HP %d ATK %d)" % [String(ContentDatabase.get_hero(hid).get("name", hid)),
				int(ContentDatabase.get_hero(hid).get("hire_cost", 100)), int(stats2["hp"]), int(stats2["atk"])])
		if hero_options.size() > 1:
			hero_pick2.selected = 1
		dvb.add_child(UIKit.label("Player 2's hero:"))
		dvb.add_child(hero_pick2)
	# --- consumables: each player packs their own belt ----------------------
	var max_slots := int(ContentDatabase.bal("dungeon", {}).get("consumable_slots", 2))
	var chosen: Array = []
	var chosen2: Array = []
	# the dropdown says what each item actually does, so a 40 HP potion is
	# distinguishable from a 200 HP one before a slot is spent on it
	var consum_ids: Array[String] = []
	var consum_labels: Array[String] = []
	for id in InventoryManager.sorted_ids("name"):
		var it := ContentDatabase.get_item(id)
		# only offer items that actually do something in a dungeon; capture and
		# escape items have no field effect and would waste a slot
		if String(it.get("category", "")) in ["consumable", "food"] 				and ContentDatabase.is_field_usable(id):
			consum_ids.append(id)
			var fx := ContentDatabase.item_effect_summary(id)
			consum_labels.append("%s x%d%s" % [ContentDatabase.item_name(id),
				InventoryManager.count(id), " — %s" % fx if fx != "" else ""])
	# a picker per player; stock is shared, so both belts count against it
	var make_picker := func(target: Array, other: Array, who: String) -> void:
		dvb.add_child(UIKit.label("%sconsumables (up to %d):" % [who, max_slots]))
		var lbl := UIKit.label("(none)", 9, UIKit.COL_DIM)
		var row := HBoxContainer.new()
		var pick := OptionButton.new()
		for t in consum_labels:
			pick.add_item(t)
		row.add_child(pick)
		row.add_child(UIKit.button("Add", func() -> void:
			if target.size() >= max_slots or consum_ids.is_empty():
				return
			var id := consum_ids[pick.selected]
			# reserved by BOTH belts — you cannot pack the same potion twice
			var reserved := target.count(id) + other.count(id)
			if InventoryManager.count(id) <= reserved:
				lbl.text = "No more %s in stock!" % ContentDatabase.item_name(id)
				return
			target.append(id)
			var names: Array[String] = []
			for c in target:
				var fx2 := ContentDatabase.item_effect_summary(String(c))
				names.append("%s (%s)" % [ContentDatabase.item_name(String(c)), fx2]
					if fx2 != "" else ContentDatabase.item_name(String(c)))
			lbl.text = ", ".join(names)))
		row.add_child(UIKit.button("Clear", func() -> void:
			target.clear()
			lbl.text = "(none)"))
		dvb.add_child(row)
		dvb.add_child(lbl)
	if MultiplayerState.enabled:
		make_picker.call(chosen, chosen2, "Player 1's ")
		make_picker.call(chosen2, chosen, "Player 2's ")
	else:
		make_picker.call(chosen, chosen2, "Bring ")
	var chosen_lbl := UIKit.label("", 9, UIKit.COL_DIM)
	dvb.add_child(chosen_lbl)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override("separation", 12)
	var depart_label := "Depart: Short Traverse Town Run (2 periods)" if first_vertical_slice else "Depart (2 periods)"
	go_row.add_child(UIKit.button(depart_label, func() -> void:
		var hid := hero_options[hero_pick.selected]
		var hid2 := ""
		var fee := int(ContentDatabase.get_hero(hid).get("hire_cost", 100))
		if hero_pick2 != null:
			hid2 = hero_options[hero_pick2.selected]
			fee += int(ContentDatabase.get_hero(hid2).get("hire_cost", 100))
		if not EconomyManager.can_afford(fee):
			chosen_lbl.text = "Not enough gold for the hire fee%s (%dg)!" % ["s" if hid2 != "" else "", fee]
			return
		var launch := func() -> void:
			dlg_layer.queue_free()
			UIKit.confirm_time_cost(self, "The expedition", TimeManager.activity_cost("dungeon"), func() -> void:
				EconomyManager.spend_gold(fee)
				for c in chosen:
					InventoryManager.remove_item(String(c))
				for c2 in chosen2:
					InventoryManager.remove_item(String(c2))
				if GameState.meet_hero(hid):
					StoryEventManager.fire("hero_met", {"hero": hid})
				if hid2 != "" and GameState.meet_hero(hid2):
					StoryEventManager.fire("hero_met", {"hero": hid2})
				DungeonManager.plan_expedition(world_id, hid, chosen, first_vertical_slice, hid2, chosen2)
				AudioManager.play_sfx("enter_expedition")
				var events := TimeManager.advance(TimeManager.activity_cost("dungeon"))
				if "deadline_failed" in events:
					SceneRouter.go("story", {"failure": true})
				elif StoryEventManager.has_pending():
					SceneRouter.go("story", {"return_to": "dungeon"})
				else:
					SceneRouter.go("dungeon"))
		if MultiplayerState.enabled:
			# the partner joins with a world-side A press — no second menu
			var who := int(get_meta("owner_player", 1))
			var other := 3 - who
			MultiplayerState.request_confirm("expedition", other,
				"Join the expedition to %s!" % String(ContentDatabase.get_world(world_id).get("name", world_id)), launch)
			dlg_layer.tree_exiting.connect(func() -> void: MultiplayerState.clear_confirm("expedition"))
			chosen_lbl.text = "Waiting for Player %d — they press A anywhere to join!" % other
			return
		launch.call()))
	go_row.add_child(UIKit.button("Cancel", func() -> void: dlg_layer.queue_free()))
	dvb.add_child(go_row)
