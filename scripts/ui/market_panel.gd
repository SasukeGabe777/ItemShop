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
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vb.add_child(top_row)
	top_row.add_child(UIKit.gold_icon("small", Vector2(18, 15)))
	_gold_lbl = UIKit.label("Gold: %d" % EconomyManager.gold, 10, UIKit.COL_ACCENT)
	_gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_gold_lbl)
	for mode in ["hot", "name", "price", "category", "world"]:
		top_row.add_child(UIKit.button("Sort: %s" % mode, _set_sort.bind(mode), 8))
	var list_parts := UIKit.scroll_list(Vector2(500, 230))
	vb.add_child(list_parts[0])
	_list = list_parts[1]
	_fill()
	vb.add_child(UIKit.button("Close", func() -> void:
		closed.emit()
		queue_free()))


func _set_sort(mode: String) -> void:
	_sort_mode = mode
	_fill()


func _fill() -> void:
	UIKit.rebuild_list(_list, _fill_rows)


func _fill_rows() -> void:
	var catalog := MarketManager.wholesale_catalog()
	match _sort_mode:
		"name":
			catalog.sort_custom(func(a: String, b: String) -> bool:
				return ContentDatabase.item_name(a) < ContentDatabase.item_name(b))
		"price":
			catalog.sort_custom(func(a: String, b: String) -> bool:
				return MarketManager.wholesale_cost(a) < MarketManager.wholesale_cost(b))
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
	var it := ContentDatabase.get_item(id)
	var w := ContentDatabase.get_world(String(it.get("world", "")))
	var world_ch := int(w.get("chapter", 99 if bool(w.get("final", false)) else 1))
	if world_ch > TimeManager.chapter:
		return "world sealed until Ch.%d" % world_ch
	var price := ContentDatabase.item_price(id)
	if float(price) > _price_cap(TimeManager.chapter):
		return "customers can't afford this until Ch.%d" % _chapter_for_price(price)
	return ""


## Customer budgets scale ~0.85x per chapter (see CustomerGen); the cap keeps
## market stock inside what those purses can actually pay.
static func _price_cap(chapter: int) -> float:
	var cfg: Dictionary = ContentDatabase.bal("market_unlock", {})
	return float(cfg.get("base_cap", 800.0)) * (1.0 + float(cfg.get("per_chapter_scale", 0.85)) * (chapter - 1))


static func _chapter_for_price(price: int) -> int:
	for ch in range(1, 9):
		if float(price) <= _price_cap(ch):
			return ch
	return 8


func _make_row(id: String, locked_reason: String = "") -> VBoxContainer:
	var it := ContentDatabase.get_item(id)
	var cost := MarketManager.wholesale_cost(id)
	var value := MarketManager.market_value(id)
	var entry := VBoxContainer.new()
	if locked_reason != "":
		entry.modulate = Color(1, 1, 1, 0.45)
	entry.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 26)
	entry.add_child(row)
	# every column has a fixed width so rows line up; oversized art is capped
	var icon := TextureRect.new()
	icon.texture = ContentDatabase.item_texture(id)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var name_lbl := UIKit.label(ContentDatabase.item_name(id), 10)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
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
	price_lbl.custom_minimum_size = Vector2(88, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.tooltip_text = "Buy for %dg, sells for about %dg" % [cost, value]
	price_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(price_lbl)
	var buy_btn := UIKit.button("Buy", func() -> void:
		if EconomyManager.spend_gold(cost):
			InventoryManager.add_item(id)
			AudioManager.play_sfx("acquired", -4.0)
			_gold_lbl.text = "Gold: %d" % EconomyManager.gold
			_fill())
	if locked_reason != "":
		buy_btn.disabled = true
		buy_btn.text = "—"
		buy_btn.tooltip_text = locked_reason
	buy_btn.custom_minimum_size = Vector2(46, 0)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy_btn)
	# blurb + owned count live on the row itself (was tooltip-only)
	var owned := InventoryManager.count(id)
	var sub_text := String(it.get("desc", ""))
	if owned > 0:
		sub_text = "Owned: %d — %s" % [owned, sub_text]
	if locked_reason != "":
		sub_text = "%s — %s" % [locked_reason, sub_text]
	var sub := UIKit.label(sub_text, 8, UIKit.COL_DIM)
	sub.clip_text = true
	var sub_pad := MarginContainer.new()
	sub_pad.add_theme_constant_override("margin_left", 30)
	sub_pad.add_theme_constant_override("margin_bottom", 4)
	sub_pad.add_child(sub)
	entry.add_child(sub_pad)
	return entry
