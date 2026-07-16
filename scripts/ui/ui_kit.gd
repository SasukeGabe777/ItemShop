class_name UIKit
## Small helpers for building consistent code-driven UI with the shared palette.

const COL_BG := Color("#1c1e30")
const COL_PANEL := Color("#282b44")
const COL_ACCENT := Color("#e8b84a")
const COL_TEXT := Color("#e8e8f0")
const COL_DIM := Color("#9aa0b8")
const COL_GOOD := Color("#7ad07a")
const COL_BAD := Color("#e07070")


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.border_color = COL_ACCENT.darkened(0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = min_size
	return p


static func label(text: String, size: int = 10, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func header(text: String) -> Label:
	return label(text, 14, COL_ACCENT)


static func button(text: String, on_press: Callable, size: int = 10) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func hsep() -> HSeparator:
	return HSeparator.new()


static func spacer(vertical: bool = true) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func scroll_list(min_size: Vector2) -> Array:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = min_size
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	return [sc, vb]


static func item_row(item_id: String, suffix: String, action_text: String, on_press: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.texture = ContentDatabase.item_texture(item_id)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var lbl := label("%s %s" % [ContentDatabase.item_name(item_id), suffix])
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.tooltip_text = String(ContentDatabase.get_item(item_id).get("desc", ""))
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(lbl)
	if action_text != "":
		row.add_child(button(action_text, on_press))
	return row


static func modal(parent: Node, title: String) -> Array:
	## Returns [layer, content_vbox]. Caller fills content and frees layer.
	var layer := CanvasLayer.new()
	layer.layer = 50
	parent.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var p := panel(Vector2(380, 0))
	center.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	if title != "":
		vb.add_child(header(title))
		vb.add_child(hsep())
	return [layer, vb]


## Time-cost confirmation required before any period-consuming activity.
static func confirm_time_cost(parent: Node, activity_label: String, periods: int, on_confirm: Callable) -> void:
	var parts := modal(parent, "Spend time?")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var now := "%s, Day %d" % [TimeManager.period_name(), TimeManager.day]
	vb.add_child(label("%s costs %d period%s." % [activity_label, periods, "s" if periods > 1 else ""]))
	vb.add_child(label("Now: %s" % now, 10, COL_DIM))
	var after_period := TimeManager.period + periods
	var after_day := TimeManager.day
	var names: Array = ContentDatabase.bal("period_names", ["Morning", "Afternoon", "Evening", "Night"])
	while after_period >= names.size():
		after_period -= names.size()
		after_day += 1
	vb.add_child(label("After: %s, Day %d" % [names[after_period], after_day], 10, COL_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(button("Confirm", func() -> void:
		layer.queue_free()
		on_confirm.call()))
	row.add_child(button("Cancel", func() -> void: layer.queue_free()))
	vb.add_child(row)
