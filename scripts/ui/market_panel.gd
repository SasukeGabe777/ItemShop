class_name MarketPanel
extends CanvasLayer
## Wholesale market: buy stock from every connected world. Prices react to
## active market events.

signal closed()


func _ready() -> void:
	layer = 40
	var parts := UIKit.modal(self, "Crossroads Market — wholesale")
	var vb: VBoxContainer = parts[1]
	var events := MarketManager.active_event_names()
	vb.add_child(UIKit.label("Market events: " + (", ".join(events) if not events.is_empty() else "calm"), 9, UIKit.COL_DIM))
	var gold_lbl := UIKit.label("Gold: %dg" % EconomyManager.gold, 10, UIKit.COL_ACCENT)
	vb.add_child(gold_lbl)
	var list_parts := UIKit.scroll_list(Vector2(360, 210))
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
	catalog.sort_custom(func(a: String, b: String) -> bool:
		return String(ContentDatabase.get_item(a).get("world", "")) < String(ContentDatabase.get_item(b).get("world", "")))
	for id in catalog:
		var cost := MarketManager.wholesale_cost(id)
		var value := MarketManager.market_value(id)
		var row := UIKit.item_row(id, "— buy %dg (sells ~%dg) | own %d" % [cost, value, InventoryManager.count(id)],
			"Buy", func() -> void:
				if EconomyManager.spend_gold(cost):
					InventoryManager.add_item(id)
					gold_lbl.text = "Gold: %dg" % EconomyManager.gold
					_fill(list, gold_lbl))
		list.add_child(row)
