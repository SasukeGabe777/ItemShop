extends Node2D
## The item shop interior. Hero can walk around, stock display furniture, and
## open the shop for a one-period selling session with live customers.

const ORDER_DIALOG_SCRIPT := preload("res://scripts/ui/order_dialog.gd")

var player: TownPlayer
var player2: TownPlayer = null
var hud: GameHUD
var prompt: Label
var prompt2: Label = null
var busy2: bool = false        # player 2 is inside a menu (their half only)
var _nego_player: int = 1      # which local player is haggling right now
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
var session_boom_id := ""
var session_boom_name := ""
var negotiating: ShopCustomer = null
var nego_queue: Array = []  # [{customer: Dictionary, item: String, node: ShopCustomer}]
var order_queue: Array = [] # [{customer, node, mode, direct/order_id}]
var order_dialog_open := false
var _order_player := 1
var corner_buttons: Array[Button] = []  # Buy furniture / Decorate / Rearrange
var _menu_owner: Dictionary = {}  # menu key -> player idx holding it open
var _rstick_edge := false
var _nego_item := ""  # item under negotiation, for the sold-items summary
# pad-driven furniture editing
var edit_sel: DisplayFurniture = null
var pad_carrying := false
var _edit_stick_edge := false
var _pad_carry_pos := Vector2.ZERO
# online party state (host arbitrates turns and remote assignments)
var _net_puppets: Dictionary = {}       # player_index -> TownPlayer puppet
var _net_busy: Dictionary = {}          # host: player_index -> mid-assignment
var _net_next_slot := 1                 # host: whose customer turn it is
var _net_assignments: Dictionary = {}   # host: assignment id -> entry
var _next_assignment_id := 1

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
	if Net.is_online():
		player.manifest_override = PartyState.world_avatar_of(
			PartyState.local_index())
	player.position = Vector2(320, 300)
	add_child(player)
	player.add_child(ZoomCamera.new())
	if not Net.is_online() or PartyState.local_index() == 1:
		var patch := PatchFollower.attach(self, player)
		patch.name = "PatchSidekick"
	hud = GameHUD.new()
	add_child(hud)
	prompt = UIKit.interaction_prompt()
	prompt.z_index = 60
	add_child(prompt)
	if MultiplayerState.enabled:
		player2 = MultiplayerState.attach_split(self, player)
		var p2_sidekick := PatchFollower.attach_p2(self, player2)
		p2_sidekick.name = "P2Sidekick"
		prompt2 = UIKit.interaction_prompt()
		prompt2.z_index = 60
		add_child(prompt2)
	elif Net.is_online():
		_setup_net_shop()
	_build_corner_buttons()
	call_deferred("_show_first_shop_guide")


## ---- online party ----------------------------------------------------------

func _setup_net_shop() -> void:
	var local_idx := PartyState.local_index()
	player.modulate = PartyState.world_tint(local_idx)
	UIKit.floating_name(player, player.visual, PartyState.pname(local_idx), 3.0, 8,
		PartyState.color(local_idx))
	Replica.register_local_player(local_idx, func() -> Array:
		return [player.global_position.x, player.global_position.y,
			player.velocity.x, player.velocity.y, 0])
	Replica.register_factory("customer", _net_spawn_customer)
	Replica.entity_event.connect(_on_net_entity_event)
	PartyState.changed.connect(_refresh_net_puppets)
	PartyState.player_left.connect(_on_net_player_left)
	Net.state_applied.connect(_on_net_state_applied)
	Net.scene_event.connect(_on_net_scene_event)
	_refresh_net_puppets()


func _on_net_state_applied(manager_name: String) -> void:
	if hud != null:
		hud.refresh()
	# InventoryManager emits display_changed during normal sync, but an
	# incoming state can land while this scene is still wiring its signals.
	# Refresh explicitly after every inventory/snapshot application so items
	# stocked by another online player always appear on every stand.
	if manager_name == "inventory" or manager_name == "*":
		_refresh_display_sprites.call_deferred()
	if manager_name == "furniture":
		dev_rebuild_furniture.call_deferred()


func _refresh_net_puppets() -> void:
	if not Net.is_online():
		return
	var local_idx := PartyState.local_index()
	for idx in PartyState.connected_indexes():
		if idx == local_idx or _net_puppets.has(idx):
			continue
		var pup := TownPlayer.new()
		pup.manifest_override = PartyState.world_avatar_of(idx)
		pup.position = player.position + Vector2(24 * idx, 0)
		pup.modulate = PartyState.world_tint(idx)
		add_child(pup)
		pup.make_puppet()
		UIKit.floating_name(pup, pup.visual, PartyState.pname(idx), 3.0, 8,
			PartyState.color(idx))
		Replica.register_player_puppet(idx, pup)
		_net_puppets[idx] = pup
	for idx: int in _net_puppets.keys():
		if idx not in PartyState.connected_indexes():
			var pup: Variant = _net_puppets[idx]
			_net_puppets.erase(idx)
			_net_busy.erase(idx)
			if pup != null and is_instance_valid(pup):
				(pup as Node).queue_free()


## A player dropped: free their puppet, and if they held the active customer
## assignment, hand that customer to the next free shopkeeper.
func _on_net_player_left(idx: int) -> void:
	if not Net.is_host():
		return
	_net_busy.erase(idx)
	for aid: int in _net_assignments.keys():
		var entry: Dictionary = _net_assignments[aid]
		if int(entry.get("who", 0)) != idx:
			continue
		_net_assignments.erase(aid)
		if String(entry.get("kind", "")) == "nego":
			Net.broadcast_scene_event("nego_watch_end", {"who": idx})
		var node: ShopCustomer = entry.get("node")
		if node != null and is_instance_valid(node):
			if String(entry.get("kind", "")) == "nego":
				nego_queue.push_front({"customer": entry.get("customer", {}),
					"item": String(entry.get("item", "")), "node": node})
			else:
				order_queue.push_front(entry.get("entry", {}))
		negotiating = null
		order_dialog_open = false
	_sync_customer_activity_pause()


func _net_spawn_customer(args: Dictionary) -> Node:
	var c := ShopCustomer.new()
	add_child(c)
	c.position = ENTRANCE
	var pp: Array = args.get("preferred_point", [])
	var preferred := Vector2(float(pp[0]), float(pp[1])) if pp.size() == 2 else Vector2.INF
	c.setup(args.get("data", {}), browse_points, ENTRANCE, preferred,
		String(args.get("item", "")), int(args.get("slot", -1)))
	c.make_puppet()
	return c


func _on_net_entity_event(eid: int, event_name: String, args: Dictionary) -> void:
	var node := Replica.entity(eid)
	if node == null:
		return
	match event_name:
		"say":
			_speech(node as Node2D, String(args.get("text", "")))
		"emote":
			if node is ShopCustomer:
				(node as ShopCustomer).show_emote(String(args.get("kind", "neutral")),
					float(args.get("dur", 1.35)))


func _on_net_scene_event(event_name: String, args: Dictionary) -> void:
	match event_name:
		"gate_progress":
			var labels := {"open_shop": "Opening the shop", "leave_shop": "Leaving"}
			_toast("%s — %d/%d ready" % [String(labels.get(String(args.get("action_id", "")),
				"Waiting")), int(args.get("count", 0)), int(args.get("needed", 0))])
		"gate_complete":
			if not Net.is_host():
				return
			match String(args.get("action_id", "")):
				"open_shop":
					if not session_active and not InventoryManager.displayed_ids().is_empty():
						_begin_session()
						Net.broadcast_scene_event("session_started", {
							"count": customers_remaining.size(),
							"boom_id": session_boom_id, "boom_name": session_boom_name})
				"leave_shop":
					busy = true
					SceneRouter.go("town")
		"session_started":
			session_active = true
			session_boom_id = String(args.get("boom_id", ""))
			session_boom_name = String(args.get("boom_name", ""))
			if not Net.is_host() and session_boom_id != "":
				_show_boom_banner(int(args.get("count", 0)))
		"session_ended":
			session_active = false
			var events: Array[String] = []
			for e in args.get("events", []):
				events.append(String(e))
			_present_session_end(events, args.get("summary", {}), args.get("day_sold", []))
		"nego_assign":
			_net_open_assigned_negotiation(args)
		"order_assign":
			_net_open_assigned_order(args)


## The host assigned US a haggling customer: run the minigame locally, ship
## the outcome back. Side effects are all applied host-side.
func _net_open_assigned_negotiation(args: Dictionary) -> void:
	var aid := int(args.get("id", 0))
	var cust: Dictionary = args.get("customer", {})
	var node := Replica.entity(int(args.get("eid", 0)))
	var panel := NegotiationPanel.new()
	panel.setup(cust, String(args.get("item", "")),
		(node as ShopCustomer).portrait_texture() if node is ShopCustomer else null)
	panel.remote = true
	panel.nego.authoritative = false
	panel.spectator_state_changed.connect(func(state: Dictionary) -> void:
		Net.request("shop.nego_watch", {"id": aid, "state": state}))
	panel.finished.connect(func(outcome: Dictionary) -> void:
		busy = false
		player.frozen = false
		Net.request("shop.nego_result", {"id": aid, "outcome": outcome}))
	busy = true
	player.frozen = true
	add_child(panel)


## Host validates that only the player holding this negotiation assignment can
## publish its read-only spectator feed.
func _net_nego_watch_update(sender: int, aid: int, state: Dictionary) -> bool:
	var entry: Dictionary = _net_assignments.get(aid, {})
	if entry.is_empty() or String(entry.get("kind", "")) != "nego" \
			or int(entry.get("who", 0)) != sender:
		return false
	_broadcast_negotiation_watch(sender, state, entry.get("node"))
	return true


func _broadcast_negotiation_watch(who: int, state: Dictionary,
		customer_node: ShopCustomer = null) -> void:
	if not Net.is_host():
		return
	var payload := state.duplicate(true)
	payload["who"] = who
	payload["player_name"] = PartyState.pname(who)
	if customer_node != null and is_instance_valid(customer_node):
		payload["eid"] = int(customer_node.get_meta("net_eid", 0))
	Net.broadcast_scene_event("nego_watch_update", payload)


func _net_open_assigned_order(args: Dictionary) -> void:
	var aid := int(args.get("id", 0))
	var cust: Dictionary = args.get("customer", {})
	var node := Replica.entity(int(args.get("eid", 0)))
	var portrait: Texture2D = (node as ShopCustomer).portrait_texture() if node is ShopCustomer else null
	var dialog := ORDER_DIALOG_SCRIPT.new()
	dialog.resolved.connect(func(result: String) -> void:
		busy = false
		player.frozen = false
		Net.request("shop.order_result", {"id": aid, "result": result}))
	busy = true
	player.frozen = true
	if String(args.get("mode", "")) == "delivery":
		dialog.show_delivery(self, cust, args.get("order", {}), portrait)
	else:
		dialog.show_request(self, cust, args.get("offer", {}), portrait)


## Host: an assigned negotiation's outcome came back from its player.
func _net_nego_result(sender: int, aid: int, outcome: Dictionary) -> void:
	var entry: Dictionary = _net_assignments.get(aid, {})
	if entry.is_empty() or int(entry.get("who", 0)) != sender:
		return
	_net_assignments.erase(aid)
	_net_busy[sender] = false
	Net.broadcast_scene_event("nego_watch_end", {"who": sender})
	Negotiation.apply_remote_outcome(entry.get("customer", {}),
		String(entry.get("item", "")), outcome)
	_nego_item = String(entry.get("item", ""))
	if not session_summary.has("sold"):
		session_summary["sold"] = []  # negotiations can happen outside sessions
	match String(outcome.get("result", "")):
		Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT:
			var qty := maxi(1, int(outcome.get("quantity", 1)))
			session_summary["sales"] = int(session_summary["sales"]) + qty
			session_summary["revenue"] = int(session_summary["revenue"]) + int(outcome.get("price", 0))
			var unit_price := int(outcome.get("price", 0)) / qty
			var remainder := int(outcome.get("price", 0)) - unit_price * qty
			for i in range(qty):
				(session_summary["sold"] as Array).append({"item": _nego_item,
					"price": unit_price + (remainder if i == 0 else 0)})
			if bool(outcome.get("perfect", false)):
				session_summary["perfect"] = int(session_summary["perfect"]) + 1
		_:
			session_summary["left"] = int(session_summary["left"]) + 1
	var node: ShopCustomer = entry.get("node")
	if node != null and is_instance_valid(node):
		var result := String(outcome.get("result", ""))
		node.show_emote(String(outcome.get("emote",
			"unhappy" if result == Negotiation.RESULT_LEAVE else "neutral")), 2.2)
		if String(outcome.get("message", "")) != "":
			_speech(node, String(outcome.get("message", "")))
		if result in [Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT]:
			var body: Variant = _net_puppets.get(sender)
			if body != null and is_instance_valid(body):
				UIKit.gold_popup(body, int(outcome.get("price", 0)))
		node.resume_after_negotiation()
	negotiating = null
	_sync_customer_activity_pause()
	hud.refresh()
	Net.sync_managers(["economy", "inventory", "relationships", "game_state"])
	_open_next_negotiation()


func _net_order_result(sender: int, aid: int, result: String) -> void:
	var entry: Dictionary = _net_assignments.get(aid, {})
	if entry.is_empty() or int(entry.get("who", 0)) != sender:
		return
	_net_assignments.erase(aid)
	_net_busy[sender] = false
	_finish_order_dialog(entry.get("entry", {}), result)
	Net.sync_managers(["inventory", "game_state", "relationships"])


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
	# pad_nav's A-press focus recovery must not land here — the right stick
	# is the deliberate way to select these while walking around
	layer.set_meta("pad_recovery_skip", true)
	corner_buttons.clear()
	for def: Array in [["Buy furniture", _open_furniture_catalog],
			["Decorate", _open_decor_catalog], ["Rearrange furniture", _on_rearrange_pressed]]:
		var b := UIKit.button(String(def[0]), def[1], 9)
		box.add_child(b)
		corner_buttons.append(b)


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
	c.order_delivery_requested.connect(_on_order_delivery_requested)
	c.boom_disappointed.connect(_on_boom_disappointed)
	c.left.connect(func(me: ShopCustomer) -> void: live_customers.erase(me))
	live_customers.append(c)
	return c


func dev_open_shop() -> void:
	if not session_active:
		_begin_session()


func dev_close_shop() -> void:
	customers_remaining.clear()
	nego_queue.clear()
	order_queue.clear()
	order_dialog_open = false
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
	if player == null:
		return
	# Pause only customer activity while any menu is visible. The world and a
	# second local player keep processing, but customers cannot stack decisions
	# behind the panel that is already demanding attention.
	_sync_customer_activity_pause()
	if session_active and not _customer_activity_blocked() and Net.is_authority():
		_run_session(delta)
	_shop_player_frame(player, prompt, "", busy, 1)
	if player2 != null:
		# watchdog: unstick P2 if their busy flag outlives their menus
		if busy2 and _nego_player != 2 and not UIKit.modal_open(MultiplayerState.p2_viewport()):
			busy2 = false
			player2.frozen = false
		_shop_player_frame(player2, prompt2, "p2_", busy2, 2)


func _customer_activity_blocked() -> bool:
	return negotiating != null or order_dialog_open or UIKit.modal_open()


func _sync_customer_activity_pause() -> void:
	var paused := _customer_activity_blocked()
	for customer: ShopCustomer in live_customers:
		if is_instance_valid(customer):
			customer.set_shop_activity_paused(paused)


func _shop_player_frame(p: TownPlayer, pr: Label, prefix: String, p_busy: bool, idx: int) -> void:
	if p_busy:
		if pr != null:
			pr.visible = false
		return
	if p.position.y > EXIT_Y:
		if session_active:
			p.position.y = EXIT_Y
			if not get_meta("exit_toasted", false):
				set_meta("exit_toasted", true)
				_toast("Close up first — customers are browsing!")
				get_tree().create_timer(2.0).timeout.connect(func() -> void: set_meta("exit_toasted", false))
		elif Net.is_online():
			# whole-party door: stand here to vote; the host leaves for everyone
			p.position.y = EXIT_Y + 2.0
			if not get_meta("exit_gated", false):
				set_meta("exit_gated", true)
				Net.request("party.gate", {"action_id": "leave_shop"})
				get_tree().create_timer(2.0).timeout.connect(func() -> void:
					set_meta("exit_gated", false))
		elif player2 == null:
			busy = true
			SceneRouter.go("town")
			return
		else:
			# split-screen: both shopkeepers leave together
			var other: TownPlayer = player2 if p == player else player
			if other != null and other.position.y > EXIT_Y - 10.0:
				busy = true
				SceneRouter.go("town")
				return
			p.position.y = EXIT_Y + 2.0
			if not get_meta("exit_toasted", false):
				set_meta("exit_toasted", true)
				_toast("Leaving — 1/2 at the door")
				get_tree().create_timer(2.0).timeout.connect(func() -> void: set_meta("exit_toasted", false))
	var ic := p.nearest_interactable()
	if pr != null:
		pr.visible = ic != null
		if ic != null:
			pr.text = "[%s] %s" % [UIKit.interact_key(), ic.prompt]
			pr.position = p.position + Vector2(-40, -34)
	if idx == 1:
		_process_corner_focus()
	# A doubles as ui_accept: while a modal is up on THIS player's screen,
	# presses belong to the modal, not the world. Same when a corner button
	# is selected: A presses the button, not the world.
	var vp := get_viewport() if idx == 1 else MultiplayerState.p2_viewport()
	if Input.is_action_just_pressed(prefix + "interact") and ic != null and not UIKit.modal_open(vp) \
			and not (idx == 1 and get_viewport().gui_get_focus_owner() in corner_buttons):
		_activate(ic.action_id, idx)


## Right stick selects the lower-right shop buttons: flick left/right to move
## between them, move the character (left stick) or press B to put it away.
func _process_corner_focus() -> void:
	if not UIKit.pad_connected() or UIKit.modal_open():
		return
	var focus := get_viewport().gui_get_focus_owner()
	var selected := focus in corner_buttons
	if selected and (Input.is_action_just_pressed("ui_cancel")
			or Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.3):
		focus.release_focus()
		return
	var x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(x) < 0.6:
		_rstick_edge = false
		return
	if _rstick_edge:
		return
	_rstick_edge = true
	if not selected:
		corner_buttons[0].grab_focus()
	elif x > 0.0:
		corner_buttons[mini(corner_buttons.find(focus) + 1, corner_buttons.size() - 1)].grab_focus()
	else:
		corner_buttons[maxi(corner_buttons.find(focus) - 1, 0)].grab_focus()


func _activate(action: String, who: int = 1) -> void:
	if MultiplayerState.enabled and _menu_owner.has(action):
		_toast("In use by Player %d!" % int(_menu_owner[action]))
		return
	if action.begins_with("slot_"):
		_open_slot_picker(int(action.trim_prefix("slot_")), who)
		return
	match action:
		"open_shop":
			if session_active:
				return
			if InventoryManager.displayed_ids().is_empty():
				_toast("Stock the display furniture first!")
				return
			if Net.is_online():
				Net.request("party.gate", {"action_id": "open_shop"})
				return
			if MultiplayerState.enabled and not MultiplayerState.ready_up("open_shop", who):
				_toast("Opening the shop — %d/2 ready" % MultiplayerState.ready_count("open_shop"))
				return
			MultiplayerState.clear_ready("open_shop")
			var opening_title := "Opening the shop"
			if BoomManager.is_active():
				opening_title = "%s BOOM" % BoomManager.display_name()
			UIKit.confirm_time_cost(self, opening_title, TimeManager.activity_cost("open_shop"), _begin_session)
		"storage":
			if Net.is_client():
				_toast("Only %s can manage storage (for now)." % PartyState.pname(1))
				return
			_open_storage(who)
		"expand":
			if Net.is_client():
				_toast("Only %s can expand the shop (for now)." % PartyState.pname(1))
				return
			_open_expand(who)
		"rearrange":
			if session_active:
				_toast("Not while customers are browsing!")
				return
			if who == 2 or Net.is_client():
				_toast("Player 1 holds the furniture tools!")
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
	var f := get_viewport().gui_get_focus_owner()
	if f != null:
		f.release_focus()  # A must edit furniture now, not re-press Rearrange
	for piece in furniture_nodes:
		if piece.is_moveable():
			piece.set_edit_highlight(true)
	var hint_text := "EDIT MODE — click furniture to pick up, click to place. Holding: [Q] store  [X] sell 50%. Right-click cancels, [E] done"
	if UIKit.pad_connected():
		hint_text = "EDIT MODE — L-stick: choose a piece · A: pick up / place · holding: Y store, X sell 50% · B: cancel / done"
	edit_hint = UIKit.label(hint_text, 9, UIKit.COL_ACCENT)
	edit_hint.position = Vector2(150, 124)
	edit_hint.z_index = 70
	add_child(edit_hint)
	if UIKit.pad_connected():
		_set_edit_sel(_first_moveable())


func _exit_edit_mode() -> void:
	if carrying != null:
		_cancel_carry()
	pad_carrying = false
	_set_edit_sel(null)
	edit_mode = false
	player.frozen = false
	for piece in furniture_nodes:
		piece.clear_ghost()
	if edit_hint != null:
		edit_hint.queue_free()
		edit_hint = null


func _process_edit() -> void:
	if Input.is_action_just_pressed("interact") and not UIKit.modal_open():
		# on a pad, A means pick up / place; on keyboard, E means done
		if UIKit.pad_connected() and Input.is_joy_button_pressed(0, JOY_BUTTON_A):
			_pad_edit_interact()
		else:
			_exit_edit_mode()
			return
	if UIKit.pad_connected():
		_process_pad_edit(get_process_delta_time())
	if carrying != null and not pad_carrying:
		var pos := (get_global_mouse_position() / EDIT_GRID).round() * EDIT_GRID
		carrying.position = pos
		carrying.set_ghost(ShopFurnitureManager.placement_valid(carrying.uid, pos, FURNITURE_AREA))


# ---- pad-driven editing: flick to select, A to pick/place, stick to move ----

func _first_moveable() -> DisplayFurniture:
	for piece in furniture_nodes:
		if is_instance_valid(piece) and piece.is_moveable():
			return piece
	return null


func _set_edit_sel(piece: DisplayFurniture) -> void:
	if edit_sel != null and is_instance_valid(edit_sel):
		edit_sel.modulate = Color.WHITE
	edit_sel = piece
	if edit_sel != null and is_instance_valid(edit_sel):
		edit_sel.modulate = Color(1.35, 1.3, 0.8)


## Nearest moveable piece in the flicked direction from the current selection.
func _move_edit_sel(dir: Vector2) -> void:
	if edit_sel == null or not is_instance_valid(edit_sel):
		_set_edit_sel(_first_moveable())
		return
	var best: DisplayFurniture = null
	var best_d := 1e9
	for piece in furniture_nodes:
		if piece == edit_sel or not is_instance_valid(piece) or not piece.is_moveable():
			continue
		var delta := piece.position - edit_sel.position
		if delta.length() < 1.0 or delta.normalized().dot(dir) < 0.35:
			continue
		if delta.length() < best_d:
			best_d = delta.length()
			best = piece
	if best != null:
		_set_edit_sel(best)


func _process_pad_edit(delta: float) -> void:
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("ui_cancel"):
		if carrying != null:
			_cancel_carry()
			pad_carrying = false
			_set_edit_sel(edit_sel if edit_sel != null and is_instance_valid(edit_sel) else _first_moveable())
		else:
			_exit_edit_mode()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if carrying == null or not pad_carrying:
		# selection mode: flick toward the piece you want
		if v.length() < 0.55:
			_edit_stick_edge = false
		elif not _edit_stick_edge:
			_edit_stick_edge = true
			_move_edit_sel(v.normalized())
		return
	# carrying with the pad: stick slides the piece on the grid
	if v.length() > 0.2:
		_pad_carry_pos += v * 150.0 * delta
		_pad_carry_pos = _pad_carry_pos.clamp(Vector2(16, 40), Vector2(624, 440))
		var snapped := (_pad_carry_pos / EDIT_GRID).round() * EDIT_GRID
		carrying.position = snapped
		carrying.set_ghost(ShopFurnitureManager.placement_valid(carrying.uid, snapped, FURNITURE_AREA))
	if Input.is_action_just_pressed("use_item"):  # Y — store
		_put_away_carried(false)
	elif Input.is_action_just_pressed("special"):  # X — sell half price
		_put_away_carried(true)
	if carrying == null:  # put-away succeeded (it can refuse for the last stand)
		pad_carrying = false
		_set_edit_sel(_first_moveable())


func _pad_edit_interact() -> void:
	if carrying == null:
		if edit_sel != null and is_instance_valid(edit_sel) and edit_sel.is_moveable():
			carrying = edit_sel
			carry_origin = edit_sel.position
			pad_carrying = true
			_pad_carry_pos = edit_sel.position
		return
	var pos := (carrying.position / EDIT_GRID).round() * EDIT_GRID
	if ShopFurnitureManager.placement_valid(carrying.uid, pos, FURNITURE_AREA):
		carrying.position = pos
		ShopFurnitureManager.move_instance(carrying.uid, pos)
		carrying.set_edit_highlight(true)
		var placed := carrying
		carrying = null
		pad_carrying = false
		_rebuild_browse_points()
		_set_edit_sel(placed)  # straight back to selection mode
	else:
		_toast("Can't place it there.")


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


func _highlight_display_slot(slot: int, on: bool = true) -> void:
	for piece: DisplayFurniture in furniture_nodes:
		if slot >= piece.slot_base and slot < piece.slot_base + piece.slot_count:
			piece.set_slot_highlight(slot, on)
		elif on:
			piece.clear_slot_highlight()


## In-menu diagram of the actual furniture and all of its display spots. The
## selected gold diamond mirrors the marker left on the stand in the room.
func _make_slot_preview(info: Dictionary, slot: int) -> Control:
	var type_id := String(info.get("type", ""))
	var def := ContentDatabase.get_furniture(type_id)
	var range_info := ShopFurnitureManager.slot_range_for_uid(int(info.get("furniture_uid", 0)))
	var local_slot := slot - range_info.x
	var offsets: Array = def.get("display_slots", [[0, -12]])
	var center := CenterContainer.new()
	center.name = "SlotPreview"
	center.custom_minimum_size = Vector2(0, 88)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(210, 84)
	center.add_child(canvas)

	var furniture_art := Sprite2D.new()
	var sprite_path := String(def.get("sprite", ""))
	furniture_art.texture = load(sprite_path) if sprite_path != "" and ResourceLoader.exists(sprite_path) else null
	furniture_art.position = Vector2(105, 42)
	furniture_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if furniture_art.texture != null:
		var texture_size := furniture_art.texture.get_size()
		var art_scale := minf(110.0 / texture_size.x, 48.0 / texture_size.y)
		furniture_art.scale = Vector2(art_scale, art_scale)
	canvas.add_child(furniture_art)

	for i in offsets.size():
		var offset: Array = offsets[i]
		var marker := UIKit.label("◆" if i == local_slot else "◇", 16,
			UIKit.COL_ACCENT if i == local_slot else UIKit.COL_DIM)
		marker.name = "SelectedSlotMarker" if i == local_slot else "SlotMarker%d" % i
		marker.position = Vector2(99 + float(offset[0]) * 2.0, 14 + float(offset[1]) * 0.35)
		marker.add_theme_color_override("font_outline_color", Color("#20243a"))
		marker.add_theme_constant_override("outline_size", 3)
		canvas.add_child(marker)

	var caption := UIKit.label("Selected spot %d of %d" % [local_slot + 1, offsets.size()], 9,
		UIKit.COL_ACCENT if offsets.size() > 1 else UIKit.COL_DIM)
	caption.position = Vector2(0, 67)
	caption.size = Vector2(210, 17)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(caption)
	return center


func _open_slot_picker(slot: int, who: int = 1) -> void:
	if who == 2:
		busy2 = true
		player2.frozen = true
	else:
		busy = true
		player.frozen = true
	var info := _slot_info(slot)
	var type_name := String(ContentDatabase.get_furniture(String(info.get("type", ""))).get("name", "stand"))
	var allowed: Array = info.get("allowed_categories", [])
	var parts := UIKit.modal(MultiplayerState.menu_parent(who, self), "Display slot %d (%s)" % [slot + 1, type_name])
	var pick_layer: CanvasLayer = parts[0]
	_highlight_display_slot(slot)
	pick_layer.tree_exiting.connect(func() -> void: _highlight_display_slot(slot, false))
	_claim_menu("slot_%d" % slot, who, pick_layer)
	var vb: VBoxContainer = parts[1]
	(vb.get_parent() as PanelContainer).custom_minimum_size = Vector2(460 if MultiplayerState.enabled else 560, 0)
	vb.add_child(_make_slot_preview(info, slot))
	var current := String(InventoryManager.display[slot]) if slot < InventoryManager.display.size() else ""
	if current != "":
		var cur_row := HBoxContainer.new()
		cur_row.add_theme_constant_override("separation", 8)
		var cur_lbl := UIKit.label("Currently: %s" % ContentDatabase.item_name(current))
		cur_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cur_row.add_child(cur_lbl)
		cur_row.add_child(UIKit.button("Take back to storage", func() -> void:
			if Net.is_client():
				Net.request("inventory.take_display", {"slot": slot})
			else:
				InventoryManager.take_display(slot)
			_close_modal(pick_layer, who), 8))
		vb.add_child(cur_row)
	# same sorting bar the market has
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	vb.add_child(sort_row)
	sort_row.add_child(UIKit.spacer(false))
	var list_parts := UIKit.scroll_list(Vector2(500, 230))
	vb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	var sort_mode := {"v": "price"}
	var fill_rows := func() -> void:
		for id in InventoryManager.sorted_ids(sort_mode["v"]):
			var it := ContentDatabase.get_item(id)
			if it.get("sellable", true) == false:
				continue
			if not allowed.is_empty() and not (String(it.get("category", "")) in allowed):
				continue
			list.add_child(_make_pick_row(id, slot, pick_layer, who))
	var refill := func() -> void: UIKit.rebuild_list(list, fill_rows)
	for mode in ["name", "price", "category", "world"]:
		sort_row.add_child(UIKit.button("Sort: %s" % mode, func() -> void:
			sort_mode["v"] = mode
			refill.call(), 8))
	fill_rows.call()
	vb.add_child(UIKit.button("Cancel", func() -> void: _close_modal(pick_layer, who)))


## One stocking row, mirroring the market's layout: 24px icon, name, category,
## trend, value, owned count, action button.
func _make_pick_row(id: String, slot: int, pick_layer: CanvasLayer, who: int = 1) -> VBoxContainer:
	var it := ContentDatabase.get_item(id)
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 26)
	entry.add_child(row)
	row.add_child(UIKit.item_icon(id))
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
	row.add_child(UIKit.gold_icon("small", Vector2(16, 14)))
	var price_lbl := UIKit.label("x%d  ~%d" % [InventoryManager.count(id), MarketManager.market_value(id)], 9, UIKit.COL_INK)
	price_lbl.custom_minimum_size = Vector2(72, 0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.tooltip_text = "You own %d; sells for about %dg today" % [InventoryManager.count(id), MarketManager.market_value(id)]
	price_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(price_lbl)
	var place_btn := UIKit.button("Place", func() -> void:
		if Net.is_client():
			Net.request("inventory.place_display", {"slot": slot, "item_id": id})
		else:
			InventoryManager.place_display(slot, id)
		_close_modal(pick_layer, who))
	place_btn.custom_minimum_size = Vector2(50, 0)
	place_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(place_btn)
	var appeal: Dictionary = it.get("appeal", {})
	if not appeal.is_empty():
		var bits: Array[String] = []
		for k: String in appeal:
			bits.append("%s+%d" % [k, int(appeal[k])])
		var sub := UIKit.label(" ".join(bits), 8, UIKit.COL_DIM)
		sub.clip_text = true
		var sub_pad := MarginContainer.new()
		sub_pad.add_theme_constant_override("margin_left", 30)
		sub_pad.add_theme_constant_override("margin_bottom", 4)
		sub_pad.add_child(sub)
		entry.add_child(sub_pad)
	return entry


## Marks a menu as held by a player; releases automatically however it closes.
func _claim_menu(menu_key: String, who: int, layer: CanvasLayer) -> void:
	_menu_owner[menu_key] = who
	layer.tree_exiting.connect(func() -> void: _menu_owner.erase(menu_key))


func _close_modal(modal_layer: CanvasLayer, who: int = 1) -> void:
	modal_layer.queue_free()
	if who == 2:
		busy2 = false
		if player2 != null:
			player2.frozen = false
	else:
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
	var parts := UIKit.modal(self, "Furniture catalog")
	var cat_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var gold_row := HBoxContainer.new()
	gold_row.add_child(UIKit.gold_icon("small", Vector2(18, 15)))
	gold_row.add_child(UIKit.label("Available: %d" % EconomyManager.gold, 10, UIKit.COL_ACCENT))
	vb.add_child(gold_row)
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
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		var row := HBoxContainer.new()
		var lbl := UIKit.label("%s — %d slot%s" % [String(def.get("name", fid)), slots, "s" if slots > 1 else ""], 10)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		row.add_child(UIKit.label("%dg" % price, 10, UIKit.COL_ACCENT))
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
		entry.add_child(row)
		var attention := float(def.get("customer_attention_modifier", 0.0))
		var desc := "Displays %d item%s." % [slots, "s" if slots != 1 else ""]
		if attention > 0.0:
			desc += " +%d%% customer attention — draws more shoppers to %s." % [
				int(round(attention * 100.0)), "these items" if slots > 1 else "this item"]
		var desc_lbl := UIKit.label(desc, 8, UIKit.COL_GOOD if attention > 0.0 else UIKit.COL_DIM)
		desc_lbl.tooltip_text = desc
		var desc_pad := MarginContainer.new()
		desc_pad.add_theme_constant_override("margin_left", 4)
		desc_pad.add_theme_constant_override("margin_bottom", 4)
		desc_pad.add_child(desc_lbl)
		entry.add_child(desc_pad)
		list.add_child(entry)
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
	var parts := UIKit.modal(self, "Decorate the shop")
	var decor_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var gold_row := HBoxContainer.new()
	gold_row.add_child(UIKit.gold_icon("small", Vector2(18, 15)))
	gold_row.add_child(UIKit.label("Available: %d" % EconomyManager.gold, 10, UIKit.COL_ACCENT))
	vb.add_child(gold_row)
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


func _open_storage(who: int = 1) -> void:
	if who == 2:
		busy2 = true
		player2.frozen = true
	else:
		busy = true
		player.frozen = true
	var parts := UIKit.modal(MultiplayerState.menu_parent(who, self), "Storage — %d items" % InventoryManager.total_items())
	var storage_layer: CanvasLayer = parts[0]
	_claim_menu("storage", who, storage_layer)
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
	vb.add_child(UIKit.button("Close", func() -> void: _close_modal(storage_layer, who)))


func _furniture_cap() -> int:
	var caps: Array = ContentDatabase.bal("shop", {}).get("furniture_caps", [5, 8, 12, 16, 20])
	return int(caps[clampi(GameState.shop_level - 1, 0, caps.size() - 1)])


func _open_expand(who: int = 1) -> void:
	var costs: Array = ContentDatabase.bal("shop", {}).get("expansion_costs", [15000, 80000, 200000, 450000])
	var idx := GameState.shop_level - 1
	if idx >= costs.size():
		return
	var cost := int(costs[idx])
	if who == 2:
		busy2 = true
		player2.frozen = true
	else:
		busy = true
		player.frozen = true
	var parts := UIKit.modal(MultiplayerState.menu_parent(who, self), "Expand the shop")
	var expand_layer: CanvasLayer = parts[0]
	_claim_menu("expand", who, expand_layer)
	var vb: VBoxContainer = parts[1]
	var caps: Array = ContentDatabase.bal("shop", {}).get("furniture_caps", [5, 8, 12, 16, 20])
	var next_idx := clampi(GameState.shop_level, 0, caps.size() - 1)
	var cost_row := HBoxContainer.new()
	cost_row.add_child(UIKit.label("Shop level %d -> %d   Cost:" % [GameState.shop_level, GameState.shop_level + 1]))
	cost_row.add_child(UIKit.gold_icon("small", Vector2(18, 15)))
	cost_row.add_child(UIKit.label("%d" % cost, 10, UIKit.COL_ACCENT))
	vb.add_child(cost_row)
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
			_close_modal(expand_layer, who)
			SceneRouter.go("shop")))
	row.add_child(UIKit.button("Cancel", func() -> void: _close_modal(expand_layer, who)))
	vb.add_child(row)


# ---------------- selling session ----------------

func _begin_session() -> void:
	session_active = true
	session_boom_id = BoomManager.active_boom_id if BoomManager.is_active() else ""
	session_boom_name = BoomManager.display_name() if BoomManager.is_active() else ""
	session_summary = {"sales": 0, "revenue": 0, "perfect": 0, "left": 0, "orders": 0, "sold": [],
		"customers": 0, "boom_id": session_boom_id, "boom_name": session_boom_name}
	customers_remaining.clear()
	customers_remaining.append_array(CustomerGen.generate_session_customers())
	session_summary["customers"] = customers_remaining.size()
	spawn_timer = 0.5
	if BoomManager.is_active():
		_show_boom_banner(customers_remaining.size())
		BoomManager.mark_announced()
	AudioManager.play_track("item_shop")


func _run_session(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0 and not customers_remaining.is_empty() and live_customers.size() < BoomManager.max_live_customers():
		spawn_timer = BoomManager.next_spawn_delay()
		_spawn_customer(customers_remaining.pop_front())
	if negotiating == null and not nego_queue.is_empty():
		if not order_dialog_open and order_queue.is_empty():
			_open_next_negotiation()
	if negotiating == null and not order_dialog_open and not order_queue.is_empty():
		_open_next_order_dialog()
	if customers_remaining.is_empty() and live_customers.is_empty() and negotiating == null \
			and nego_queue.is_empty() and order_queue.is_empty() and not order_dialog_open:
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
	c.setup(cust, browse_points, ENTRANCE, preferred_point,
		String(preferred_slot.get("item_id", "")), slot_index)
	c.negotiate_requested.connect(_on_negotiate_requested)
	c.order_requested.connect(_on_order_requested)
	c.order_delivery_requested.connect(_on_order_delivery_requested)
	c.boom_disappointed.connect(_on_boom_disappointed)
	c.left.connect(func(me: ShopCustomer) -> void:
		live_customers.erase(me)
		if Net.is_host():
			Replica.host_despawn(me, "left", {}))
	live_customers.append(c)
	if Net.is_host():
		var preferred_arr: Array = []
		if preferred_point != Vector2.INF:
			preferred_arr = [preferred_point.x, preferred_point.y]
		Replica.host_register(c, "customer", {"data": cust,
			"preferred_point": preferred_arr,
			"item": String(preferred_slot.get("item_id", "")), "slot": slot_index})
	if bool(cust.get("named", false)) and String(cust.get("line", "")) != "":
		_speech(c, String(cust["line"]))


func _speech(over: Node2D, text: String) -> void:
	if Net.is_host() and int(over.get_meta("net_eid", 0)) != 0:
		Replica.host_event(over, "say", {"text": text})
	var prior := over.get_node_or_null("SpeechBubble")
	if prior != null:
		prior.queue_free()
	var lbl := UIKit.label(text, 8)
	lbl.name = "SpeechBubble"
	lbl.custom_minimum_size = Vector2(0, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size.x = minf(180, text.length() * 4.5)
	# Stack dialogue above the reaction icon, both centered on the customer.
	var speech_y := -52.0
	if over is ShopCustomer and (over as ShopCustomer).visual != null:
		speech_y = (over as ShopCustomer).visual.top_y() * (over as ShopCustomer).visual.scale.y - 32.0
	lbl.position = Vector2(-lbl.custom_minimum_size.x / 2.0, speech_y)
	lbl.z_index = 65
	over.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _on_order_requested(cust: Dictionary, direct_boom_request: bool = false) -> void:
	order_queue.append({"customer": cust, "node": _customer_node(cust),
		"mode": "request", "direct": direct_boom_request})
	_open_next_order_dialog()


func _on_order_delivery_requested(cust: Dictionary, order_id: int) -> void:
	order_queue.append({"customer": cust, "node": _customer_node(cust),
		"mode": "delivery", "order_id": order_id})
	_open_next_order_dialog()


func _open_next_order_dialog() -> void:
	if order_dialog_open or negotiating != null or order_queue.is_empty():
		return
	var who := _available_customer_player()
	if who == 0:
		return
	var entry: Dictionary = order_queue.pop_front()
	var node: ShopCustomer = entry.get("node")
	if node == null or not is_instance_valid(node):
		_open_next_order_dialog()
		return
	var cust: Dictionary = entry["customer"]
	order_dialog_open = true
	_order_player = who
	# validate + roll host-side FIRST (offers use the host RNG), whoever hosts
	# the dialog
	var order: Dictionary = {}
	var offer: Dictionary = {}
	if String(entry.get("mode", "")) == "delivery":
		order = InventoryManager.order_by_id(int(entry.get("order_id", -1)))
		if order.is_empty():
			_order_dialog_cancelled(entry)
			return
	else:
		offer = CustomerGen.make_order_offer(cust, bool(entry.get("direct", false)), true)
		if offer.is_empty():
			if bool(entry.get("direct", false)):
				_on_boom_disappointed(cust)
			_order_dialog_cancelled(entry)
			return
		entry["offer"] = offer
		InventoryManager.mark_order_requested()
	if Net.is_online() and who != PartyState.local_index():
		_net_busy[who] = true
		var aid := _next_assignment_id
		_next_assignment_id += 1
		_net_assignments[aid] = {"kind": "order", "entry": entry, "who": who}
		Net.send_scene_event_to(who, "order_assign", {"id": aid, "customer": cust,
			"mode": String(entry.get("mode", "")), "order": order, "offer": offer,
			"eid": int(node.get_meta("net_eid", 0))})
		_sync_customer_activity_pause()
		_advance_customer_player()
		return
	var dialog := ORDER_DIALOG_SCRIPT.new()
	dialog.resolved.connect(func(result: String) -> void:
		_finish_order_dialog(entry, result))
	if who == 2:
		busy2 = true
		player2.frozen = true
	else:
		busy = true
		player.frozen = true
	_sync_customer_activity_pause()
	var parent := MultiplayerState.menu_parent(who, self)
	if String(entry.get("mode", "")) == "delivery":
		dialog.show_delivery(parent, cust, order, node.portrait_texture())
		_advance_customer_player()
	else:
		dialog.show_request(parent, cust, offer, node.portrait_texture())
		_advance_customer_player()


func _finish_order_dialog(entry: Dictionary, result: String) -> void:
	var cust: Dictionary = entry.get("customer", {})
	var node: ShopCustomer = entry.get("node")
	if String(entry.get("mode", "")) == "delivery":
		var order_id := int(entry.get("order_id", -1))
		if result == "deliver" and InventoryManager.try_fulfill_order(order_id):
			if is_instance_valid(node):
				node.show_emote("happy", 2.2)
				_speech(node, "Perfect — exactly what I ordered. I won't forget this!")
		else:
			InventoryManager.fail_order(order_id)
			if is_instance_valid(node):
				node.show_emote("unhappy", 2.2)
				_speech(node, "You promised it would be ready...")
	else:
		if result == "accept":
			var offer: Dictionary = entry.get("offer", {})
			var order := InventoryManager.add_order(String(cust.get("id", "")),
				String(offer.get("kind", "item")), String(offer.get("target", "")),
				int(offer.get("qty", 1)), int(offer.get("reward_each", 0)),
				int(offer.get("return_in_days", 1)), cust)
			if not order.is_empty():
				session_summary["orders"] = int(session_summary["orders"]) + 1
				GameState.know_customer(String(cust.get("id", "")))
				if is_instance_valid(node):
					node.show_emote("happy", 1.8)
					_speech(node, "Wonderful. I'll be back on Day %d!" % int(order["return_day"]))
		else:
			if is_instance_valid(node):
				node.show_emote("neutral", 1.5)
				_speech(node, "I understand. Maybe another time.")
	_order_dialog_cancelled(entry)


func _order_dialog_cancelled(entry: Dictionary) -> void:
	if _order_player == 2:
		busy2 = false
		if player2 != null:
			player2.frozen = false
	else:
		busy = false
		player.frozen = false
	var node: ShopCustomer = entry.get("node")
	if node != null and is_instance_valid(node):
		node.resume_after_order()
	order_dialog_open = false
	_sync_customer_activity_pause()
	if hud != null:
		hud.refresh()
	_open_next_order_dialog()
	_open_next_negotiation()


func _on_boom_disappointed(cust: Dictionary) -> void:
	session_summary["left"] = int(session_summary["left"]) + 1
	var node := _customer_node(cust)
	if node != null:
		_speech(node, "Nothing for the %s? I'll try another shop." % BoomManager.display_name())
	if bool(cust.get("named", false)):
		RelationshipManager.change_relationship(String(cust.get("id", "")), -1)


func _customer_node(cust: Dictionary) -> ShopCustomer:
	for customer in live_customers:
		if customer.data == cust:
			return customer
	return null


## Customers may ask simultaneously; they wait in line while one panel is open.
func _on_negotiate_requested(cust: Dictionary, item_id: String) -> void:
	var node := _customer_node(cust)
	nego_queue.append({"customer": cust, "item": item_id, "node": node})
	_open_next_negotiation()


func _open_next_negotiation() -> void:
	if negotiating != null or order_dialog_open or nego_queue.is_empty():
		return
	# In co-op, customer conversations use a strict shared round-robin. If the
	# designated shopkeeper has another menu open, the customer waits rather
	# than giving the other player two turns in a row.
	var who := _available_customer_player()
	if who == 0:
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
	_nego_item = item_id
	_nego_player = who
	# online: a remote player's turn — ship them the assignment; the host
	# keeps `negotiating` set so the line stays serial until their result
	if Net.is_online() and who != PartyState.local_index():
		_net_busy[who] = true
		var aid := _next_assignment_id
		_next_assignment_id += 1
		_net_assignments[aid] = {"kind": "nego", "customer": entry["customer"],
			"item": item_id, "node": node, "who": who}
		Net.send_scene_event_to(who, "nego_assign", {"id": aid,
			"customer": entry["customer"], "item": item_id,
			"eid": int(node.get_meta("net_eid", 0))})
		_advance_customer_player()
		_sync_customer_activity_pause()
		return
	var panel := NegotiationPanel.new()
	panel.setup(entry["customer"], item_id, node.portrait_texture())
	panel.pad_device = 0 if who == 1 else MultiplayerState.P2_DEVICE
	if Net.is_online():
		panel.spectator_state_changed.connect(
			func(state: Dictionary) -> void:
				_broadcast_negotiation_watch(who, state, node))
	panel.finished.connect(_on_negotiation_finished)
	if who == 2:
		busy2 = true
		player2.frozen = true
	else:
		busy = true
		player.frozen = true
	MultiplayerState.menu_parent(who, self).add_child(panel)
	_advance_customer_player()
	_sync_customer_activity_pause()


func _available_customer_player() -> int:
	if Net.is_online():
		# strict shared rotation over connected seats, same as couch: if the
		# designated shopkeeper is mid-menu the customer waits in line
		var order := PartyState.connected_indexes()
		if order.is_empty():
			return 0
		if _net_next_slot not in order:
			_net_next_slot = order[0]
		var idx := _net_next_slot
		if idx == PartyState.local_index():
			return idx if not busy and not UIKit.modal_open(get_viewport()) else 0
		return idx if not bool(_net_busy.get(idx, false)) else 0
	if not MultiplayerState.enabled or player2 == null:
		return 1 if not busy and not UIKit.modal_open(get_viewport()) else 0
	var who := MultiplayerState.next_customer_player
	if who == 1:
		return 1 if not busy and not UIKit.modal_open(get_viewport()) else 0
	return 2 if not busy2 and not UIKit.modal_open(MultiplayerState.p2_viewport()) else 0


func _advance_customer_player() -> void:
	if Net.is_online():
		var order := PartyState.connected_indexes()
		if order.is_empty():
			return
		var pos := maxi(0, order.find(_net_next_slot))
		_net_next_slot = order[(pos + 1) % order.size()]
		return
	MultiplayerState.next_customer_player = 2 if MultiplayerState.enabled and player2 != null \
		and MultiplayerState.next_customer_player == 1 else 1


func _on_negotiation_finished(outcome: Dictionary) -> void:
	if Net.is_online() and Net.is_host():
		Net.broadcast_scene_event("nego_watch_end", {"who": _nego_player})
	if _nego_player == 2:
		busy2 = false
		if player2 != null:
			player2.frozen = false
	else:
		busy = false
		player.frozen = false
	match String(outcome.get("result", "")):
		Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT:
			var qty := maxi(1, int(outcome.get("quantity", 1)))
			session_summary["sales"] = int(session_summary["sales"]) + qty
			session_summary["revenue"] = int(session_summary["revenue"]) + int(outcome.get("price", 0))
			var unit_price := int(outcome.get("price", 0)) / qty
			var remainder := int(outcome.get("price", 0)) - unit_price * qty
			for i in range(qty):
				(session_summary["sold"] as Array).append({"item": _nego_item, "price": unit_price + (remainder if i == 0 else 0)})
			if bool(outcome.get("perfect", false)):
				session_summary["perfect"] = int(session_summary["perfect"]) + 1
		_:
			session_summary["left"] = int(session_summary["left"]) + 1
	if negotiating != null and is_instance_valid(negotiating):
		var result := String(outcome.get("result", ""))
		var emote := String(outcome.get("emote", "unhappy" if result == Negotiation.RESULT_LEAVE else "neutral"))
		negotiating.show_emote(emote, 2.2)
		var response := String(outcome.get("message", ""))
		if response != "":
			_speech(negotiating, response)
		if result in [Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT]:
			var shopkeeper: Node2D = player2 if _nego_player == 2 and player2 != null else player
			UIKit.gold_popup(shopkeeper, int(outcome.get("price", 0)))
		negotiating.resume_after_negotiation()
	negotiating = null
	_sync_customer_activity_pause()
	hud.refresh()
	if Net.is_host():
		Net.sync_managers(["economy", "inventory", "relationships", "game_state"])
	_open_next_negotiation()


func _end_session() -> void:
	session_active = false
	# snapshot the whole day's sales BEFORE advancing (rollover clears the log)
	var day_sold: Array = EconomyManager.day_sales.duplicate(true)
	if session_boom_id != "":
		BoomManager.complete_shop_session()
	var events := TimeManager.advance(TimeManager.activity_cost("open_shop"))
	if Net.is_online():
		# only the host simulates sessions; everyone presents the debrief
		Net.sync_all()
		Net.broadcast_scene_event("session_ended", {"events": events,
			"summary": session_summary.duplicate(true), "day_sold": day_sold})
		return
	_present_session_end(events, session_summary, day_sold)


func _present_session_end(events: Array[String], summary: Dictionary, day_sold: Array) -> void:
	if "new_day" in events:
		# the day rolled over: the full-screen day transition replaces the
		# little summary modal + Patch popup (it contains both)
		busy = false
		var day_summary := summary.duplicate(true)
		day_summary["sold"] = day_sold
		var total := 0
		for e: Dictionary in day_sold:
			total += int(e.get("price", 0))
		day_summary["sales"] = day_sold.size()
		day_summary["revenue"] = total
		DayTransition.show_transition(self, TimeManager.day - 1, day_summary, func() -> void:
			hud.refresh()
			if StoryEventManager.has_pending():
				SceneRouter.go("story", {"return_to": "shop"})
			else:
				DayBriefing.maybe_show(self))
		return
	# a period passed but the day goes on: same info panel, single sky —
	# players stay up to date with the Fade after every stretch of the day
	busy = false
	DayTransition.show_period(self, summary, func() -> void:
		hud.refresh()
		if "deadline_failed" in events:
			SceneRouter.go("story", {"failure": true})
		elif StoryEventManager.has_pending():
			SceneRouter.go("story", {"return_to": "shop"})
		else:
			DayBriefing.maybe_show(self))


func _show_boom_banner(customer_count: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 38
	add_child(layer)
	var panel := UIKit.ornate_panel(Vector2(430, 0))
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 50
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	var title := UIKit.label("BOOM!  %s" % session_boom_name, 18, UIKit.COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var detail := UIKit.label("%d customers are arriving in fast waves. Keep the displays stocked!" % customer_count, 10, UIKit.COL_INK)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(detail)
	var tween := layer.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)
