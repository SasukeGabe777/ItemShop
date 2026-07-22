class_name GameHUD
extends CanvasLayer
## Persistent top bar: day/period/chapter, gold, deadline progress, market
## events, and pending order count. Also hosts the pause menu.

const HELP_ENCYCLOPEDIA_SCRIPT := preload("res://scripts/ui/help_encyclopedia_panel.gd")

var day_label: Label
var period_label: Label
var period_pips: Array[TextureRect] = []
var period_portraits: Array[TextureRect] = []
var period_plate_labels: Array[Label] = []
var gold_label: Label
var deadline_label: Label
var market_label: Label
var orders_label: Label


const HUD_BAR := "res://assets/shared/ui/processed/hud_bar.png"
# sliced from daycycle.png: one sky per period, plus circular portraits
const DAY_THUMB := "res://assets/shared/ui/backgrounds/processed/daycycle_%s.png"
const DAY_PORTRAIT := "res://assets/shared/ui/backgrounds/processed/portrait_%s.png"
const PERIOD_KEYS := ["morning", "afternoon", "evening", "night"]


func _ready() -> void:
	layer = 20
	var bar := UIKit.panel()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# ornate white bar + light theme, matching the menus
	if ResourceLoader.exists(HUD_BAR):
		var style := StyleBoxTexture.new()
		style.texture = load(HUD_BAR)
		style.texture_margin_left = 14
		style.texture_margin_right = 14
		style.texture_margin_top = 7
		style.texture_margin_bottom = 7
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		bar.add_theme_stylebox_override("panel", style)
		bar.theme = UIKit.light_theme()
	add_child(bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	bar.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	day_label = UIKit.label("", 9)
	row.add_child(day_label)
	period_label = UIKit.label("", 11, UIKit.COL_ACCENT)
	row.add_child(period_label)
	var gold_group := HBoxContainer.new()
	gold_group.add_theme_constant_override("separation", 1)
	gold_group.add_child(UIKit.gold_icon("small", Vector2(12, 10)))
	gold_label = UIKit.label("", 11, UIKit.COL_ACCENT)
	gold_group.add_child(gold_label)
	row.add_child(gold_group)
	# the stakes read large — this is the Fade's countdown
	deadline_label = UIKit.label("", 11)
	row.add_child(deadline_label)
	row.add_child(UIKit.spacer(false))
	# day-cycle skies sit on the right, before the Menu button
	var pip_box := HBoxContainer.new()
	pip_box.add_theme_constant_override("separation", 3)
	row.add_child(pip_box)
	for i in range(TimeManager.periods_per_day()):
		var pip := TextureRect.new()
		var key: String = PERIOD_KEYS[mini(i, PERIOD_KEYS.size() - 1)]
		if ResourceLoader.exists(DAY_THUMB % key):
			pip.texture = load(DAY_THUMB % key)
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pip.clip_contents = true
		pip.custom_minimum_size = Vector2(26, 15)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip_box.add_child(pip)
		period_pips.append(pip)
	row.add_child(UIKit.button("Menu", _open_pause, 8))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	vb.add_child(row2)
	orders_label = UIKit.label("", 8, UIKit.COL_DIM)
	row2.add_child(orders_label)
	market_label = UIKit.label("", 8, UIKit.COL_DIM)
	market_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_label.clip_text = true
	row2.add_child(market_label)
	# large circular sky portrait + time plate, top right of each player's
	# screen: one set in single player, a smaller pair per half in 2P so
	# both halves read identically
	var edges: Array[float] = [1.0]
	var psize := 86.0
	if MultiplayerState.enabled:
		edges = [0.5, 1.0]
		psize = 56.0
	for edge in edges:
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		portrait.anchor_left = edge
		portrait.anchor_right = edge
		portrait.anchor_top = 0.0
		portrait.anchor_bottom = 0.0
		portrait.offset_left = -psize - 10
		portrait.offset_right = -10
		portrait.offset_top = 52
		portrait.offset_bottom = 52 + psize
		portrait.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(portrait)
		period_portraits.append(portrait)
		var plate := UIKit.nameplate("", 9 if MultiplayerState.enabled else 11)
		period_plate_labels.append(plate.get_child(0))
		plate.anchor_left = edge
		plate.anchor_right = edge
		plate.anchor_top = 0.0
		plate.anchor_bottom = 0.0
		plate.offset_left = -psize - 16
		plate.offset_right = -4
		plate.offset_top = 54 + psize
		plate.offset_bottom = 76 + psize
		add_child(plate)
	EconomyManager.gold_changed.connect(func(_g: int) -> void: refresh())
	set_process(true)
	TimeManager.period_advanced.connect(func(_d: int, _p: int) -> void:
		refresh()
		_flash_period_banner())
	TimeManager.day_started.connect(func(_d: int) -> void: refresh())
	MarketManager.events_changed.connect(refresh)
	BoomManager.boom_changed.connect(refresh)
	InventoryManager.orders_changed.connect(refresh)
	BridgeManager.gate_repaired.connect(func(_w: String) -> void: refresh())
	refresh()


## The HUD draws above P2's SubViewport, so the corner portrait would sit on
## top of that half's (now full-half) menus — duck each half's portrait and
## time plate while a menu is open on that half.
func _process(_delta: float) -> void:
	for i in period_portraits.size():
		var vp: Viewport = get_viewport()
		if period_portraits.size() > 1 and i == 1:
			vp = MultiplayerState.p2_viewport()
			if vp == null:
				vp = get_viewport()
		var covered := UIKit.modal_open(vp)
		period_portraits[i].visible = not covered
		var plate := period_plate_labels[i].get_parent() as Control
		if plate != null:
			plate.visible = not covered


func refresh() -> void:
	var chap := TimeManager.chapter
	var world := ContentDatabase.world_for_chapter(chap)
	var world_name := String(world.get("name", "The Null Archive"))
	day_label.text = "Day %d/%d  |  Ch.%d %s" % [
		TimeManager.day, TimeManager.campaign_days(), chap, world_name]
	if GameState.endless_mode:
		day_label.text = "Day %d  |  Endless" % TimeManager.day
	period_label.text = TimeManager.period_name()
	var tip := "%s — period %d of %d today" % [
		TimeManager.period_name(), TimeManager.period + 1, TimeManager.periods_per_day()]
	period_label.tooltip_text = tip
	period_label.mouse_filter = Control.MOUSE_FILTER_STOP
	for i in range(period_pips.size()):
		period_pips[i].tooltip_text = tip
		if i < TimeManager.period:
			period_pips[i].modulate = Color(0.45, 0.45, 0.5, 0.9)   # spent
		elif i == TimeManager.period:
			period_pips[i].modulate = Color.WHITE                    # now
		else:
			period_pips[i].modulate = Color(0.6, 0.6, 0.7, 0.45)     # ahead
	var pkey: String = PERIOD_KEYS[clampi(TimeManager.period, 0, PERIOD_KEYS.size() - 1)]
	for portrait in period_portraits:
		if ResourceLoader.exists(DAY_PORTRAIT % pkey):
			portrait.texture = load(DAY_PORTRAIT % pkey)
		portrait.tooltip_text = tip
	for lbl in period_plate_labels:
		lbl.text = TimeManager.period_name()
	gold_label.text = "%d" % EconomyManager.gold
	if GameState.endless_mode or chap > 7:
		deadline_label.text = "The Fade looms..." if chap == 8 and not BridgeManager.fade_defeated else ""
	else:
		var wid := String(world.get("id", ""))
		var shard := "SHARD OK" if BridgeManager.has_shard(wid) else "shard needed"
		deadline_label.text = "Due day %d: %dg + %s" % [
			TimeManager.chapter_deadline_day(), BridgeManager.repair_cost(wid), shard]
		deadline_label.add_theme_color_override("font_color",
			UIKit.COL_GOOD if BridgeManager.has_shard(wid) and EconomyManager.gold >= BridgeManager.repair_cost(wid) else UIKit.COL_INK)
	orders_label.text = "Orders: %d/%d  |  Returning: %d" % [
		InventoryManager.orders.size(), InventoryManager.order_capacity(),
		InventoryManager.due_orders().size()]
	var events := MarketManager.active_event_names()
	var market_text := "Market: " + (", ".join(events) if not events.is_empty() else "calm")
	market_label.text = ("BOOM: %s (%d session%s)  |  " % [BoomManager.display_name(), BoomManager.sessions_left,
		"" if BoomManager.sessions_left == 1 else "s"] if BoomManager.is_active() else "") + market_text
	market_label.add_theme_color_override("font_color", UIKit.COL_BAD if BoomManager.is_active() else UIKit.COL_DIM)


var _period_banner: Control = null


## Brief center-screen banner whenever the period changes: the new sky plus
## "Afternoon — period 2 of 4", so time passing is impossible to miss.
func _flash_period_banner() -> void:
	if _period_banner != null and is_instance_valid(_period_banner):
		_period_banner.queue_free()
	var key: String = PERIOD_KEYS[clampi(TimeManager.period, 0, PERIOD_KEYS.size() - 1)]
	var banner := PanelContainer.new()
	banner.theme = UIKit.light_theme()
	if ResourceLoader.exists(HUD_BAR):
		var style := StyleBoxTexture.new()
		style.texture = load(HUD_BAR)
		style.texture_margin_left = 14
		style.texture_margin_right = 14
		style.texture_margin_top = 7
		style.texture_margin_bottom = 7
		style.set_content_margin_all(10)
		banner.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	banner.add_child(row)
	var sky := TextureRect.new()
	if ResourceLoader.exists(DAY_THUMB % key):
		sky.texture = load(DAY_THUMB % key)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.clip_contents = true
	sky.custom_minimum_size = Vector2(52, 30)
	row.add_child(sky)
	row.add_child(UIKit.label("%s — period %d of %d" % [
		TimeManager.period_name(), TimeManager.period + 1, TimeManager.periods_per_day()], 15, UIKit.COL_ACCENT))
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_top = 60
	banner.modulate.a = 0.0
	add_child(banner)
	_period_banner = banner
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	# stay up while Patch is talking or a menu covers the screen, and for at
	# least a couple of seconds either way, so the change actually registers
	var age := {"t": 0.0}
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	banner.add_child(timer)
	timer.timeout.connect(func() -> void:
		age["t"] += 0.25
		var hold := UIKit.modal_open() or get_tree().get_first_node_in_group("patch_speaking") != null
		if age["t"] >= 2.2 and not hold:
			timer.stop()
			var out := banner.create_tween()
			out.tween_property(banner, "modulate:a", 0.0, 0.5)
			out.tween_callback(banner.queue_free))


## Start/Back (the "menu" action) opens the pause menu on a pad — the Menu
## button is no longer reachable via stray A presses.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and not UIKit.modal_open() and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_open_pause()


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
			text += "  (day %d, %d)" % [int(summary["day"]), int(summary["gold"])]
		var save_button := UIKit.button(text, func() -> void:
			SaveManager.save_to_slot(slot)
			close.call())
		if not summary.is_empty():
			save_button.icon = UIKit.gold_texture("small")
		vb.add_child(save_button)
	var auto := SaveManager.autosave_summary()
	if not auto.is_empty():
		vb.add_child(UIKit.label("Autosaved: Day %d, %s" % [int(auto["day"]),
			String(auto["period_name"])], 9, UIKit.COL_DIM))
	vb.add_child(UIKit.hsep())
	vb.add_child(UIKit.button("Help & Encyclopedia", func() -> void:
		close.call()
		_open_help_encyclopedia()))
	vb.add_child(UIKit.button("Music: %s" % ("muted" if AudioManager.muted else "on"), func() -> void:
		AudioManager.set_muted(not AudioManager.muted)
		close.call()))
	vb.add_child(UIKit.button("Quit to main menu", func() -> void:
		close.call()
		SceneRouter.go("main_menu")))
	vb.add_child(UIKit.button("Resume", close))


func _open_orders() -> void:
	_open_help_encyclopedia()


func _open_help_encyclopedia() -> void:
	add_child(HELP_ENCYCLOPEDIA_SCRIPT.new())
