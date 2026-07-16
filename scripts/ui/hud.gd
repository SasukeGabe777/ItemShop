class_name GameHUD
extends CanvasLayer
## Persistent top bar: day/period/chapter, gold, deadline progress, market
## events, and pending order count. Also hosts the pause menu.

var day_label: Label
var gold_label: Label
var deadline_label: Label
var market_label: Label
var orders_label: Label


func _ready() -> void:
	layer = 20
	var bar := UIKit.panel()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	day_label = UIKit.label("", 10)
	row.add_child(day_label)
	gold_label = UIKit.label("", 10, UIKit.COL_ACCENT)
	row.add_child(gold_label)
	deadline_label = UIKit.label("", 10)
	row.add_child(deadline_label)
	orders_label = UIKit.label("", 10, UIKit.COL_DIM)
	row.add_child(orders_label)
	row.add_child(UIKit.spacer(false))
	market_label = UIKit.label("", 9, UIKit.COL_DIM)
	row.add_child(market_label)
	row.add_child(UIKit.button("Menu", _open_pause))
	EconomyManager.gold_changed.connect(func(_g: int) -> void: refresh())
	TimeManager.period_advanced.connect(func(_d: int, _p: int) -> void: refresh())
	TimeManager.day_started.connect(func(_d: int) -> void: refresh())
	MarketManager.events_changed.connect(refresh)
	InventoryManager.orders_changed.connect(refresh)
	BridgeManager.gate_repaired.connect(func(_w: String) -> void: refresh())
	refresh()


func refresh() -> void:
	var chap := TimeManager.chapter
	var world := ContentDatabase.world_for_chapter(chap)
	var world_name := String(world.get("name", "The Null Archive"))
	day_label.text = "Day %d/%d  %s  |  Ch.%d %s" % [
		TimeManager.day, TimeManager.campaign_days(), TimeManager.period_name(), chap, world_name]
	if GameState.endless_mode:
		day_label.text = "Day %d  %s  |  Endless" % [TimeManager.day, TimeManager.period_name()]
	gold_label.text = "%dg" % EconomyManager.gold
	if GameState.endless_mode or chap > 7:
		deadline_label.text = "The Fade looms..." if chap == 8 and not BridgeManager.fade_defeated else ""
	else:
		var wid := String(world.get("id", ""))
		var shard := "SHARD OK" if BridgeManager.has_shard(wid) else "shard needed"
		deadline_label.text = "Due day %d: %dg + %s" % [
			TimeManager.chapter_deadline_day(), BridgeManager.repair_cost(wid), shard]
		deadline_label.add_theme_color_override("font_color",
			UIKit.COL_GOOD if BridgeManager.has_shard(wid) and EconomyManager.gold >= BridgeManager.repair_cost(wid) else UIKit.COL_TEXT)
	orders_label.text = "Orders: %d" % InventoryManager.orders.size()
	var events := MarketManager.active_event_names()
	market_label.text = "Market: " + (", ".join(events) if not events.is_empty() else "calm")


func _open_pause() -> void:
	var parts := UIKit.modal(self, GameState.game_title)
	var pause_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	get_tree().paused = true
	pause_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var close := func() -> void:
		get_tree().paused = false
		pause_layer.queue_free()
	for slot in range(1, 4):
		var summary := SaveManager.slot_summary(slot)
		var text := "Save to slot %d" % slot
		if not summary.is_empty():
			text += "  (day %d, %dg)" % [int(summary["day"]), int(summary["gold"])]
		vb.add_child(UIKit.button(text, func() -> void:
			SaveManager.save_to_slot(slot)
			close.call()))
	vb.add_child(UIKit.hsep())
	vb.add_child(UIKit.button("Orders & encyclopedia", func() -> void:
		close.call()
		_open_orders()))
	vb.add_child(UIKit.button("Music: %s" % ("muted" if AudioManager.muted else "on"), func() -> void:
		AudioManager.set_muted(not AudioManager.muted)
		close.call()))
	vb.add_child(UIKit.button("Quit to main menu", func() -> void:
		close.call()
		SceneRouter.go("main_menu")))
	vb.add_child(UIKit.button("Resume", close))


func _open_orders() -> void:
	var parts := UIKit.modal(self, "Active orders")
	var order_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	if InventoryManager.orders.is_empty():
		vb.add_child(UIKit.label("No active orders.", 10, UIKit.COL_DIM))
	for o: Dictionary in InventoryManager.orders:
		var cust := String(o["customer_id"])
		var cname := String(ContentDatabase.get_named_customer(cust).get("name", cust.trim_prefix("walkin_").capitalize()))
		var target_desc := ""
		match String(o["kind"]):
			"item": target_desc = ContentDatabase.item_name(String(o["target"]))
			"category": target_desc = "any %s" % o["target"]
			"tag": target_desc = "anything '%s'" % o["target"]
			"world": target_desc = "goods from %s" % String(ContentDatabase.get_world(String(o["target"])).get("name", o["target"]))
		var oid := int(o["id"])
		var row := HBoxContainer.new()
		var lbl := UIKit.label("%s wants %dx %s by day %d (%dg each)" % [cname, int(o["qty"]), target_desc, int(o["deadline_day"]), int(o["reward_each"])])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		row.add_child(UIKit.button("Deliver", func() -> void:
			if InventoryManager.try_fulfill_order(oid):
				order_layer.queue_free()
				_open_orders()))
		vb.add_child(row)
	vb.add_child(UIKit.hsep())
	vb.add_child(UIKit.label("Encyclopedia: %d items discovered | Merchant Lv.%d (%d/%d xp) | Perfect combo: %d" % [
		GameState.encyclopedia.size(), GameState.merchant_level, GameState.merchant_xp, GameState.xp_for_next_level(), EconomyManager.combo], 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Close", func() -> void: order_layer.queue_free()))
