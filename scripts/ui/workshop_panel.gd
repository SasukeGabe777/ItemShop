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
	var gold_row := HBoxContainer.new()
	gold_row.add_child(UIKit.gold_icon("small", Vector2(18, 15)))
	gold_lbl = UIKit.label("Gold: %d" % EconomyManager.gold, 10, UIKit.COL_ACCENT)
	gold_row.add_child(gold_lbl)
	vb.add_child(gold_row)
	vb.add_child(UIKit.label("Base values are shown so every craft can be judged before spending. Daily market trends may change resale value.", 8, UIKit.COL_DIM))
	var list_parts := UIKit.scroll_list(Vector2(520, 250))
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
		var chapter_a := int(a.get("unlock_chapter", 1))
		var chapter_b := int(b.get("unlock_chapter", 1))
		if chapter_a != chapter_b:
			return chapter_a < chapter_b
		return ContentDatabase.item_name(String(a.get("output", ""))) < ContentDatabase.item_name(String(b.get("output", ""))))
	for r in recipes:
		var out_id := String(r["output"])
		var fee := int(r.get("fee", 50))
		var can := EconomyManager.can_afford(fee)
		var needs: Array[String] = []
		var materials_value := 0
		for iid: String in r.get("inputs", {}):
			var need := int(r["inputs"][iid])
			var have := InventoryManager.count(iid)
			needs.append("%d× %s (%d owned)" % [need, ContentDatabase.item_name(iid), have])
			materials_value += int(round(float(ContentDatabase.get_item(iid).get("price", 0)))) * need
			if have < need:
				can = false
		var count := int(r.get("count", 1))
		var output_value := int(round(float(ContentDatabase.get_item(out_id).get("price", 0)))) * count
		var total_cost := materials_value + fee
		var margin := output_value - total_cost
		var tagline := "  [CROSSOVER]" if bool(r.get("crossover", false)) else ""
		var rid := String(r["id"])
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		var row := UIKit.item_row(out_id, "×%d%s" % [count, tagline], "Craft" if can else "Missing", func() -> void:
			_craft(rid))
		var craft_button := row.get_child(row.get_child_count() - 1) as Button
		craft_button.disabled = not can
		entry.add_child(row)
		var needs_line := UIKit.label("Uses: %s  •  Workshop fee: %dg" % [", ".join(needs), fee], 8,
			UIKit.COL_DIM if can else UIKit.COL_BAD)
		needs_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(needs_line)
		var value_line := UIKit.label("Value: materials %dg + fee %dg = %dg  →  output %dg  (craft gain +%dg)" % [
			materials_value, fee, total_cost, output_value, margin], 8, UIKit.COL_GOOD if margin >= 0 else UIKit.COL_BAD)
		value_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(value_line)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_bottom", 5)
		entry.add_child(pad)
		list.add_child(entry)
	# Future recipes show greyed so the workshop hints at what's coming.
	var locked := ContentDatabase.recipes_for_chapter(99).filter(func(r: Dictionary) -> bool:
		return int(r.get("unlock_chapter", 1)) > TimeManager.chapter)
	locked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unlock_chapter", 1)) < int(b.get("unlock_chapter", 1)))
	if not locked.is_empty():
		list.add_child(UIKit.label("— locked recipes —", 9, UIKit.COL_DIM))
	for r in locked:
		var count := int(r.get("count", 1))
		var ingredients: Array[String] = []
		for item_id: String in r.get("inputs", {}):
			ingredients.append("%d× %s" % [int(r["inputs"][item_id]), ContentDatabase.item_name(item_id)])
		var row := UIKit.item_row(String(r["output"]), "×%d  •  from %s  •  Chapter %d" % [
			count, " + ".join(ingredients), int(r.get("unlock_chapter", 1))], "", Callable())
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
	gold_lbl.text = "Gold: %d" % EconomyManager.gold
	_fill()
