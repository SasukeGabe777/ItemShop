extends Node2D
## The Crossroads hub: walkable plaza with the shop, market, workshop, guild,
## home and the seven World Bridge gates.

var player: TownPlayer
var player2: TownPlayer = null
var hud: GameHUD
var prompt: Label
var prompt2: Label = null
var busy: bool = false   # player 1 has a panel / story open
var busy2: bool = false  # player 2 has a panel open (their half only)


func _ready() -> void:
	AudioManager.play_track("crossroads_night" if TimeManager.period >= 3 else "crossroads_day")
	_build_ground()
	_build_buildings()
	_build_gates()
	player = TownPlayer.new()
	player.position = SceneRouter.last_town_position if SceneRouter.last_town_position != Vector2.ZERO else Vector2(320, 240)
	add_child(player)
	player.add_child(ZoomCamera.new())
	PatchFollower.attach(self, player)
	hud = GameHUD.new()
	add_child(hud)
	prompt = UIKit.label("", 10, UIKit.COL_ACCENT)
	prompt.z_index = 60
	add_child(prompt)
	if MultiplayerState.enabled:
		player2 = MultiplayerState.attach_split(self, player)
		prompt2 = UIKit.label("", 10, UIKit.COL_ACCENT)
		prompt2.z_index = 60
		add_child(prompt2)
	if StoryEventManager.has_pending():
		_play_story()
	else:
		DayBriefing.maybe_show(self)


func _build_ground() -> void:
	Scenery.tiled_floor(self, Rect2(-200, -200, 1040, 880), "floor_cobble", Color("#3a4257"), -10, Color(0.4, 0.42, 0.58))
	Scenery.tiled_floor(self, Rect2(120, 80, 400, 340), "floor_cobble", Color("#4a5570"), -9)
	# plaza dressing: lamps at the corners, crates by the market
	Scenery.prop(self, Vector2(140, 100), "lamp_lit")
	Scenery.prop(self, Vector2(500, 100), "lamp_lit")
	Scenery.prop(self, Vector2(140, 415), "lamp_lit")
	Scenery.prop(self, Vector2(500, 415), "lamp_lit")
	Scenery.prop(self, Vector2(320, 250), "rug", -8)
	# (the broken-bridge plank strip now lives inside the World Bridge menu)


const LOBBY_SPRITE := "res://assets/locations/processed/lobby/%s.png"


func _door(pos: Vector2, size: Vector2, color: Color, title: String, action: String, sprite_name: String = "") -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var h := size / 2.0
	var tex_path := LOBBY_SPRITE % sprite_name
	if sprite_name != "" and ResourceLoader.exists(tex_path):
		# building art with its base at the door rect's bottom edge
		var spr := Sprite2D.new()
		spr.texture = load(tex_path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(0, h.y - spr.texture.get_height() / 2.0)
		body.add_child(spr)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
		poly.color = color
		body.add_child(poly)
	# ornate nameplate centered directly under the location
	var plate := UIKit.nameplate(title)
	body.add_child(plate)
	_center_plate(plate, Vector2(0, h.y + 4.0))
	add_child(body)
	var ic := InteractionComponent.new()
	ic.prompt = title
	ic.action_id = action
	ic.position = pos + Vector2(0, h.y + 12)
	ic.add_to_group("interactables")
	add_child(ic)


func _build_buildings() -> void:
	_door(Vector2(200, 150), Vector2(90, 60), Color("#8a5a34"), "Item Shop", "shop", "itemshop")
	_door(Vector2(440, 150), Vector2(90, 60), Color("#4a7a54"), "Market", "market", "market")
	_door(Vector2(200, 360), Vector2(90, 60), Color("#5a5a8a"), "Workshop", "workshop", "workshop")
	_door(Vector2(440, 360), Vector2(90, 60), Color("#8a4a5a"), "Adventurers' Guild", "guild", "guild")
	_door(Vector2(320, 470), Vector2(70, 50), Color("#6a6a4a"), "Home (rest)", "home", "home")


func _build_gates() -> void:
	var ic := InteractionComponent.new()
	ic.prompt = "World Bridge Gates"
	ic.action_id = "gates"
	ic.position = Vector2(320, 90)
	ic.add_to_group("interactables")
	add_child(ic)
	var tex_path := LOBBY_SPRITE % "worldbridge"
	if ResourceLoader.exists(tex_path):
		var spr := Sprite2D.new()
		spr.texture = load(tex_path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(320, 46)
		add_child(spr)
	var plate := UIKit.nameplate("World Bridge")
	add_child(plate)
	_center_plate(plate, Vector2(320, 94))


## Containers only know their real size after a layout pass — centering with
## reset_size() alone leaves long titles offset to the right.
func _center_plate(plate: Control, top_center: Vector2) -> void:
	(func() -> void:
		if is_instance_valid(plate):
			plate.position = top_center - Vector2(plate.size.x / 2.0, 0)).call_deferred()


func _process(_delta: float) -> void:
	_player_frame(player, prompt, "", busy, 1)
	if player2 != null:
		# watchdog: if P2 is flagged busy but nothing is actually open on
		# their half, unstick them (guards against any menu-state desync)
		if busy2 and not UIKit.modal_open(MultiplayerState.p2_viewport()):
			busy2 = false
			player2.frozen = false
		_player_frame(player2, prompt2, "p2_", busy2, 2)


func _player_frame(p: TownPlayer, pr: Label, prefix: String, p_busy: bool, idx: int) -> void:
	if p_busy or p == null:
		if pr != null:
			pr.visible = false
		return
	var ic := p.nearest_interactable()
	pr.visible = ic != null
	if ic != null:
		pr.text = "[%s] %s" % [UIKit.interact_key(), ic.prompt]
		pr.position = p.position + Vector2(-30, -34)
	var vp := get_viewport() if idx == 1 else MultiplayerState.p2_viewport()
	if Input.is_action_just_pressed(prefix + "interact") and ic != null and not UIKit.modal_open(vp):
		_activate(ic.action_id, idx)


func _activate(action: String, who: int = 1) -> void:
	match action:
		"shop":
			if MultiplayerState.enabled and not MultiplayerState.ready_up("enter_shop", who):
				_toast("Entering the shop — %d/2 ready" % MultiplayerState.ready_count("enter_shop"),
					player if who == 1 else player2)
				return
			MultiplayerState.clear_ready("enter_shop")
			SceneRouter.last_town_position = player.position
			SceneRouter.go("shop")
		"market":
			_open_panel(MarketPanel.new(), who)
		"workshop":
			_open_panel(WorkshopPanel.new(), who)
		"guild":
			_open_panel(GuildPanel.new(), who)
		"gates":
			_open_panel(GatesPanel.new(), who)
		"home":
			if MultiplayerState.enabled and not MultiplayerState.ready_up("rest", who):
				_toast("Resting — %d/2 ready" % MultiplayerState.ready_count("rest"),
					player if who == 1 else player2)
				return
			MultiplayerState.clear_ready("rest")
			UIKit.confirm_time_cost(self, "Resting", TimeManager.activity_cost("rest"), func() -> void:
				var day_sold: Array = EconomyManager.day_sales.duplicate(true)
				var events := TimeManager.advance(TimeManager.activity_cost("rest"))
				_after_time_events(events, day_sold))


func _toast(text: String, over: Node2D) -> void:
	var lbl := UIKit.label(text, 10, UIKit.COL_ACCENT)
	lbl.position = (over.position if over != null else Vector2(280, 240)) + Vector2(-60, -48)
	lbl.z_index = 70
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


func _open_panel(panel: Node, who: int = 1) -> void:
	panel.set_meta("owner_player", who)
	if who == 2:
		busy2 = true
		player2.frozen = true
		MultiplayerState.menu_parent(2, self).add_child(panel)
	else:
		busy = true
		player.frozen = true
		add_child(panel)
	if panel.has_signal("closed"):
		panel.connect("closed", func() -> void:
			if who == 2:
				busy2 = false
				if player2 != null:
					player2.frozen = false
				return
			busy = false
			player.frozen = false
			hud.refresh()
			if StoryEventManager.has_pending():
				_play_story())


func _after_time_events(events: Array[String], day_sold: Array = []) -> void:
	hud.refresh()
	if "deadline_failed" in events:
		SceneRouter.go("story", {"failure": true})
		return
	if "new_day" in events:
		var summary := {}
		if not day_sold.is_empty():
			var total := 0
			for e: Dictionary in day_sold:
				total += int(e.get("price", 0))
			summary = {"sales": day_sold.size(), "revenue": total, "sold": day_sold}
		DayTransition.show_transition(self, TimeManager.day - 1, summary, _resume_new_day)
		return
	DayTransition.show_period(self, {}, _resume_new_day)


func _resume_new_day() -> void:
	AudioManager.play_track("crossroads_night" if TimeManager.period >= 3 else "crossroads_day")
	if StoryEventManager.has_pending():
		_play_story()
	else:
		DayBriefing.maybe_show(self)


func _play_story() -> void:
	SceneRouter.last_town_position = player.position
	SceneRouter.go("story", {"return_to": "town"})
