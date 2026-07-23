extends Control
## Title screen: the supplied key art fills the screen and real buttons sit on
## its menu rows (New Game / Load / Config / Extras). Falls back to a plain
## menu when the art is missing.

const ART_PATH := "res://assets/shared/ui/titlescreenupdated.png"
const BAR_BLUE := "res://assets/shared/ui/processed/bar_blue.png"
const CURSOR_HAND := "res://assets/shared/ui/processed/cursor_hand.png"

## Scene-root Controls are not reliably auto-sized, so all UI lives in a
## CanvasLayer with a full-rect Control (same pattern as UIKit.modal).
var ui_root: Control
var hand_cursor: TextureRect
var _hand_tween: Tween
var _menu_buttons: Array[Button] = []
var _art_size := Vector2(1672, 941)

# menu bar positions as fractions of the ART image (measured off the png)
const BAR_FRACTIONS := {
	"left": 0.0969, "right": 0.5263, "height": 0.0638,
	"tops": [0.579, 0.659, 0.739, 0.820],
}


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_root)
	AudioManager.play_track("main_menu")
	if ResourceLoader.exists(ART_PATH):
		_build_art_menu()
	else:
		_build_plain_menu()


func _build_art_menu() -> void:
	var art := TextureRect.new()
	art.texture = load(ART_PATH)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ui_root.add_child(art)
	# labeled buttons on the art's blank menu bars; the supplied blue bar is
	# the selected state and the supplied hand cursor points at the selection
	var blue_style: StyleBoxTexture = null
	if ResourceLoader.exists(BAR_BLUE):
		blue_style = StyleBoxTexture.new()
		blue_style.texture = load(BAR_BLUE)
		blue_style.texture_margin_left = 16
		blue_style.texture_margin_right = 16
		blue_style.texture_margin_top = 4
		blue_style.texture_margin_bottom = 4
	var empty_style := StyleBoxEmpty.new()
	var rows: Array = [
		["NEW GAME", _on_new_game],
		["LOAD", _on_load],
		["CONFIG", _on_config],
		["EXTRAS", _on_extras],
	]
	var first_btn: Button = null
	for row: Array in rows:
		var b := Button.new()
		b.text = String(row[0])
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color("#3a3f52"))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.add_theme_stylebox_override("normal", empty_style)
		if blue_style != null:
			b.add_theme_stylebox_override("hover", blue_style)
			b.add_theme_stylebox_override("focus", blue_style)
			b.add_theme_stylebox_override("pressed", blue_style)
		else:
			var hover := StyleBoxFlat.new()
			hover.bg_color = Color(0.3, 0.45, 0.8, 0.85)
			hover.set_corner_radius_all(4)
			b.add_theme_stylebox_override("hover", hover)
			b.add_theme_stylebox_override("focus", hover)
			b.add_theme_stylebox_override("pressed", hover)
		b.pressed.connect(func() -> void: AudioManager.play_sfx("menu_select", -4.0))
		b.pressed.connect(Callable(row[1]))
		b.mouse_entered.connect(b.grab_focus)  # hover and keyboard share one selection
		b.focus_entered.connect(func() -> void:
			AudioManager.play_sfx("menu_movement", -6.0)
			_point_hand_at(b))
		ui_root.add_child(b)
		_menu_buttons.append(b)
		if first_btn == null:
			first_btn = b
	if ResourceLoader.exists(CURSOR_HAND):
		hand_cursor = TextureRect.new()
		hand_cursor.texture = load(CURSOR_HAND)
		hand_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hand_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hand_cursor.size = Vector2(24, 20)
		hand_cursor.z_index = 5
		ui_root.add_child(hand_cursor)
	if first_btn != null:
		first_btn.grab_focus.call_deferred()
	# 2P split-screen toggle mirrors the Quit button in the opposite corner —
	# ornate bar styling, or it vanishes into the pale sky art
	var mp_btn := UIKit.button("2 PLAYERS: %s" % ("ON" if MultiplayerState.enabled else "OFF"), Callable(), 10)
	var ui_scale_btn := UIKit.button("UI SIZE: %s" % MultiplayerState.ui_scale_label(), Callable(), 10)
	mp_btn.theme = UIKit.light_theme()
	mp_btn.anchor_left = 0.005
	mp_btn.anchor_right = 0.155
	mp_btn.anchor_top = 0.015
	mp_btn.anchor_bottom = 0.075
	mp_btn.offset_left = 0
	mp_btn.offset_right = 0
	mp_btn.offset_top = 0
	mp_btn.offset_bottom = 0
	mp_btn.pressed.connect(func() -> void:
		MultiplayerState.set_enabled(not MultiplayerState.enabled)
		mp_btn.text = "2 PLAYERS: %s" % ("ON" if MultiplayerState.enabled else "OFF")
		ui_scale_btn.visible = MultiplayerState.enabled)
	ui_root.add_child(mp_btn)
	ui_scale_btn.theme = UIKit.light_theme()
	ui_scale_btn.anchor_left = 0.16
	ui_scale_btn.anchor_right = 0.31
	ui_scale_btn.anchor_top = 0.015
	ui_scale_btn.anchor_bottom = 0.075
	ui_scale_btn.offset_left = 0
	ui_scale_btn.offset_right = 0
	ui_scale_btn.offset_top = 0
	ui_scale_btn.offset_bottom = 0
	ui_scale_btn.visible = MultiplayerState.enabled
	ui_scale_btn.pressed.connect(func() -> void:
		MultiplayerState.cycle_ui_scale()
		ui_scale_btn.text = "UI SIZE: %s" % MultiplayerState.ui_scale_label())
	ui_root.add_child(ui_scale_btn)
	var quit_btn := UIKit.button("Quit", func() -> void: get_tree().quit(), 9)
	quit_btn.flat = true
	quit_btn.anchor_left = 0.94
	quit_btn.anchor_right = 0.995
	quit_btn.anchor_top = 0.015
	quit_btn.anchor_bottom = 0.07
	quit_btn.offset_left = 0; quit_btn.offset_right = 0; quit_btn.offset_top = 0; quit_btn.offset_bottom = 0
	ui_root.add_child(quit_btn)
	var tex: Texture2D = art.texture
	_art_size = Vector2(tex.get_width(), tex.get_height())
	get_viewport().size_changed.connect(_layout_menu_buttons)
	_layout_menu_buttons.call_deferred()


## Buttons must sit on the art's painted bars, so lay them out from the art's
## actual drawn rect (KEEP_ASPECT_COVERED math), not viewport fractions.
func _layout_menu_buttons() -> void:
	var vp := ui_root.get_viewport_rect().size
	var art_scale := maxf(vp.x / _art_size.x, vp.y / _art_size.y)
	var drawn := _art_size * art_scale
	var origin := (vp - drawn) / 2.0
	var tops: Array = BAR_FRACTIONS["tops"]
	for i in range(_menu_buttons.size()):
		var b := _menu_buttons[i]
		b.position = origin + Vector2(float(BAR_FRACTIONS["left"]), float(tops[i])) * drawn
		b.size = Vector2((float(BAR_FRACTIONS["right"]) - float(BAR_FRACTIONS["left"])) * drawn.x, float(BAR_FRACTIONS["height"]) * drawn.y)
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and focused in _menu_buttons:
		_point_hand_at(focused)


func _point_hand_at(btn: Button) -> void:
	if hand_cursor == null:
		return
	if _hand_tween != null and _hand_tween.is_valid():
		_hand_tween.kill()
	var target := Vector2(btn.global_position.x - 27.0, btn.global_position.y + btn.size.y / 2.0 - 10.0)
	hand_cursor.global_position = target
	# gentle horizontal bob toward the selected row
	_hand_tween = hand_cursor.create_tween().set_loops()
	_hand_tween.tween_property(hand_cursor, "global_position:x", target.x + 4.0, 0.35).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(hand_cursor, "global_position:x", target.x, 0.35).set_trans(Tween.TRANS_SINE)


func _on_new_game() -> void:
	var parts := UIKit.modal(self, "New game — choose a slot")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	for slot in range(1, 4):
		var summary := SaveManager.slot_summary(slot)
		var text := "Slot %d — empty" % slot
		if not summary.is_empty():
			text = "Slot %d — Day %d, %d (will be overwritten)" % [slot, int(summary["day"]), int(summary["gold"])]
		var slot_button := UIKit.button(text, func() -> void: SceneRouter.start_new_campaign(slot))
		if not summary.is_empty():
			slot_button.icon = UIKit.gold_texture("small")
		vb.add_child(slot_button)
	vb.add_child(UIKit.button("Cancel", func() -> void: layer.queue_free()))


func _on_load() -> void:
	var parts := UIKit.modal(self, "Continue")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var any := false
	# the autosave is taken at every day portion, so it is usually the newest
	# thing here — offer it first
	var auto := SaveManager.autosave_summary()
	if not auto.is_empty():
		any = true
		var auto_button := UIKit.button("Autosave — Day %d %s, Ch.%d, %d%s" % [
			int(auto["day"]), String(auto["period_name"]), int(auto["chapter"]),
			int(auto["gold"]), " (Endless)" if bool(auto["endless"]) else ""],
			func() -> void: SceneRouter.continue_autosave())
		auto_button.icon = UIKit.gold_texture("small")
		vb.add_child(auto_button)
		vb.add_child(UIKit.hsep())
	for slot in range(1, 4):
		var summary := SaveManager.slot_summary(slot)
		if summary.is_empty():
			continue
		any = true
		var desc := "Slot %d — Day %d %s, Ch.%d, %d%s" % [slot, int(summary["day"]), String(summary["period_name"]), int(summary["chapter"]), int(summary["gold"]), " (Endless)" if bool(summary["endless"]) else ""]
		var row := HBoxContainer.new()
		var b := UIKit.button(desc, func() -> void: SceneRouter.continue_campaign(slot))
		b.icon = UIKit.gold_texture("small")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		row.add_child(UIKit.button("X", func() -> void:
			SaveManager.delete_slot(slot)
			layer.queue_free()
			_on_load()))
		vb.add_child(row)
	if not any:
		vb.add_child(UIKit.label("No saved games yet.", 10, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Cancel", func() -> void: layer.queue_free()))


func _on_config() -> void:
	var parts := UIKit.modal(self, "Config")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	vb.add_child(UIKit.button("Music: %s" % ("muted" if AudioManager.muted else "on"), func() -> void:
		AudioManager.set_muted(not AudioManager.muted)
		layer.queue_free()
		_on_config()))
	vb.add_child(UIKit.button("Fullscreen: %s" % ("on" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "off"), func() -> void:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		layer.queue_free()
		_on_config()))
	vb.add_child(UIKit.label("Move WASD/arrows | Interact E | Attack J | Special K", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.label("Dodge L | Item I | Finisher U | Debug console F3", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Close", func() -> void: layer.queue_free()))


func _on_extras() -> void:
	var parts := UIKit.modal(self, "Extras — credits")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	for line in [
		"Sprites ripped from The Spriters Resource:",
		"KH: Chain of Memories — Nemu, Oshio, Omega Heartless & others",
		"Mario & Luigi: Superstar Saga — A.J. Nitro",
		"OMORI Hero sheet, FF Record Keeper sheets — respective rippers",
		"ChronoType font — Caveras (CC BY-NC-SA)",
		"Full attribution: credits/ASSET_CREDITS.csv",
		"",
		"A private, non-commercial fan prototype.",
	]:
		vb.add_child(UIKit.label(String(line), 9, UIKit.COL_DIM if line != "" else UIKit.COL_TEXT))
	vb.add_child(UIKit.button("Close", func() -> void: layer.queue_free()))


## Fallback when the title art is absent.
func _build_plain_menu() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(center)
	var panel := UIKit.panel(Vector2(360, 0))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := UIKit.label(GameState.game_title, 20, UIKit.COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	vb.add_child(UIKit.button("New game", _on_new_game))
	vb.add_child(UIKit.button("Load", _on_load))
	vb.add_child(UIKit.button("Config", _on_config))
	vb.add_child(UIKit.button("Quit", func() -> void: get_tree().quit()))
