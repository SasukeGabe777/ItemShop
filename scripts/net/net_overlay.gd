extends CanvasLayer
## Always-on-top status strip for online play: "reconnecting...", "waiting
## for the party...", "host paused". Lives under Net and keeps processing
## while the tree is paused.


var _label: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var strip := PanelContainer.new()
	strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	strip.offset_top = 8.0
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.92)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	strip.add_theme_stylebox_override("panel", style)
	add_child(strip)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color("ffd98f"))
	strip.add_child(_label)


func show_message(text: String) -> void:
	_label.text = text
	visible = true


func clear() -> void:
	visible = false
