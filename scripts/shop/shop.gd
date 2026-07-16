extends Node2D
## The item shop interior. Hero can walk around, stock display furniture, and
## open the shop for a one-period selling session with live customers.

var player: TownPlayer
var hud: GameHUD
var prompt: Label
var session_active: bool = false
var customers_remaining: Array[Dictionary] = []
var live_customers: Array[ShopCustomer] = []
var spawn_timer: float = 0.0
var busy: bool = false
var display_markers: Array[Node2D] = []
var browse_points: Array[Vector2] = []
var session_summary := {"sales": 0, "revenue": 0, "perfect": 0, "left": 0, "orders": 0}
var negotiating: ShopCustomer = null

const ENTRANCE := Vector2(320, 400)


func _ready() -> void:
	AudioManager.play_track("item_shop")
	_build_room()
	_build_furniture()
	player = TownPlayer.new()
	player.position = Vector2(320, 300)
	add_child(player)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	player.add_child(cam)
	hud = GameHUD.new()
	add_child(hud)
	prompt = UIKit.label("", 10, UIKit.COL_ACCENT)
	prompt.z_index = 60
	add_child(prompt)


func _build_room() -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.polygon = PackedVector2Array([Vector2(140, 120), Vector2(500, 120), Vector2(500, 420), Vector2(140, 420)])
	floor_poly.color = Color("#5a4a3a")
	floor_poly.z_index = -10
	add_child(floor_poly)
	# walls
	for wall_def: Array in [
		[Vector2(320, 112), Vector2(376, 16)],
		[Vector2(132, 270), Vector2(16, 316)],
		[Vector2(508, 270), Vector2(16, 316)],
		[Vector2(214, 428), Vector2(164, 16)],
		[Vector2(426, 428), Vector2(164, 16)],
	]:
		var body := StaticBody2D.new()
		body.position = wall_def[0]
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall_def[1]
		shape.shape = rect
		body.add_child(shape)
		var poly := Polygon2D.new()
		var h: Vector2 = wall_def[1] / 2.0
		poly.polygon = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
		poly.color = Color("#3a3028")
		body.add_child(poly)
		add_child(body)
	var door_lbl := UIKit.label("~ door ~", 9, UIKit.COL_DIM)
	door_lbl.position = Vector2(300, 424)
	add_child(door_lbl)


func _furniture_kind(slot: int) -> String:
	var shop_cfg: Dictionary = ContentDatabase.bal("shop", {})
	var window_slots: Array = shop_cfg.get("window_slots", [0, 1, 2, 3])
	if slot in window_slots:
		return "counter"
	return ["shelf", "pedestal", "case"][slot % 3]


func _build_furniture() -> void:
	display_markers.clear()
	browse_points.clear()
	var n := InventoryManager.display_slot_count()
	for i in range(n):
		var col := i % 4
		var row_i := i / 4
		var pos := Vector2(190.0 + col * 88.0, 170.0 + row_i * 76.0)
		var marker := Node2D.new()
		marker.position = pos
		var kind := _furniture_kind(i)
		var spr := Sprite2D.new()
		spr.texture = PlaceholderFactory.furniture_texture(kind, 34, 20)
		marker.add_child(spr)
		var window_slots: Array = ContentDatabase.bal("shop", {}).get("window_slots", [0, 1, 2, 3])
		if i in window_slots:
			var tag := UIKit.label("window", 7, UIKit.COL_DIM)
			tag.position = Vector2(-14, -26)
			marker.add_child(tag)
		var item_spr := Sprite2D.new()
		item_spr.name = "ItemSprite"
		item_spr.position = Vector2(0, -12)
		marker.add_child(item_spr)
		var ic := InteractionComponent.new()
		ic.prompt = "Display slot %d" % (i + 1)
		ic.action_id = "slot_%d" % i
		ic.position = pos
		ic.add_to_group("interactables")
		add_child(ic)
		add_child(marker)
		display_markers.append(marker)
		browse_points.append(pos)
	var open_ic := InteractionComponent.new()
	open_ic.prompt = "Open the shop (1 period)"
	open_ic.action_id = "open_shop"
	open_ic.position = Vector2(320, 140)
	open_ic.add_to_group("interactables")
	add_child(open_ic)
	var exit_ic := InteractionComponent.new()
	exit_ic.prompt = "Leave to the Crossroads"
	exit_ic.action_id = "exit"
	exit_ic.position = Vector2(320, 410)
	exit_ic.add_to_group("interactables")
	add_child(exit_ic)
	var storage_ic := InteractionComponent.new()
	storage_ic.prompt = "Storage & sorting"
	storage_ic.action_id = "storage"
	storage_ic.position = Vector2(160, 140)
	storage_ic.add_to_group("interactables")
	add_child(storage_ic)
	if GameState.shop_level < 3:
		var expand_ic := InteractionComponent.new()
		expand_ic.prompt = "Expand shop"
		expand_ic.action_id = "expand"
		expand_ic.position = Vector2(480, 140)
		expand_ic.add_to_group("interactables")
		add_child(expand_ic)
	_refresh_display_sprites()
	InventoryManager.display_changed.connect(_refresh_display_sprites)


func _refresh_display_sprites() -> void:
	for i in range(display_markers.size()):
		if i >= InventoryManager.display.size():
			break
		var spr := display_markers[i].get_node("ItemSprite") as Sprite2D
		var id := String(InventoryManager.display[i])
		spr.texture = ContentDatabase.item_texture(id) if id != "" else null


func _process(delta: float) -> void:
	if busy or player == null:
		prompt.visible = false
		return
	if session_active:
		_run_session(delta)
	var ic := player.nearest_interactable()
	prompt.visible = ic != null
	if ic != null:
		prompt.text = "[E] " + ic.prompt
		prompt.position = player.position + Vector2(-40, -34)
	if Input.is_action_just_pressed("interact") and ic != null:
		_activate(ic.action_id)


func _activate(action: String) -> void:
	if action.begins_with("slot_"):
		_open_slot_picker(int(action.trim_prefix("slot_")))
		return
	match action:
		"open_shop":
			if session_active:
				return
			if InventoryManager.displayed_ids().is_empty():
				_toast("Stock the display furniture first!")
				return
			UIKit.confirm_time_cost(self, "Opening the shop", TimeManager.activity_cost("open_shop"), _begin_session)
		"storage":
			_open_storage()
		"expand":
			_open_expand()
		"exit":
			if session_active:
				_toast("Close up first — customers are browsing!")
				return
			SceneRouter.go("town")


func _toast(text: String) -> void:
	var lbl := UIKit.label(text, 10, UIKit.COL_BAD)
	lbl.position = player.position + Vector2(-60, -48)
	lbl.z_index = 70
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


# ---------------- stocking ----------------

func _open_slot_picker(slot: int) -> void:
	busy = true
	player.frozen = true
	var parts := UIKit.modal(self, "Display slot %d (%s)" % [slot + 1, _furniture_kind(slot)])
	var pick_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var current := String(InventoryManager.display[slot]) if slot < InventoryManager.display.size() else ""
	if current != "":
		vb.add_child(UIKit.label("Currently: %s" % ContentDatabase.item_name(current)))
		vb.add_child(UIKit.button("Take back to storage", func() -> void:
			InventoryManager.take_display(slot)
			_close_modal(pick_layer)))
	var list_parts := UIKit.scroll_list(Vector2(340, 200))
	vb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	for id in InventoryManager.sorted_ids("price"):
		var it := ContentDatabase.get_item(id)
		if it.get("sellable", true) == false:
			continue
		var appeal: Dictionary = it.get("appeal", {})
		var appeal_bits: Array[String] = []
		for k: String in appeal:
			appeal_bits.append("%s+%d" % [k, int(appeal[k])])
		list.add_child(UIKit.item_row(id, "x%d ~%dg %s" % [InventoryManager.count(id), MarketManager.market_value(id), " ".join(appeal_bits)],
			"Place", func() -> void:
				InventoryManager.place_display(slot, id)
				_close_modal(pick_layer)))
	vb.add_child(UIKit.button("Cancel", func() -> void: _close_modal(pick_layer)))


func _close_modal(modal_layer: CanvasLayer) -> void:
	modal_layer.queue_free()
	busy = false
	player.frozen = false


func _open_storage() -> void:
	busy = true
	player.frozen = true
	var parts := UIKit.modal(self, "Storage — %d items" % InventoryManager.total_items())
	var storage_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	vb.add_child(sort_row)
	var list_parts := UIKit.scroll_list(Vector2(360, 210))
	vb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	var fill := func(mode: String) -> void:
		for child in list.get_children():
			child.queue_free()
		for id in InventoryManager.sorted_ids(mode):
			var it := ContentDatabase.get_item(id)
			list.add_child(UIKit.item_row(id, "x%d  ~%dg  [%s/%s]" % [InventoryManager.count(id), MarketManager.market_value(id),
				String(it.get("world", "?")), String(it.get("category", "?"))], "", Callable()))
	for mode in ["name", "price", "category", "world"]:
		sort_row.add_child(UIKit.button("Sort: %s" % mode, func() -> void: fill.call(mode)))
	fill.call("name")
	var appeal := InventoryManager.shop_appeal()
	vb.add_child(UIKit.label("Shop appeal — cozy %d | intense %d | retro %d | modern %d (dominant: %s)" % [
		int(appeal["cozy"]), int(appeal["intense"]), int(appeal["retro"]), int(appeal["modern"]), InventoryManager.dominant_appeal()], 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Close", func() -> void: _close_modal(storage_layer)))


func _open_expand() -> void:
	var costs: Array = ContentDatabase.bal("shop", {}).get("expansion_costs", [15000, 80000])
	var idx := GameState.shop_level - 1
	if idx >= costs.size():
		return
	var cost := int(costs[idx])
	busy = true
	player.frozen = true
	var parts := UIKit.modal(self, "Expand the shop")
	var expand_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	vb.add_child(UIKit.label("Level %d -> %d: more display slots. Cost: %dg" % [GameState.shop_level, GameState.shop_level + 1, cost]))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.button("Pay", func() -> void:
		if EconomyManager.spend_gold(cost):
			GameState.shop_level += 1
			InventoryManager.on_shop_expanded()
			_close_modal(expand_layer)
			SceneRouter.go("shop")))
	row.add_child(UIKit.button("Cancel", func() -> void: _close_modal(expand_layer)))
	vb.add_child(row)


# ---------------- selling session ----------------

func _begin_session() -> void:
	session_active = true
	session_summary = {"sales": 0, "revenue": 0, "perfect": 0, "left": 0, "orders": 0}
	customers_remaining.clear()
	customers_remaining.append_array(CustomerGen.generate_session_customers())
	spawn_timer = 0.5
	AudioManager.play_track("item_shop")


func _run_session(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0 and not customers_remaining.is_empty() and live_customers.size() < 4:
		spawn_timer = randf_range(1.2, 2.6)
		_spawn_customer(customers_remaining.pop_front())
	if customers_remaining.is_empty() and live_customers.is_empty() and negotiating == null:
		_end_session()


func _spawn_customer(cust: Dictionary) -> void:
	var c := ShopCustomer.new()
	add_child(c)
	c.position = ENTRANCE
	c.setup(cust, browse_points, ENTRANCE)
	c.negotiate_requested.connect(_on_negotiate_requested)
	c.order_requested.connect(_on_order_requested)
	c.left.connect(func(me: ShopCustomer) -> void: live_customers.erase(me))
	live_customers.append(c)
	if bool(cust.get("named", false)) and String(cust.get("line", "")) != "":
		_speech(c, String(cust["line"]))


func _speech(over: Node2D, text: String) -> void:
	var lbl := UIKit.label(text, 8)
	lbl.custom_minimum_size = Vector2(0, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size.x = minf(180, text.length() * 4.5)
	lbl.position = Vector2(-50, -52)
	lbl.z_index = 65
	over.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _on_order_requested(cust: Dictionary) -> void:
	var order := CustomerGen.maybe_make_order(cust)
	if not order.is_empty():
		session_summary["orders"] = int(session_summary["orders"]) + 1
		hud.refresh()


func _on_negotiate_requested(cust: Dictionary, item_id: String) -> void:
	negotiating = null
	for c in live_customers:
		if c.data == cust:
			negotiating = c
			break
	var panel := NegotiationPanel.new()
	panel.setup(cust, item_id)
	panel.finished.connect(_on_negotiation_finished)
	busy = true
	player.frozen = true
	add_child(panel)


func _on_negotiation_finished(outcome: Dictionary) -> void:
	busy = false
	player.frozen = false
	match String(outcome.get("result", "")):
		Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT:
			session_summary["sales"] = int(session_summary["sales"]) + 1
			session_summary["revenue"] = int(session_summary["revenue"]) + int(outcome.get("price", 0))
			if bool(outcome.get("perfect", false)):
				session_summary["perfect"] = int(session_summary["perfect"]) + 1
		_:
			session_summary["left"] = int(session_summary["left"]) + 1
	if negotiating != null and is_instance_valid(negotiating):
		if bool(outcome.get("result", "") in [Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT]):
			_speech(negotiating, "Thanks!")
		negotiating.resume_after_negotiation()
	negotiating = null
	hud.refresh()


func _end_session() -> void:
	session_active = false
	var events := TimeManager.advance(TimeManager.activity_cost("open_shop"))
	var parts := UIKit.modal(self, "Shop session complete")
	var end_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	vb.add_child(UIKit.label("Sales: %d   Revenue: %dg" % [int(session_summary["sales"]), int(session_summary["revenue"])]))
	vb.add_child(UIKit.label("Perfect deals: %d   Walked away: %d   New orders: %d" % [
		int(session_summary["perfect"]), int(session_summary["left"]), int(session_summary["orders"])]))
	vb.add_child(UIKit.label("Merchant Lv.%d  combo x%d" % [GameState.merchant_level, EconomyManager.combo], 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Continue", func() -> void:
		end_layer.queue_free()
		hud.refresh()
		if "deadline_failed" in events:
			SceneRouter.go("story", {"failure": true})
		elif StoryEventManager.has_pending():
			SceneRouter.go("story", {"return_to": "shop"})))
	busy = false
