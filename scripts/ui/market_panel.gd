class_name MarketPanel
extends CanvasLayer
## Wholesale market: buy stock from every connected world. Prices react to
## active market events; each row shows the item's type, whether it sells
## high or low today, its blurb, and how many you already own. Sortable the
## same way shop storage is.

signal closed()

var _sort_mode := "hot"
var _list: VBoxContainer
var _gold_lbl: Label
var _sort_button: Button
var _rarity_button: Button
var _compact_mp := false
var _scroll: ScrollContainer
var _rarity_filter := "All"

const SORT_MODES := ["hot", "name", "price", "rarity", "category", "world"]
const RARITY_FILTERS := ["All", "Common", "Uncommon", "Rare", "Legendary"]


func _ready() -> void:
	layer = 40
	_compact_mp = MultiplayerState.enabled and MultiplayerState.ui_scale_factor() > 1.0
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
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vb.add_child(top_row)
	top_row.add_child(UIKit.gold_icon("small", Vector2(18, 15)))
	_gold_lbl = UIKit.label("Gold: %d" % EconomyManager.gold, 10, UIKit.COL_ACCENT)
	_gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_gold_lbl)
	_sort_button = UIKit.button("Sort: Hot →", _cycle_sort, 8)
	top_row.add_child(_sort_button)
	_rarity_button = UIKit.button("Rarity: All →", _cycle_rarity, 8)
	top_row.add_child(_rarity_button)
	# Leave room for the ornate frame and Close bar at the 640x360 design
	# viewport. A 230px list made this panel 17px taller than the screen.
	var list_parts := UIKit.scroll_list(Vector2(500, 205))
	_scroll = list_parts[0] as ScrollContainer
	if _compact_mp:
		(list_parts[0] as ScrollContainer).custom_minimum_size = Vector2(340, 200)
	vb.add_child(list_parts[0])
	_list = list_parts[1]
	Net.state_applied.connect(func(manager_name: String) -> void:
		if manager_name in ["economy", "inventory", "market", "*"] \
				and is_instance_valid(_list):
			_gold_lbl.text = "Gold: %d" % EconomyManager.gold
			_fill.call_deferred())
	_fill()
	vb.add_child(UIKit.button("Close", func() -> void:
		closed.emit()
		queue_free()))


func _set_sort(mode: String) -> void:
	_sort_mode = mode
	_fill()


func _cycle_sort() -> void:
	var next := (SORT_MODES.find(_sort_mode) + 1) % SORT_MODES.size()
	_set_sort(SORT_MODES[next])
	if _sort_button != null:
		_sort_button.text = "Sort: %s →" % _sort_mode.capitalize()


func _cycle_rarity() -> void:
	var next := (RARITY_FILTERS.find(_rarity_filter) + 1) % RARITY_FILTERS.size()
	_rarity_filter = RARITY_FILTERS[next]
	_rarity_button.text = "Rarity: %s →" % _rarity_filter
	if _scroll != null:
		_scroll.scroll_vertical = 0
	_fill()


func _fill() -> void:
	var old_scroll := _scroll.scroll_vertical if _scroll != null else 0
	UIKit.rebuild_list(_list, _fill_rows)
	# Rebuilt rows are created after the modal's first deferred Large-mode
	# font pass. Boost the fresh controls immediately so changing sort never
	# drops descriptions and prices back to their tiny base sizes.
	if _compact_mp:
		UIKit._boost_large_modal_fonts(_list)
	if _scroll != null:
		_restore_scroll.call_deferred(old_scroll)


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = mini(value,
			int(_scroll.get_v_scroll_bar().max_value))


func _fill_rows() -> void:
	var catalog := MarketManager.wholesale_catalog()
	if _rarity_filter != "All":
		catalog = catalog.filter(func(item_id: String) -> bool:
			return ContentDatabase.item_rarity(item_id) == _rarity_filter)
	match _sort_mode:
		"name":
			catalog.sort_custom(func(a: String, b: String) -> bool:
				return ContentDatabase.item_name(a) < ContentDatabase.item_name(b))
		"price":
			catalog.sort_custom(func(a: String, b: String) -> bool:
				return MarketManager.wholesale_cost(a) < MarketManager.wholesale_cost(b))
		"rarity":
			catalog.sort_custom(func(a: String, b: String) -> bool:
				var rarity_a := ContentDatabase.item_rarity_rank(a)
				var rarity_b := ContentDatabase.item_rarity_rank(b)
				return ContentDatabase.item_name(a) < ContentDatabase.item_name(b) \
					if rarity_a == rarity_b else rarity_a > rarity_b)
		"category":
			catalog.sort_custom(func(a: String, b: String) -> bool:
				var ca := String(ContentDatabase.get_item(a).get("category", ""))
				var cb := String(ContentDatabase.get_item(b).get("category", ""))
				return ca < cb if ca != cb else ContentDatabase.item_name(a) < ContentDatabase.item_name(b))
		"world":
			catalog.sort_custom(func(a: String, b: String) -> bool:
				var wa := String(ContentDatabase.get_item(a).get("world", ""))
				var wb := String(ContentDatabase.get_item(b).get("world", ""))
				return wa < wb if wa != wb else ContentDatabase.item_name(a) < ContentDatabase.item_name(b))
		_:
			# hot items float to the top, crashed items sink
			catalog.sort_custom(func(a: String, b: String) -> bool:
				var ma := MarketManager.price_multiplier(a)
				var mb := MarketManager.price_multiplier(b)
				if absf(ma - mb) > 0.001:
					return ma > mb
				return String(ContentDatabase.get_item(a).get("world", "")) < String(ContentDatabase.get_item(b).get("world", "")))
	# progression gate: everything is listed (like the workshop's locked
	# recipes), but goods beyond the current chapter's customer purses are
	# greyed out and can't be bought yet
	var locked: Array[String] = []
	for id in catalog:
		if _locked_reason(id) == "":
			_list.add_child(_make_row(id))
		else:
			locked.append(id)
	if not locked.is_empty():
		_list.add_child(UIKit.label("— beyond today's market —", 9, UIKit.COL_DIM))
	for id in locked:
		_list.add_child(_make_row(id, _locked_reason(id)))


## Why an item can't be bought yet ("" = purchasable). Two gates: the item's
## world must be reachable (chapter), and its price must sit inside what this
## chapter's customers can realistically pay — no Peach's Dress on Day 1.
func _locked_reason(id: String) -> String:
	return MarketManager.item_locked_reason(id)


func _make_row(id: String, locked_reason: String = "") -> VBoxContainer:
	var it := ContentDatabase.get_item(id)
	var cost := MarketManager.wholesale_cost(id)
	var value := MarketManager.market_value(id)
	var entry := VBoxContainer.new()
	entry.set_meta("item_id", id)
	if locked_reason != "":
		entry.modulate = Color(1, 1, 1, 0.45)
	entry.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 26)
	entry.add_child(row)
	# every column has a fixed width so rows line up; oversized art is capped
	row.add_child(UIKit.item_icon(id))
	var rarity_badge := UIKit.rarity_label(id)
	rarity_badge.custom_minimum_size.x = 58
	row.add_child(rarity_badge)
	var name_lbl := UIKit.label(ContentDatabase.item_name(id), 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)
	var mult := MarketManager.price_multiplier(id)
	var trend_text := "— steady"
	var trend_color := UIKit.COL_DIM
	if mult >= 1.05:
		trend_text = "▲ %s today" % DayBriefing._pct(mult)
		trend_color = UIKit.COL_GOOD
	elif mult <= 0.95:
		trend_text = "▼ %s today" % DayBriefing._pct(mult)
		trend_color = UIKit.COL_BAD
	if not _compact_mp:
		var trend_lbl := UIKit.label(
			trend_text, 10 if mult >= 1.05 or mult <= 0.95 else 9, trend_color)
		trend_lbl.custom_minimum_size = Vector2(78, 0)
		row.add_child(trend_lbl)
	var price_lbl := UIKit.label("%dg → ~%dg" % [cost, value], 9, UIKit.COL_INK)
	price_lbl.custom_minimum_size = Vector2(100, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.tooltip_text = "Buy for %dg, sells for about %dg" % [cost, value]
	price_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(price_lbl)
	var buy_btn := UIKit.button("Buy", func() -> void:
		Net.request("market.buy", {"item_id": id},
			func(ok: bool, _result: Dictionary) -> void:
				if ok:
					AudioManager.play_sfx("acquired", -4.0)
					_gold_lbl.text = "Gold: %d" % EconomyManager.gold
					_fill.call_deferred()))
	if locked_reason != "":
		buy_btn.disabled = true
		buy_btn.text = "—"
		buy_btn.tooltip_text = locked_reason
	buy_btn.custom_minimum_size = Vector2(46, 0)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy_btn)
	var owned := InventoryManager.count(id)
	var sell_btn := UIKit.button("Sell\n%dg" % MarketManager.sellback_value(id),
		func() -> void:
			Net.request("market.sell", {"item_id": id},
				func(ok: bool, _result: Dictionary) -> void:
					if ok:
						AudioManager.play_sfx("itemsale", -4.0)
						_gold_lbl.text = "Gold: %d" % EconomyManager.gold
						_fill.call_deferred()), 8)
	sell_btn.disabled = owned <= 0
	sell_btn.tooltip_text = "Sell one from storage back to the market at 35% of today's value."
	sell_btn.custom_minimum_size = Vector2(48, 0)
	row.add_child(sell_btn)
	# blurb + owned count live on the row itself (was tooltip-only)
	var sub_text := String(it.get("desc", ""))
	if _compact_mp:
		sub_text = "%s · %s — %s" % [
			String(it.get("category", "")).capitalize(), trend_text, sub_text]
	else:
		sub_text = "%s — %s" % [
			String(it.get("category", "")).capitalize(), sub_text]
	if owned > 0:
		sub_text = "Owned: %d — %s" % [owned, sub_text]
	if locked_reason != "":
		sub_text = "%s — %s" % [locked_reason, sub_text]
	var sub := UIKit.label(sub_text, 8, UIKit.COL_DIM)
	sub.clip_text = not _compact_mp
	if _compact_mp:
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sub_pad := MarginContainer.new()
	sub_pad.add_theme_constant_override("margin_left", 30)
	sub_pad.add_theme_constant_override("margin_bottom", 4)
	sub_pad.add_child(sub)
	entry.add_child(sub_pad)
	return entry
