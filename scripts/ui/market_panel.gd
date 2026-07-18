class_name MarketPanel
extends CanvasLayer
## Wholesale market: buy stock from every connected world. Prices react to
## active market events; each row shows the item's type and whether it is
## selling high (green) or low (red) today.

signal closed()


func _ready() -> void:
	layer = 40
	var parts := UIKit.modal(self, "Crossroads Market — wholesale")
	var vb: VBoxContainer = parts[1]
	var ev_row := HBoxContainer.new()
	ev_row.add_theme_constant_override("separation", 8)
	vb.add_child(ev_row)
	var events := MarketManager.active_event_names()
	var ev_lbl := UIKit.label("Market events: " + (", ".join(events) if not events.is_empty() else "calm"), 9, UIKit.COL_DIM)
	ev_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev_row.add_child(ev_lbl)
	ev_row.add_child(UIKit.button("Today's report", func() -> void: DayBriefing.show_report(self), 8))
	var gold_lbl := UIKit.label("Gold: %dg" % EconomyManager.gold, 10, UIKit.COL_ACCENT)
	vb.add_child(gold_lbl)
	var list_parts := UIKit.scroll_list(Vector2(470, 210))
	vb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	_fill(list, gold_lbl)
	vb.add_child(UIKit.button("Close", func() -> void:
		closed.emit()
		queue_free()))


func _fill(list: VBoxContainer, gold_lbl: Label) -> void:
	for child in list.get_children():
		child.queue_free()
	var catalog := MarketManager.wholesale_catalog()
	# hot items float to the top, crashed items sink, worlds group in between
	catalog.sort_custom(func(a: String, b: String) -> bool:
		var ma := MarketManager.price_multiplier(a)
		var mb := MarketManager.price_multiplier(b)
		if absf(ma - mb) > 0.001:
			return ma > mb
		return String(ContentDatabase.get_item(a).get("world", "")) < String(ContentDatabase.get_item(b).get("world", "")))
	for id in catalog:
		list.add_child(_make_row(id, list, gold_lbl))


func _make_row(id: String, list: VBoxContainer, gold_lbl: Label) -> HBoxContainer:
	var it := ContentDatabase.get_item(id)
	var cost := MarketManager.wholesale_cost(id)
	var value := MarketManager.market_value(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = ContentDatabase.item_texture(id)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var name_lbl := UIKit.label(ContentDatabase.item_name(id), 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.tooltip_text = "%s\nOwned: %d" % [String(it.get("desc", "")), InventoryManager.count(id)]
	name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(name_lbl)
	var cat_lbl := UIKit.label(String(it.get("category", "")).capitalize(), 9, UIKit.COL_DIM)
	cat_lbl.custom_minimum_size = Vector2(64, 0)
	row.add_child(cat_lbl)
	var mult := MarketManager.price_multiplier(id)
	var trend_lbl := UIKit.label("— steady", 9, UIKit.COL_DIM)
	if mult >= 1.05:
		trend_lbl = UIKit.label("▲ %s today" % DayBriefing._pct(mult), 10, UIKit.COL_GOOD)
	elif mult <= 0.95:
		trend_lbl = UIKit.label("▼ %s today" % DayBriefing._pct(mult), 10, UIKit.COL_BAD)
	trend_lbl.custom_minimum_size = Vector2(78, 0)
	row.add_child(trend_lbl)
	var price_lbl := UIKit.label("%dg → ~%dg" % [cost, value], 9, UIKit.COL_INK)
	price_lbl.tooltip_text = "Buy for %dg, sells for about %dg" % [cost, value]
	price_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(price_lbl)
	row.add_child(UIKit.button("Buy", func() -> void:
		if EconomyManager.spend_gold(cost):
			InventoryManager.add_item(id)
			AudioManager.play_sfx("acquired", -4.0)
			gold_lbl.text = "Gold: %dg" % EconomyManager.gold
			_fill(list, gold_lbl)))
	return row
