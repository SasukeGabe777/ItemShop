class_name WorkshopPanel
extends CanvasLayer
## Crossroads Workshop: crafting from data-driven recipes, including crossover
## recipes that combine franchises.

signal closed()

var list: VBoxContainer
var gold_lbl: Label


func _ready() -> void:
	layer = 40
	var parts := UIKit.modal(self, "Crossroads Workshop")
	var vb: VBoxContainer = parts[1]
	gold_lbl = UIKit.label("Gold: %dg" % EconomyManager.gold, 10, UIKit.COL_ACCENT)
	vb.add_child(gold_lbl)
	var list_parts := UIKit.scroll_list(Vector2(380, 220))
	vb.add_child(list_parts[0])
	list = list_parts[1]
	_fill()
	vb.add_child(UIKit.button("Close", func() -> void:
		closed.emit()
		queue_free()))


func _fill() -> void:
	UIKit.rebuild_list(list, _fill_rows)


func _fill_rows() -> void:
	var recipes := ContentDatabase.recipes_for_chapter(TimeManager.chapter)
	recipes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unlock_chapter", 1)) < int(b.get("unlock_chapter", 1)))
	for r in recipes:
		var out_id := String(r["output"])
		var fee := int(r.get("fee", 50))
		var can := EconomyManager.can_afford(fee)
		var needs: Array[String] = []
		for iid: String in r.get("inputs", {}):
			var need := int(r["inputs"][iid])
			var have := InventoryManager.count(iid)
			needs.append("%s %d/%d" % [ContentDatabase.item_name(iid), have, need])
			if have < need:
				can = false
		var count := int(r.get("count", 1))
		var tagline := " [CROSSOVER]" if bool(r.get("crossover", false)) else ""
		var prefix := "x%d " % count if count > 1 else ""
		var suffix := "%s← %s | fee %dg%s" % [prefix, ", ".join(needs), fee, tagline]
		var rid := String(r["id"])
		var row := UIKit.item_row(out_id, suffix, "Craft" if can else "—", func() -> void:
			_craft(rid))
		list.add_child(row)
	# future recipes show greyed so the workshop hints at what's coming
	var locked := ContentDatabase.recipes_for_chapter(99).filter(func(r: Dictionary) -> bool:
		return int(r.get("unlock_chapter", 1)) > TimeManager.chapter)
	locked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unlock_chapter", 1)) < int(b.get("unlock_chapter", 1)))
	if not locked.is_empty():
		list.add_child(UIKit.label("— locked recipes —", 9, UIKit.COL_DIM))
	for r in locked:
		var row := UIKit.item_row(String(r["output"]), "unlocks in Chapter %d" % int(r.get("unlock_chapter", 1)), "", Callable())
		row.modulate = Color(1, 1, 1, 0.45)
		list.add_child(row)


func _craft(recipe_id: String) -> void:
	var r := ContentDatabase.get_recipe(recipe_id)
	if r.is_empty():
		return
	var fee := int(r.get("fee", 50))
	for iid: String in r.get("inputs", {}):
		if InventoryManager.count(iid) < int(r["inputs"][iid]):
			return
	if not EconomyManager.spend_gold(fee):
		return
	for iid: String in r.get("inputs", {}):
		InventoryManager.remove_item(iid, int(r["inputs"][iid]))
	InventoryManager.add_item(String(r["output"]), int(r.get("count", 1)))
	AudioManager.play_sfx("acquired")
	GameState.set_flag("crafted_" + recipe_id)
	gold_lbl.text = "Gold: %dg" % EconomyManager.gold
	_fill()
