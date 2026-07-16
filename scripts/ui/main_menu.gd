extends Control
## Title screen: the supplied key art fills the screen and real buttons sit on
## its menu rows (New Game / Load / Config / Extras). Falls back to a plain
## menu when the art is missing.

const ART_PATH := "res://assets/shared/ui/titlescreen.png"

## Scene-root Controls are not reliably auto-sized, so all UI lives in a
## CanvasLayer with a full-rect Control (same pattern as UIKit.modal).
var ui_root: Control


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
	# invisible-but-highlightable buttons over the art's four menu rows
	var rows: Array = [
		["New Game", 0.625, _on_new_game],
		["Load", 0.680, _on_load],
		["Config", 0.734, _on_config],
		["Extras", 0.788, _on_extras],
	]
	for row: Array in rows:
		var b := Button.new()
		b.flat = true
		b.text = ""
		b.anchor_left = 0.125
		b.anchor_right = 0.54
		b.anchor_top = float(row[1])
		b.anchor_bottom = float(row[1]) + 0.05
		b.offset_left = 0; b.offset_right = 0; b.offset_top = 0; b.offset_bottom = 0
		b.tooltip_text = String(row[0])
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1, 1, 1, 0.18)
		hover.set_corner_radius_all(3)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("focus", hover)
		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color(1, 1, 1, 0.3)
		b.add_theme_stylebox_override("pressed", pressed_style)
		b.pressed.connect(Callable(row[2]))
		ui_root.add_child(b)
	var quit_btn := UIKit.button("Quit", func() -> void: get_tree().quit(), 9)
	quit_btn.flat = true
	quit_btn.anchor_left = 0.94
	quit_btn.anchor_right = 0.995
	quit_btn.anchor_top = 0.015
	quit_btn.anchor_bottom = 0.07
	quit_btn.offset_left = 0; quit_btn.offset_right = 0; quit_btn.offset_top = 0; quit_btn.offset_bottom = 0
	ui_root.add_child(quit_btn)


func _on_new_game() -> void:
	var parts := UIKit.modal(self, "New game — choose a slot")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	for slot in range(1, 4):
		var summary := SaveManager.slot_summary(slot)
		var text := "Slot %d — empty" % slot
		if not summary.is_empty():
			text = "Slot %d — Day %d, %dg (will be overwritten)" % [slot, int(summary["day"]), int(summary["gold"])]
		vb.add_child(UIKit.button(text, func() -> void: SceneRouter.start_new_campaign(slot)))
	vb.add_child(UIKit.button("Cancel", func() -> void: layer.queue_free()))


func _on_load() -> void:
	var parts := UIKit.modal(self, "Continue")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var any := false
	for slot in range(1, 4):
		var summary := SaveManager.slot_summary(slot)
		if summary.is_empty():
			continue
		any = true
		var desc := "Slot %d — Day %d, Ch.%d, %dg%s" % [slot, int(summary["day"]), int(summary["chapter"]), int(summary["gold"]), " (Endless)" if bool(summary["endless"]) else ""]
		var row := HBoxContainer.new()
		var b := UIKit.button(desc, func() -> void: SceneRouter.continue_campaign(slot))
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
