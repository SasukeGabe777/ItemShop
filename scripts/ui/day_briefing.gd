class_name DayBriefing
## Large start-of-day popup: what today's market events actually mean — which
## goods sell high or low and which shoppers they pull into town. Shown once
## per day; the market panel can reopen it any time.

static var last_shown_day := -1


static func reset() -> void:
	last_shown_day = -1


## Show the report once per day. Skipped while a story scene is queued and
## during the guided KH opening (until the first sale lands) so the tutorial
## modals stay uncluttered.
static func maybe_show(parent: Node) -> void:
	if TimeManager.day == last_shown_day and not BoomManager.announcement_pending:
		return
	if StoryEventManager.has_pending():
		return
	var cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	var active := String(cfg.get("active_flag", ""))
	var starter := String(cfg.get("starter_sale_flag", ""))
	if active != "" and GameState.has_flag(active) \
			and starter != "" and not GameState.has_flag(starter):
		return
	last_shown_day = TimeManager.day
	show_report(parent)


static func show_report(parent: Node) -> CanvasLayer:
	var parts := UIKit.modal(parent, "")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	vb.custom_minimum_size = Vector2(500, 0)
	vb.add_theme_constant_override("separation", 4)
	var title := UIKit.label("Day %d — %s" % [TimeManager.day, TimeManager.period_name()], 22, UIKit.COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := ""
	if GameState.endless_mode:
		sub = "Endless mode"
	else:
		var world := ContentDatabase.world_for_chapter(TimeManager.chapter)
		sub = "Chapter %d · %s" % [TimeManager.chapter, String(world.get("name", ""))]
		if TimeManager.chapter <= 7:
			var left := TimeManager.chapter_deadline_day() - TimeManager.day
			sub += " · deadline in %d day%s" % [left, "" if left == 1 else "s"] if left > 0 else " · DEADLINE TODAY"
	var sub_lbl := UIKit.label(sub, 10, UIKit.COL_DIM)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub_lbl)
	vb.add_child(UIKit.hsep())
	if BoomManager.is_active():
		var boom_title := UIKit.label("BOOM ALERT: %s" % BoomManager.display_name(), 17, UIKit.COL_BAD)
		boom_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(boom_title)
		var boom_copy := UIKit.label(BoomManager.announcement(), 11, UIKit.COL_INK)
		boom_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boom_copy.custom_minimum_size.x = 470
		vb.add_child(boom_copy)
		for line in BoomManager.summary_lines():
			vb.add_child(UIKit.label("- " + line, 10, UIKit.COL_ACCENT))
		vb.add_child(UIKit.label("Prepare your storage and displays before opening. This Boom is consumed by shop sessions, not by time passing.", 9, UIKit.COL_DIM))
		vb.add_child(UIKit.hsep())
		BoomManager.mark_announced()
	var rep := UIKit.label("TODAY'S MARKET REPORT", 13, UIKit.COL_ACCENT)
	rep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rep)
	var any_effect := false
	for ev in MarketManager.active_event_details():
		vb.add_child(UIKit.spacer_px(4))
		var days := int(ev["days_left"])
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		vb.add_child(name_row)
		name_row.add_child(UIKit.label(String(ev["name"]), 14, UIKit.COL_INK))
		name_row.add_child(UIKit.label("%d more day%s" % [days, "" if days == 1 else "s"], 9, UIKit.COL_DIM))
		if String(ev["desc"]) != "":
			vb.add_child(UIKit.label("\"%s\"" % String(ev["desc"]), 10, UIKit.COL_DIM))
		var mults: Dictionary = ev["mults"]
		var highs: Array[String] = []
		var lows: Array[String] = []
		for key: String in mults:
			var m := float(mults[key])
			var entry := "%s %s" % [_key_label(key), _pct(m)]
			if m > 1.0:
				highs.append(entry)
			elif m < 1.0:
				lows.append(entry)
		if highs.is_empty() and lows.is_empty():
			vb.add_child(UIKit.label("Prices hold steady — no effect on trade.", 11, UIKit.COL_DIM))
			continue
		any_effect = true
		if not highs.is_empty():
			vb.add_child(UIKit.label("▲ Selling high: %s" % ", ".join(highs), 12, UIKit.COL_GOOD))
		if not lows.is_empty():
			vb.add_child(UIKit.label("▼ Selling low: %s" % ", ".join(lows), 12, UIKit.COL_BAD))
		var drawn := _drawn_archetypes(mults)
		if not drawn.is_empty():
			vb.add_child(UIKit.label("Drawn to your shop: %s" % ", ".join(drawn), 11, UIKit.COL_INK))
	if not any_effect:
		vb.add_child(UIKit.label("A calm market. Everything trades at normal prices.", 11, UIKit.COL_DIM))
	vb.add_child(UIKit.spacer_px(6))
	vb.add_child(UIKit.label("Tip: the Market screen colors every item green or red by today's demand.", 9, UIKit.COL_DIM))
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)
	var button_text := "Prepare for the Boom" if BoomManager.is_active() else "Start the day"
	btn_row.add_child(UIKit.button(button_text, func() -> void: layer.queue_free(), 12))
	return layer


## Archetype display names that like any of this event's boosted goods.
static func _drawn_archetypes(mults: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in ContentDatabase.archetypes:
		var arch: Dictionary = ContentDatabase.get_archetype(id)
		for key: String in mults:
			if float(mults[key]) <= 1.0:
				continue
			var hit: bool = (key.begins_with("tag:") and key.trim_prefix("tag:") in arch.get("likes_tags", [])) \
				or (key.begins_with("cat:") and key.trim_prefix("cat:") in arch.get("likes_categories", []))
			if hit:
				out.append(String(arch.get("name", id)))
				break
	return out


const CAT_LABELS := {
	"weapon": "Weapons", "armor": "Armor", "consumable": "Consumables",
	"food": "Food", "treasure": "Treasures", "material": "Materials",
	"accessory": "Accessories", "key": "Key items",
}


## "tag:healing" -> "Healing goods", "cat:weapon" -> "Weapons"
static func _key_label(key: String) -> String:
	if key.begins_with("cat:"):
		var c := key.trim_prefix("cat:")
		return String(CAT_LABELS.get(c, c.capitalize()))
	return key.trim_prefix("tag:").capitalize() + " goods"


## "+60%" / "−45%" formatting for a multiplier.
static func _pct(mult: float) -> String:
	var pct := int(round((mult - 1.0) * 100.0))
	return ("+%d%%" % pct) if pct >= 0 else ("−%d%%" % -pct)
