extends Node2D
## The Crossroads hub: walkable plaza with the shop, market, workshop, guild,
## home and the seven World Bridge gates.

var player: TownPlayer
var hud: GameHUD
var prompt: Label
var busy: bool = false  # a panel or story scene is open


func _ready() -> void:
	AudioManager.play_track("crossroads_night" if TimeManager.period >= 3 else "crossroads_day")
	_build_ground()
	_build_buildings()
	_build_gates()
	player = TownPlayer.new()
	player.position = SceneRouter.last_town_position if SceneRouter.last_town_position != Vector2.ZERO else Vector2(320, 240)
	add_child(player)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	player.add_child(cam)
	hud = GameHUD.new()
	add_child(hud)
	prompt = UIKit.label("", 10, UIKit.COL_ACCENT)
	prompt.z_index = 60
	add_child(prompt)
	if StoryEventManager.has_pending():
		_play_story()


func _build_ground() -> void:
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(-200, -200), Vector2(840, -200), Vector2(840, 680), Vector2(-200, 680)])
	ground.color = Color("#3a4257")
	ground.z_index = -10
	add_child(ground)
	var plaza := Polygon2D.new()
	plaza.polygon = PackedVector2Array([Vector2(120, 80), Vector2(520, 80), Vector2(520, 420), Vector2(120, 420)])
	plaza.color = Color("#4a5570")
	plaza.z_index = -9
	add_child(plaza)
	# broken bridge visual at the top
	for i in range(7):
		var plank := Polygon2D.new()
		var x := 140.0 + i * 55.0
		plank.polygon = PackedVector2Array([Vector2(x, 40), Vector2(x + 40, 40), Vector2(x + 40, 70), Vector2(x, 70)])
		var world := ContentDatabase.world_for_chapter(i + 1)
		var repaired := BridgeManager.is_repaired(String(world.get("id", "")))
		plank.color = Color(String(world.get("accent_color", "#888888"))) if repaired else Color("#2a2d3f")
		add_child(plank)


func _door(pos: Vector2, size: Vector2, color: Color, title: String, action: String) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var poly := Polygon2D.new()
	var h := size / 2.0
	poly.polygon = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
	poly.color = color
	body.add_child(poly)
	var lbl := UIKit.label(title, 9)
	lbl.position = Vector2(-h.x, -h.y - 14)
	body.add_child(lbl)
	add_child(body)
	var ic := InteractionComponent.new()
	ic.prompt = title
	ic.action_id = action
	ic.position = pos + Vector2(0, h.y + 12)
	ic.add_to_group("interactables")
	add_child(ic)


func _build_buildings() -> void:
	_door(Vector2(200, 140), Vector2(90, 60), Color("#8a5a34"), "Item Shop", "shop")
	_door(Vector2(440, 140), Vector2(90, 60), Color("#4a7a54"), "Market", "market")
	_door(Vector2(200, 360), Vector2(90, 60), Color("#5a5a8a"), "Workshop", "workshop")
	_door(Vector2(440, 360), Vector2(90, 60), Color("#8a4a5a"), "Adventurers' Guild", "guild")
	_door(Vector2(320, 470), Vector2(70, 50), Color("#6a6a4a"), "Home (rest)", "home")


func _build_gates() -> void:
	var ic := InteractionComponent.new()
	ic.prompt = "World Bridge Gates"
	ic.action_id = "gates"
	ic.position = Vector2(320, 90)
	ic.add_to_group("interactables")
	add_child(ic)
	var lbl := UIKit.label("~ World Bridge ~", 10, UIKit.COL_ACCENT)
	lbl.position = Vector2(272, 90)
	add_child(lbl)


func _process(_delta: float) -> void:
	if busy or player == null:
		prompt.visible = false
		return
	var ic := player.nearest_interactable()
	prompt.visible = ic != null
	if ic != null:
		prompt.text = "[E] " + ic.prompt
		prompt.position = player.position + Vector2(-30, -34)
	if Input.is_action_just_pressed("interact") and ic != null:
		_activate(ic.action_id)


func _activate(action: String) -> void:
	match action:
		"shop":
			SceneRouter.last_town_position = player.position
			SceneRouter.go("shop")
		"market":
			_open_panel(MarketPanel.new())
		"workshop":
			_open_panel(WorkshopPanel.new())
		"guild":
			_open_panel(GuildPanel.new())
		"gates":
			_open_panel(GatesPanel.new())
		"home":
			UIKit.confirm_time_cost(self, "Resting", TimeManager.activity_cost("rest"), func() -> void:
				var events := TimeManager.advance(TimeManager.activity_cost("rest"))
				_after_time_events(events))


func _open_panel(panel: Node) -> void:
	busy = true
	player.frozen = true
	add_child(panel)
	if panel.has_signal("closed"):
		panel.connect("closed", func() -> void:
			busy = false
			player.frozen = false
			hud.refresh()
			if StoryEventManager.has_pending():
				_play_story())


func _after_time_events(events: Array[String]) -> void:
	hud.refresh()
	if "deadline_failed" in events:
		SceneRouter.go("story", {"failure": true})
		return
	AudioManager.play_track("crossroads_night" if TimeManager.period >= 3 else "crossroads_day")
	if StoryEventManager.has_pending():
		_play_story()


func _play_story() -> void:
	SceneRouter.last_town_position = player.position
	SceneRouter.go("story", {"return_to": "town"})
