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
var furniture_nodes: Array[DisplayFurniture] = []
var browse_points: Array[Vector2] = []
var edit_mode: bool = false
var carrying: DisplayFurniture = null
var carry_origin := Vector2.ZERO
var edit_hint: Label = null
var session_summary := {"sales": 0, "revenue": 0, "perfect": 0, "left": 0, "orders": 0}
var negotiating: ShopCustomer = null
var nego_queue: Array = []  # [{customer: Dictionary, item: String, node: ShopCustomer}]

const ENTRANCE := Vector2(320, 400)
## Area furniture may occupy: inside the walls, clear of the door strip.
const FURNITURE_AREA := Rect2(60, 132, 520, 258)
const EDIT_GRID := 8.0
## Painted room art: its wooden-floor band is mapped onto y 120..420 so all
## gameplay coordinates keep working; the room is wider than the old one.
const ROOM_BG := "res://assets/shared/ui/backgrounds/shopbackgroundupdated.png"
const BG_FLOOR_TOP_FRAC := 0.4
const BG_FLOOR_BOTTOM_FRAC := 0.825
## Walking past the entrance gap at the bottom leaves to the Crossroads
## automatically (like dungeon room doors) — no interact prompt needed.
const EXIT_Y := 424.0


func _ready() -> void:
	add_to_group("shop_runtime")
	# draw order follows feet position — rebuilt furniture would otherwise
	# land after the player in the tree and draw on top of them
	y_sort_enabled = true
	AudioManager.play_track("item_shop")
	_build_room()
	_build_furniture()
	player = TownPlayer.new()
	player.position = Vector2(320, 300)
	add_child(player)
	player.add_child(ZoomCamera.new())
	PatchFollower.attach(self, player)
	hud = GameHUD.new()
	add_child(hud)
	prompt = UIKit.label("", 10, UIKit.COL_ACCENT)
	prompt.z_index = 60
	add_child(prompt)
	_build_corner_buttons()
	call_deferred("_show_first_shop_guide")


func _build_corner_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.anchor_left = 0.5
	box.offset_left = 0
	box.offset_right = -6
	box.offset_top = -32
	box.offset_bottom = -6
	box.alignment = BoxContainer.ALIGNMENT_END
	box.theme = UIKit.light_theme()
	layer.add_child(box)
	box.add_child(UIKit.button("Buy furniture", _open_furniture_catalog, 9))
	box.add_child(UIKit.button("Decorate", _open_decor_catalog, 9))
	box.add_child(UIKit.button("Rearrange furniture", _on_rearrange_pressed, 9))


func _on_rearrange_pressed() -> void:
	if edit_mode:
		_exit_edit_mode()
		return
	if session_active:
		_toast("Not while customers are browsing!")
		return
	if busy:
		return
	_enter_edit_mode()


func _show_first_shop_guide() -> void:
	const TUTORIAL_ID := "first_shop_vertical_slice"
	if TUTORIAL_ID in GameState.tutorials_seen or not GameState.campaign_active:
		return
	# let the scene-change curtain lift so the shop is visible behind the guide
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	busy = true
	player.frozen = true
	var parts := UIKit.modal(self, "Your first shop session")
	var guide_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	vb.add_child(UIKit.label("1. Walk to any item stand until [E] Display slot appears."))
	vb.add_child(UIKit.label("2. Press E and choose a Potion, Ether, or Rupee."))
	vb.add_child(UIKit.label("3. To move a stand, use Rearrange furniture at the lower-right."))
	vb.add_child(UIKit.label("4. Walk to the counter at the top and press E to open."))
	vb.add_child(UIKit.label("The first customer will inspect a stocked stand and ask you to negotiate.", 9, UIKit.COL_GOOD))
	vb.add_child(UIKit.button("Begin stocking", func() -> void:
		GameState.tutorials_seen.append(TUTORIAL_ID)
		busy = false
		player.frozen = false
		guide_layer.queue_free()))


func _build_room() -> void:
	if ResourceLoader.exists(ROOM_BG):
		var bg := Sprite2D.new()
		bg.texture = load(ROOM_BG)
		var tex_h := float(bg.texture.get_height())
		var s := 300.0 / ((BG_FLOOR_BOTTOM_FRAC - BG_FLOOR_TOP_FRAC) * tex_h)
		bg.scale = Vector2(s, s)
		# floor band top lands on y=120; horizontally centered on the room
		var top := 120.0 - BG_FLOOR_TOP_FRAC * tex_h * s
		bg.position = Vector2(320.0, top + tex_h * s / 2.0)
		bg.z_index = -10
		add_child(bg)
	else:
		Scenery.tiled_floor(self, Rect2(140, 120, 360, 300), "floor_cobble", Color("#5a4a3a"), -10, Color(0.92, 0.82, 0.72))
	# invisible collision walls hugging the art's floor edges; the bottom
	# pair leaves a gap for the entrance stairs
	for wall_def: Array in [
		[Vector2(320, 112), Vector2(620, 16)],
		[Vector2(42, 270), Vector2(16, 316)],
		[Vector2(598, 270), Vector2(16, 316)],
		[Vector2(152, 428), Vector2(204, 16)],
		[Vector2(488, 428), Vector2(204, 16)],
	]:
		var body := StaticBody2D.new()
		body.position = wall_def[0]
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall_def[1]
		shape.shape = rect
		body.add_child(shape)
		add_child(body)


func _build_furniture() -> void:
	furniture_nodes.clear()
	browse_points.clear()
	ShopFurnitureManager.ensure_layout()
	var window := ShopFurnitureManager.window_slots()
	var slot_base := 0
	for inst: Dictionary in ShopFurnitureManager.layout:
		var piece := DisplayFurniture.new()
		add_child(piece)
		piece.setup(inst, ShopFurnitureManager.type_def(inst), slot_base, window)
		furniture_nodes.append(piece)
		slot_base += piece.slot_count
	_rebuild_browse_points()
	var open_ic := InteractionComponent.new()
	open_ic.prompt = "Open the shop (1 period)"
	open_ic.action_id = "open_shop"
	open_ic.position = Vector2(320, 140)
	open_ic.add_to_group("interactables")
	add_child(open_ic)
	var storage_ic := InteractionComponent.new()
	storage_ic.prompt = "Storage & sorting"
	storage_ic.action_id = "storage"
	storage_ic.position = Vector2(160, 140)
	storage_ic.add_to_group("interactables")
	add_child(storage_ic)
	var storage_chest := Sprite2D.new()
	var chest_tex := Scenery.texture_or_null("chest")
	storage_chest.texture = chest_tex if chest_tex != null else PlaceholderFactory.furniture_texture("chest", 28, 20)
	storage_chest.position = Vector2(160, 140)
	add_child(storage_chest)
	if GameState.shop_level < 5:
		var expand_ic := InteractionComponent.new()
		expand_ic.prompt = "Expand shop"
		expand_ic.action_id = "expand"
		expand_ic.position = Vector2(480, 140)
		expand_ic.add_to_group("interactables")
		add_child(expand_ic)
		var expand_spr := Sprite2D.new()
		var ladder_tex := Scenery.texture_or_null("ladder")
		expand_spr.texture = ladder_tex if ladder_tex != null else PlaceholderFactory.furniture_texture("shelf", 24, 20)
		if expand_spr.texture != null and expand_spr.texture.get_height() > 56:
			var k := 56.0 / float(expand_spr.texture.get_height())
			expand_spr.scale = Vector2(k, k)
		expand_spr.position = Vector2(480, 140)
		add_child(expand_spr)
	var edit_ic := InteractionComponent.new()
	edit_ic.prompt = "Rearrange furniture"
	edit_ic.action_id = "rearrange"
	edit_ic.position = Vector2(480, 340)
	edit_ic.add_to_group("interactables")
	add_child(edit_ic)
	_refresh_display_sprites()
	InventoryManager.display_changed.connect(_refresh_display_sprites)


func dev_spawn_furniture(type_id: String, at: Vector2) -> DisplayFurniture:
	var inst := ShopFurnitureManager.add_instance(type_id, at)
	if inst.is_empty():
		return null
	var slot_base := ShopFurnitureManager.total_slot_count() - ShopFurnitureManager.slots_per_instance(inst)
	InventoryManager.resize_display_slots(ShopFurnitureManager.total_slot_count())
	var piece := DisplayFurniture.new()
	add_child(piece)
	piece.setup(inst, ShopFurnitureManager.type_def(inst), slot_base, ShopFurnitureManager.window_slots())
	furniture_nodes.append(piece)
	_rebuild_browse_points()
	return piece


func dev_remove_furniture(uid: int) -> bool:
	var slot_range := ShopFurnitureManager.slot_range_for_uid(uid)
	if slot_range.x < 0:
		return false
	InventoryManager.remove_display_range(slot_range.x, slot_range.y)
	if not ShopFurnitureManager.remove_instance(uid):
		return false
	dev_rebuild_furniture()
	return true


func dev_rebuild_furniture() -> void:
	for piece in furniture_nodes:
		if is_instance_valid(piece):
			piece.queue_free()
	furniture_nodes.clear()
	var slot_base := 0
	for inst: Dictionary in ShopFurnitureManager.layout:
		var piece := DisplayFurniture.new()
		add_child(piece)
		piece.setup(inst, ShopFurnitureManager.type_def(inst), slot_base, ShopFurnitureManager.window_slots())
		furniture_nodes.append(piece)
		slot_base += piece.slot_count
	InventoryManager.resize_display_slots(slot_base)
	_rebuild_browse_points()


func dev_summon_customer(customer_id: String, at: Vector2 = ENTRANCE) -> ShopCustomer:
	var src := ContentDatabase.get_named_customer(customer_id)
	if src.is_empty():
		return null
	var cust := CustomerGen.runtime_named(src)
	var c := ShopCustomer.new()
	add_child(c)
	c.position = at
	c.setup(cust, browse_points if not browse_points.is_empty() else [at], ENTRANCE)
	c.add_to_group("dev_editable")
	c.set_meta("dev_object_type", "customer")
	c.set_meta("dev_content_id", customer_id)
	c.negotiate_requested.connect(_on_negotiate_requested)
	c.order_requested.connect(_on_order_requested)
	c.left.connect(func(me: ShopCustomer) -> void: live_customers.erase(me))
	live_customers.append(c)
	return c


func dev_open_shop() -> void:
	if not session_active:
		_begin_session()


func dev_close_shop() -> void:
	customers_remaining.clear()
	nego_queue.clear()
	negotiating = null
	for c in live_customers.duplicate():
		if is_instance_valid(c):
			c.queue_free()
	live_customers.clear()
	session_active = false
	busy = false
	if player != null:
		player.frozen = false


func dev_toggle_edit_mode() -> void:
	if edit_mode:
		_exit_edit_mode()
	else:
		_enter_edit_mode()


func dev_set_display_item(slot: int, item_id: String) -> bool:
	if slot < 0 or slot >= InventoryManager.display.size() or ContentDatabase.get_item(item_id).is_empty():
		return false
	if InventoryManager.count(item_id) <= 0:
		InventoryManager.add_item(item_id)
	return InventoryManager.place_display(slot, item_id)


func _rebuild_browse_points() -> void:
	browse_points.clear()
	for piece in furniture_nodes:
		browse_points.append_array(piece.browse_global_positions())


func _refresh_display_sprites() -> void:
	for piece in furniture_nodes:
		piece.refresh_items()


func _process(delta: float) -> void:
	if edit_mode:
		_process_edit()
		return
	if busy or player == null:
		prompt.visible = false
		return
	if session_active:
		_run_session(delta)
	if player.position.y > EXIT_Y:
		if session_active:
			player.position.y = EXIT_Y
			if not get_meta("exit_toasted", false):
				set_meta("exit_toasted", true)
				_toast("Close up first — customers are browsing!")
				get_tree().create_timer(2.0).timeout.connect(func() -> void: set_meta("exit_toasted", false))
		else:
			busy = true
			SceneRouter.go("town")
			return
	var ic := player.nearest_interactable()
	prompt.visible = ic != null
	if ic != null:
		prompt.text = "[%s] %s" % [UIKit.interact_key(), ic.prompt]
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
		"rearrange":
			if session_active:
				_toast("Not while customers are browsing!")
				return
			_enter_edit_mode()


func _toast(text: String) -> void:
	AudioManager.play_sfx("error", -4.0)
	var lbl := UIKit.label(text, 10, UIKit.COL_BAD)
	lbl.position = player.position + Vector2(-60, -48)
	lbl.z_index = 70
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


# ---------------- shop edit mode ----------------

func _enter_edit_mode() -> void:
	edit_mode = true
	player.frozen = true
	prompt.visible = false
	for piece in furniture_nodes:
		if piece.is_moveable():
			piece.set_edit_highlight(true)
	edit_hint = UIKit.label("EDIT MODE — click furniture to pick up, click to place. Holding: [Q] store  [X] sell 50%. Right-click cancels, [E] done", 9, UIKit.COL_ACCENT)
	edit_hint.position = Vector2(150, 124)
	edit_hint.z_index = 70
	add_child(edit_hint)


func _exit_edit_mode() -> void:
	if carrying != null:
		_cancel_carry()
	edit_mode = false
	player.frozen = false
	for piece in furniture_nodes:
		piece.clear_ghost()
	if edit_hint != null:
		edit_hint.queue_free()
		edit_hint = null


func _process_edit() -> void:
	if Input.is_action_just_pressed("interact"):
		_exit_edit_mode()
		return
	if carrying != null:
		var pos := (get_global_mouse_position() / EDIT_GRID).round() * EDIT_GRID
		carrying.position = pos
		carrying.set_ghost(ShopFurnitureManager.placement_valid(carrying.uid, pos, FURNITURE_AREA))


func _unhandled_input(event: InputEvent) -> void:
	if not edit_mode:
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_exit_edit_mode()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and carrying != null:
		match (event as InputEventKey).keycode:
			KEY_Q:
				_put_away_carried(false)
				get_viewport().set_input_as_handled()
				return
			KEY_X:
				_put_away_carried(true)
				get_viewport().set_input_as_handled()
				return
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and carrying != null:
		_cancel_carry()
		get_viewport().set_input_as_handled()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	var mouse := get_global_mouse_position()
	if carrying == null:
		for piece in furniture_nodes:
			if piece.is_moveable() and piece.footprint().grow(4.0).has_point(mouse):
				carrying = piece
				carry_origin = piece.position
				break
		return
	var pos := (mouse / EDIT_GRID).round() * EDIT_GRID
	if ShopFurnitureManager.placement_valid(carrying.uid, pos, FURNITURE_AREA):
		carrying.position = pos
		ShopFurnitureManager.move_instance(carrying.uid, pos)
		carrying.set_edit_highlight(true)
		carrying = null
		_rebuild_browse_points()
	else:
		_toast("Can't place it there.")


func _cancel_carry() -> void:
	carrying.position = carry_origin
	carrying.set_edit_highlight(true)
	carrying = null


## Q/X while holding a piece in edit mode: put it in furniture storage, or
## sell it for half its catalog price. Items on its slots go back to storage.
func _put_away_carried(sell: bool) -> void:
	if ShopFurnitureManager.layout.size() <= 1:
		_toast("A shop needs at least one stand!")
		return
	var uid := carrying.uid
	var type_id := carrying.type_id
	var type_name := String(carrying.type_def.get("name", type_id))
	carrying = null
	if sell:
		var prices: Dictionary = ContentDatabase.bal("furniture_prices", {})
		var value := int(prices.get(type_id, prices.get("default", 400))) / 2
		EconomyManager.add_gold(value)
		_notice("Sold %s for %dg" % [type_name, value])
	else:
		ShopFurnitureManager.stored.append(type_id)
		_notice("%s put into storage (place it again from the catalog)" % type_name)
	dev_remove_furniture(uid)
	for piece in furniture_nodes:
		if piece.is_moveable():
			piece.set_edit_highlight(true)
	hud.refresh()


func _notice(text: String) -> void:
	AudioManager.play_sfx("menu_close", -6.0)
	var lbl := UIKit.label(text, 10, UIKit.COL_GOOD)
	lbl.position = player.position + Vector2(-70, -48)
	lbl.z_index = 70
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


# ---------------- stocking ----------------

func _slot_info(slot: int) -> Dictionary:
	for s: Dictionary in ShopFurnitureManager.get_all_available_display_slots():
		if int(s.get("index", -1)) == slot:
			return s
	return {}


func _open_slot_picker(slot: int) -> void:
	busy = true
	player.frozen = true
	var info := _slot_info(slot)
	var type_name := String(ContentDatabase.get_furniture(String(info.get("type", ""))).get("name", "stand"))
	var allowed: Array = info.get("allowed_categories", [])
	var parts := UIKit.modal(self, "Display slot %d (%s)" % [slot + 1, type_name])
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
		if not allowed.is_empty() and not (String(it.get("category", "")) in allowed):
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


## First grid position inside FURNITURE_AREA where this piece fits without
## overlapping existing furniture; Vector2.INF when the floor is full.
func _find_free_spot(type_id: String) -> Vector2:
	var def := ContentDatabase.get_furniture(type_id)
	var size_arr: Array = def.get("size", [40, 24])
	var size := Vector2(float(size_arr[0]), float(size_arr[1]))
	var y := FURNITURE_AREA.position.y + size.y / 2.0 + 4.0
	while y <= FURNITURE_AREA.end.y - size.y / 2.0 - 4.0:
		var x := FURNITURE_AREA.position.x + size.x / 2.0 + 4.0
		while x <= FURNITURE_AREA.end.x - size.x / 2.0 - 4.0:
			var r := Rect2(Vector2(x, y) - size / 2.0, size)
			var ok := true
			for inst: Dictionary in ShopFurnitureManager.layout:
				if r.grow(2.0).intersects(ShopFurnitureManager.instance_rect(inst)):
					ok = false
					break
			if ok:
				return Vector2(x, y)
			x += EDIT_GRID
		y += EDIT_GRID
	return Vector2.INF


func _open_furniture_catalog() -> void:
	if session_active:
		_toast("Not while customers are browsing!")
		return
	if busy or edit_mode:
		return
	busy = true
	player.frozen = true
	var prices: Dictionary = ContentDatabase.bal("furniture_prices", {})
	var parts := UIKit.modal(self, "Furniture catalog — %dg" % EconomyManager.gold)
	var cat_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var list_parts := UIKit.scroll_list(Vector2(400, 220))
	vb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	var cap := _furniture_cap()
	var at_cap := ShopFurnitureManager.stand_count() >= cap
	if at_cap:
		vb.add_child(UIKit.label("SHOP FULL — %d of %d stands placed. Expand the shop, or store/sell furniture in Rearrange mode." % [
			ShopFurnitureManager.stand_count(), cap], 10, UIKit.COL_BAD))
	# stored furniture goes back on the floor for free
	for i in ShopFurnitureManager.stored.size():
		var stored_idx := i
		var stored_id := String(ShopFurnitureManager.stored[i])
		var sdef := ContentDatabase.get_furniture(stored_id)
		if sdef.is_empty() or bool(sdef.get("decor", false)):
			continue
		var srow := HBoxContainer.new()
		var slbl := UIKit.label("In storage: %s" % String(sdef.get("name", stored_id)), 10, UIKit.COL_ACCENT)
		slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(slbl)
		var place_btn := UIKit.button("Place", func() -> void:
			if ShopFurnitureManager.stand_count() >= cap:
				_toast("The shop only fits %d stands — expand it first!" % cap)
				return
			var spot := _find_free_spot(stored_id)
			if spot == Vector2.INF:
				_toast("No floor space left — rearrange first.")
				return
			ShopFurnitureManager.stored.remove_at(stored_idx)
			dev_spawn_furniture(stored_id, spot)
			_close_modal(cat_layer)
			_open_furniture_catalog())
		place_btn.disabled = at_cap
		srow.add_child(place_btn)
		vb.add_child(srow)
	var ids: Array = ContentDatabase.furniture.keys().filter(func(fid: String) -> bool:
		return not bool(ContentDatabase.get_furniture(fid).get("decor", false)))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ua := int(ContentDatabase.get_furniture(a).get("unlock_level", 1))
		var ub := int(ContentDatabase.get_furniture(b).get("unlock_level", 1))
		if ua != ub:
			return ua < ub
		return int(prices.get(a, prices.get("default", 400))) < int(prices.get(b, prices.get("default", 400))))
	for id: String in ids:
		var fid := id
		var def := ContentDatabase.get_furniture(fid)
		var unlock := int(def.get("unlock_level", 1))
		var price := int(prices.get(fid, prices.get("default", 400)))
		var slots := maxi(1, (def.get("display_slots", [[0, -12]]) as Array).size())
		var row := HBoxContainer.new()
		var lbl := UIKit.label("%s — %d slot%s — %dg" % [String(def.get("name", fid)), slots, "s" if slots > 1 else "", price], 10)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		if unlock > GameState.shop_level:
			lbl.add_theme_color_override("font_color", UIKit.COL_DIM)
			row.add_child(UIKit.label("Shop Lv.%d" % unlock, 9, UIKit.COL_DIM))
		else:
			var buy_btn := UIKit.button("Buy", func() -> void:
				if ShopFurnitureManager.stand_count() >= cap:
					_toast("The shop only fits %d stands — expand it first!" % cap)
					return
				if EconomyManager.gold < price:
					_toast("Not enough gold!")
					return
				var spot := _find_free_spot(fid)
				if spot == Vector2.INF:
					_toast("No floor space left — rearrange first.")
					return
				EconomyManager.spend_gold(price)
				dev_spawn_furniture(fid, spot)
				hud.refresh()
				_close_modal(cat_layer)
				_open_furniture_catalog())
			buy_btn.disabled = at_cap
			row.add_child(buy_btn)
		list.add_child(row)
	var cap_line := UIKit.label("Stands: %d of %d (shop Lv.%d) — expanding the shop raises the cap and unlocks new pieces. Decor is separate." % [
		ShopFurnitureManager.stand_count(), cap, GameState.shop_level], 9, UIKit.COL_BAD if at_cap else UIKit.COL_DIM)
	vb.add_child(cap_line)
	vb.add_child(UIKit.label("New pieces appear on a free spot — use Rearrange furniture to place them.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Close", func() -> void: _close_modal(cat_layer)))


## Decor catalog: appeal-only pieces with no display slots. They don't count
## against the stand cap — only floor space limits them.
func _open_decor_catalog() -> void:
	if session_active:
		_toast("Not while customers are browsing!")
		return
	if busy or edit_mode:
		return
	busy = true
	player.frozen = true
	var prices: Dictionary = ContentDatabase.bal("furniture_prices", {})
	var parts := UIKit.modal(self, "Decorate the shop — %dg" % EconomyManager.gold)
	var decor_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var appeal := InventoryManager.shop_appeal()
	vb.add_child(UIKit.label("Shop appeal — cozy %d | intense %d | retro %d | modern %d (dominant: %s)" % [
		int(appeal["cozy"]), int(appeal["intense"]), int(appeal["retro"]), int(appeal["modern"]),
		InventoryManager.dominant_appeal()], 9, UIKit.COL_DIM))
	# stored decor goes back on the floor for free
	for i in ShopFurnitureManager.stored.size():
		var stored_idx := i
		var stored_id := String(ShopFurnitureManager.stored[i])
		var sdef := ContentDatabase.get_furniture(stored_id)
		if sdef.is_empty() or not bool(sdef.get("decor", false)):
			continue
		var srow := HBoxContainer.new()
		var slbl := UIKit.label("In storage: %s" % String(sdef.get("name", stored_id)), 10, UIKit.COL_ACCENT)
		slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(slbl)
		srow.add_child(UIKit.button("Place", func() -> void:
			var spot := _find_free_spot(stored_id)
			if spot == Vector2.INF:
				_toast("No floor space left — rearrange first.")
				return
			ShopFurnitureManager.stored.remove_at(stored_idx)
			dev_spawn_furniture(stored_id, spot)
			_close_modal(decor_layer)
			_open_decor_catalog()))
		vb.add_child(srow)
	var list_parts := UIKit.scroll_list(Vector2(430, 220))
	vb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	var ids: Array = ContentDatabase.furniture.keys().filter(func(fid: String) -> bool:
		return bool(ContentDatabase.get_furniture(fid).get("decor", false)))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(prices.get(a, 400)) < int(prices.get(b, 400)))
	for id: String in ids:
		var fid := id
		var def := ContentDatabase.get_furniture(fid)
		var price := int(prices.get(fid, 400))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		var spr := String(def.get("sprite", ""))
		icon.texture = load(spr) if spr != "" and ResourceLoader.exists(spr) else null
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var lbl := UIKit.label(String(def.get("name", fid)), 10)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		row.add_child(lbl)
		var mods: Dictionary = def.get("appeal_modifiers", {})
		var bits: Array[String] = []
		for k: String in mods:
			bits.append("%s +%d" % [k, int(mods[k])])
		var appeal_lbl := UIKit.label(", ".join(bits), 9, UIKit.COL_GOOD)
		appeal_lbl.custom_minimum_size = Vector2(110, 0)
		row.add_child(appeal_lbl)
		var price_lbl := UIKit.label("%dg" % price, 10, UIKit.COL_INK)
		price_lbl.custom_minimum_size = Vector2(48, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price_lbl)
		var buy_btn := UIKit.button("Buy", func() -> void:
			if EconomyManager.gold < price:
				_toast("Not enough gold!")
				return
			var spot := _find_free_spot(fid)
			if spot == Vector2.INF:
				_toast("No floor space left — rearrange first.")
				return
			EconomyManager.spend_gold(price)
			dev_spawn_furniture(fid, spot)
			hud.refresh()
			_close_modal(decor_layer)
			_open_decor_catalog())
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(buy_btn)
		list.add_child(row)
	vb.add_child(UIKit.label("Decor raises the shop's appeal, drawing matching customers. Move or store it in Rearrange mode.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Close", func() -> void: _close_modal(decor_layer)))


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


func _furniture_cap() -> int:
	var caps: Array = ContentDatabase.bal("shop", {}).get("furniture_caps", [5, 8, 12, 16, 20])
	return int(caps[clampi(GameState.shop_level - 1, 0, caps.size() - 1)])


func _open_expand() -> void:
	var costs: Array = ContentDatabase.bal("shop", {}).get("expansion_costs", [15000, 80000, 200000, 450000])
	var idx := GameState.shop_level - 1
	if idx >= costs.size():
		return
	var cost := int(costs[idx])
	busy = true
	player.frozen = true
	var parts := UIKit.modal(self, "Expand the shop")
	var expand_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var caps: Array = ContentDatabase.bal("shop", {}).get("furniture_caps", [5, 8, 12, 16, 20])
	var next_idx := clampi(GameState.shop_level, 0, caps.size() - 1)
	vb.add_child(UIKit.label("Shop level %d -> %d   Cost: %dg" % [GameState.shop_level, GameState.shop_level + 1, cost]))
	vb.add_child(UIKit.label("Furniture cap %d -> %d pieces (more stands = more display slots)" % [
		_furniture_cap(), int(caps[next_idx])], 10))
	var unlocked: Array[String] = []
	for fid: String in ContentDatabase.furniture:
		if int(ContentDatabase.get_furniture(fid).get("unlock_level", 1)) == GameState.shop_level + 1:
			unlocked.append(String(ContentDatabase.get_furniture(fid).get("name", fid)))
	if not unlocked.is_empty():
		vb.add_child(UIKit.label("Unlocks: %s" % ", ".join(unlocked), 10, UIKit.COL_GOOD))
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
	if customers_remaining.is_empty() and live_customers.is_empty() and negotiating == null and nego_queue.is_empty():
		_end_session()


func _spawn_customer(cust: Dictionary) -> void:
	var c := ShopCustomer.new()
	add_child(c)
	c.position = ENTRANCE
	var preferred_point := Vector2.INF
	var preferred_slot := ShopFurnitureManager.choose_display_slot_for_customer(cust)
	var slot_index := int(preferred_slot.get("slot", -1))
	if slot_index >= 0 and slot_index < browse_points.size():
		preferred_point = browse_points[slot_index]
	c.setup(cust, browse_points, ENTRANCE, preferred_point)
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


## Customers may ask simultaneously; they wait in line while one panel is open.
func _on_negotiate_requested(cust: Dictionary, item_id: String) -> void:
	var node: ShopCustomer = null
	for c in live_customers:
		if c.data == cust:
			node = c
			break
	nego_queue.append({"customer": cust, "item": item_id, "node": node})
	_open_next_negotiation()


func _open_next_negotiation() -> void:
	if negotiating != null or nego_queue.is_empty():
		return
	var entry: Dictionary = nego_queue.pop_front()
	var node: ShopCustomer = entry["node"]
	if node == null or not is_instance_valid(node):
		_open_next_negotiation()
		return
	var item_id := String(entry["item"])
	# the item may have sold to someone earlier in the line
	if not (item_id in InventoryManager.displayed_ids()):
		var replacement := CustomerGen.pick_interest(entry["customer"])
		if replacement == "":
			node.resume_after_negotiation()
			_open_next_negotiation()
			return
		item_id = replacement
	negotiating = node
	var panel := NegotiationPanel.new()
	panel.setup(entry["customer"], item_id, node.portrait_texture())
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
	_open_next_negotiation()


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
			SceneRouter.go("story", {"return_to": "shop"})
		else:
			PatchDebrief.show_debrief(self, session_summary, func() -> void:
				DayBriefing.maybe_show(self))))
	busy = false
