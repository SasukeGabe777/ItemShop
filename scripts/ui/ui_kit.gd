class_name UIKit
## Small helpers for building consistent code-driven UI with the shared palette.

const COL_BG := Color("#1c1e30")
const COL_PANEL := Color("#282b44")
# Palette tuned to read on BOTH the dark HUD bar and the white ornate panels.
const COL_ACCENT := Color("#c8922a")
const COL_PROMPT := Color("#ffffff")
const COL_TEXT := Color("#e8e8f0")   # sentinel: labels with this color inherit the ambient theme
const COL_INK := Color("#2c3050")    # dark text used inside light panels
const COL_DIM := Color("#767d95")
const COL_GOOD := Color("#4a9a55")
const COL_BAD := Color("#c65555")

const PANEL_WIDE := "res://assets/shared/ui/processed/panel_wide.png"
const BAR_WHITE := "res://assets/shared/ui/processed/bar_white.png"
const BAR_BLUE := "res://assets/shared/ui/processed/bar_blue.png"
const GOLD_SMALL := "res://assets/shared/ui/processed/gold_coin_small.png"
const GOLD_MEDIUM := "res://assets/shared/ui/processed/gold_pile_medium.png"
const GOLD_LARGE := "res://assets/shared/ui/processed/gold_pile_large.png"
const BOND_PATTERN := "res://assets/shared/ui/processed/bond_%d.png"
const EMOTE_PATTERN := "res://assets/shared/ui/processed/emote_%s.png"

static var _light_theme: Theme = null
static var _open_modals := 0
static var _modals_by_viewport: Dictionary = {}  # viewport instance id -> count


## True while any UIKit.modal() is on screen. Gameplay code that polls raw
## actions (like "interact", which shares the pad's A button with ui_accept)
## must check this, or every press aimed at the modal also fires in-world.
## Pass a viewport to ask about one player's screen half in split-screen —
## P1's menu must never gate P2's world input, and vice versa.
static func modal_open(vp: Viewport = null) -> bool:
	if vp == null:
		return _open_modals > 0
	return int(_modals_by_viewport.get(vp.get_instance_id(), 0)) > 0


static func _count_modal(vp: Viewport, delta: int) -> void:
	_open_modals = maxi(0, _open_modals + delta)
	if vp == null:
		return
	var key := vp.get_instance_id()
	_modals_by_viewport[key] = maxi(0, int(_modals_by_viewport.get(key, 0)) + delta)


## ---- controller support -------------------------------------------------

static func pad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


## Key name shown in interact prompts: "A" on a controller, "E" otherwise.
static func interact_key() -> String:
	return "A" if pad_connected() else "E"


static func _first_button_in(node: Node) -> Button:
	if node.is_queued_for_deletion():
		return null
	if node is Button and (node as Button).visible and not (node as Button).disabled:
		return node
	for child in node.get_children():
		var b := _first_button_in(child)
		if b != null:
			return b
	return null


## Clears `list`'s children and calls `fill` to rebuild them, keeping the
## controller selector alive: when focus was inside the list, it is restored
## onto the same row index (clamped) of the rebuilt list. Without this, a
## rebuild frees the focused button and the pad selector vanishes.
static func rebuild_list(list: Node, fill: Callable) -> void:
	var row := -1
	if list.is_inside_tree():
		var focus := list.get_viewport().gui_get_focus_owner()
		if focus != null:
			var old := list.get_children()
			for i in old.size():
				if old[i] == focus or old[i].is_ancestor_of(focus):
					row = i
					break
	for child in list.get_children():
		child.queue_free()
	fill.call()
	if row < 0:
		return
	var rows := list.get_children().filter(func(c: Node) -> bool:
		return not c.is_queued_for_deletion())
	if rows.is_empty():
		return
	var b := _first_button_in(rows[clampi(row, 0, rows.size() - 1)])
	if b == null:
		for r: Node in rows:
			b = _first_button_in(r)
			if b != null:
				break
	if b != null:
		b.grab_focus()


## Focuses the first usable button under `root` (deferred, so it works right
## after building a menu) when a controller is plugged in — the D-pad and A
## button then drive every menu via Godot's built-in focus navigation.
static func focus_first_button(root: Node) -> void:
	if not pad_connected():
		return
	(func() -> void:
		if not is_instance_valid(root):
			return
		var b := _first_button_in(root)
		if b != null:
			b.grab_focus()).call_deferred()


## Theme for content inside the supplied white ornate panels: dark text and
## the white/blue bar textures as button states.
static func light_theme() -> Theme:
	if _light_theme != null:
		return _light_theme
	var t := Theme.new()
	t.set_color("font_color", "Label", COL_INK)
	t.set_color("font_color", "Button", COL_INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(COL_INK, 0.4))
	if ResourceLoader.exists(BAR_WHITE) and ResourceLoader.exists(BAR_BLUE):
		var normal := StyleBoxTexture.new()
		normal.texture = load(BAR_WHITE)
		var active := StyleBoxTexture.new()
		active.texture = load(BAR_BLUE)
		for sb: StyleBoxTexture in [normal, active]:
			sb.texture_margin_left = 16
			sb.texture_margin_right = 16
			sb.texture_margin_top = 4
			sb.texture_margin_bottom = 4
			sb.content_margin_left = 18
			sb.content_margin_right = 18
		t.set_stylebox("normal", "Button", normal)
		t.set_stylebox("disabled", "Button", normal)
		t.set_stylebox("hover", "Button", active)
		t.set_stylebox("focus", "Button", active)
		t.set_stylebox("pressed", "Button", active)
	_light_theme = t
	return t


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
	# COL_TEXT means "ambient": inherit white on dark HUD, ink inside light modals
	if color != COL_TEXT:
		l.add_theme_color_override("font_color", color)
	return l


## Bright in-world action text ("[E] Open the shop", "[A] Market", etc.).
## Kept separate from COL_ACCENT so menu headings and economy highlights retain
## their gold hierarchy while every keyboard/controller prompt stays legible.
static func interaction_prompt() -> Label:
	var l := label("", 10, COL_PROMPT)
	l.add_theme_color_override("font_outline_color", Color("#20243a"))
	l.add_theme_constant_override("outline_size", 3)
	return l


static func header(text: String) -> Label:
	return label(text, 14, COL_ACCENT)


static func gold_texture(variant: String = "small") -> Texture2D:
	var path := GOLD_SMALL
	if variant == "medium":
		path = GOLD_MEDIUM
	elif variant == "large":
		path = GOLD_LARGE
	return load(path) if ResourceLoader.exists(path) else null


static func gold_variant(amount: int) -> String:
	if amount >= 500:
		return "large"
	if amount >= 100:
		return "medium"
	return "small"


static func gold_icon(variant: String = "small", icon_size: Vector2 = Vector2(20, 18)) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = gold_texture(variant)
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


static func bond_icon(level: int, icon_size: Vector2 = Vector2(44, 44)) -> TextureRect:
	var icon := TextureRect.new()
	var tier := clampi(level, 1, 5)
	var path := BOND_PATTERN % tier
	icon.texture = load(path) if ResourceLoader.exists(path) else null
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.tooltip_text = "Bond level %d" % tier
	return icon


static func emote_texture(kind: String) -> Texture2D:
	var path := EMOTE_PATTERN % kind
	return load(path) if ResourceLoader.exists(path) else null


## A coin pile and amount floating above the shopkeeper after a completed sale.
static func gold_popup(parent: Node2D, amount: int) -> Node2D:
	var holder := Node2D.new()
	holder.name = "GoldSalePopup"
	holder.position = Vector2(0, -54)
	holder.z_index = 40
	parent.add_child(holder)
	var sprite := Sprite2D.new()
	sprite.texture = gold_texture(gold_variant(amount))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(sprite)
	var amount_label := label("+%d" % amount, 11, Color.WHITE)
	amount_label.add_theme_color_override("font_outline_color", Color("#5b3510"))
	amount_label.add_theme_constant_override("outline_size", 4)
	amount_label.position.y = 15
	holder.add_child(amount_label)
	(func() -> void:
		if is_instance_valid(amount_label):
			amount_label.position.x = -amount_label.size.x / 2.0).call_deferred()
	var tw := holder.create_tween()
	tw.tween_property(holder, "position:y", holder.position.y - 18.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(holder, "modulate:a", 0.0, 0.3)
	tw.tween_callback(holder.queue_free)
	return holder


## A character's name floating directly above its sprite: white with a dark
## outline so it reads on any world backdrop, horizontally centered on the
## body's origin. `visual` supplies the sprite top; centering is deferred one
## frame because a Label only knows its width after a layout pass. Shared by
## shop customers and the lobby crossers so every name looks the same.
static func floating_name(parent: Node2D, visual: CharacterVisual, text: String, gap: float = 3.0) -> Label:
	var l := label(text, 8, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 5
	parent.add_child(l)
	(func() -> void:
		if is_instance_valid(l) and is_instance_valid(visual):
			# honor any scale the caller put on the visual (e.g. size-capped crossers)
			var top := visual.top_y() * visual.scale.y
			l.position = Vector2(-l.size.x / 2.0, top - l.size.y - gap)).call_deferred()
	return l


static func button(text: String, on_press: Callable, size: int = 10) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func() -> void: AudioManager.play_sfx("menu_select", -4.0))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Ornate location nameplate: large gold text on the white bar texture,
## matching the menus. Center it with `reset_size()` then position.
static func nameplate(text: String, font_size: int = 13) -> PanelContainer:
	var p := PanelContainer.new()
	if ResourceLoader.exists(BAR_WHITE):
		var sb := StyleBoxTexture.new()
		sb.texture = load(BAR_WHITE)
		sb.texture_margin_left = 16
		sb.texture_margin_right = 16
		sb.texture_margin_top = 4
		sb.texture_margin_bottom = 4
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", sb)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.95, 0.9)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(6)
		p.add_theme_stylebox_override("panel", sb)
	var l := label(text, font_size, COL_ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func hsep() -> HSeparator:
	return HSeparator.new()


static func spacer(vertical: bool = true) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func spacer_px(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func scroll_list(min_size: Vector2) -> Array:
	if _mp_split_active():
		# split-screen: narrow lists let the whole menu scale up further
		# (a 500px list can never grow past ~1.5x inside half a window)
		min_size.x = minf(min_size.x, 420.0)
		min_size.y = minf(min_size.y, 240.0)
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


## The supplied ornate white panel with the light theme for its content;
## falls back to the plain dark panel when the texture is missing.
static func ornate_panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := panel(min_size)
	if ResourceLoader.exists(PANEL_WIDE):
		var style := StyleBoxTexture.new()
		# panel_wide.png is pre-scaled to 380px (the modal min width) so the
		# nine-patch only stretches up; margins are in that scaled space
		style.texture = load(PANEL_WIDE)
		style.texture_margin_left = 20
		style.texture_margin_right = 20
		style.texture_margin_top = 14
		style.texture_margin_bottom = 14
		style.content_margin_left = 36
		style.content_margin_right = 36
		style.content_margin_top = 28
		style.content_margin_bottom = 26
		p.add_theme_stylebox_override("panel", style)
		p.theme = light_theme()
	return p


static func modal(parent: Node, title: String) -> Array:
	## Returns [layer, content_vbox]. Caller fills content and frees layer.
	var layer := CanvasLayer.new()
	layer.layer = 50
	parent.add_child(layer)
	var vp := layer.get_viewport()
	_count_modal(vp, 1)
	layer.tree_exiting.connect(func() -> void:
		_count_modal(vp, -1)
		AudioManager.play_sfx("menu_close", -4.0))
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var p := ornate_panel(Vector2(380, 0))
	center.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	if title != "":
		vb.add_child(header(title))
		vb.add_child(hsep())
	# split-screen: once the caller has filled the modal, measure it and scale
	# it to FILL its player's half — fixed guesses left menus unreadably small.
	# Refits whenever the panel's size changes (sorting, list rebuilds).
	if vp is SubViewport or _mp_split_active():
		var fit := func() -> void: _fit_modal_to_half(layer, p, dim)
		fit.call_deferred()
		p.resized.connect(fit)
	# controller: focus the first button once the caller has filled the modal
	focus_first_button(vb)
	return [layer, vb]


static func _mp_split_active() -> bool:
	var mp := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("MultiplayerState")
	return mp != null and bool(mp.get("enabled")) and mp.call("p2_viewport") != null


## Scale a modal so it fills most of its player's screen half. P2's menus
## live inside their SubViewport (physical pixels, the viewport IS the half);
## P1's live on the root viewport and are confined to the LEFT half so P2's
## view is never covered. Single-player modals are left at native layout.
static func _fit_modal_to_half(layer: CanvasLayer, p: PanelContainer, dim: ColorRect) -> void:
	if not is_instance_valid(layer) or not is_instance_valid(p) or not layer.is_inside_tree():
		return
	var vp := layer.get_viewport()
	if vp == null:
		return
	var half: Vector2
	var frame: Vector2  # the full region the layer's controls span unscaled
	if vp is SubViewport:
		half = Vector2((vp as SubViewport).size)
		frame = half
	elif _mp_split_active():
		frame = Vector2(vp.get_visible_rect().size)
		half = Vector2(frame.x * 0.5, frame.y)
	else:
		return
	var psize := p.get_combined_minimum_size()
	if psize.x < 1.0 or psize.y < 1.0:
		return
	var s := clampf(minf(half.x * 0.95 / psize.x, half.y * 0.92 / psize.y), 0.5, 2.4)
	layer.scale = Vector2(s, s)
	layer.offset = (half - frame * s) * 0.5
	# the darkening backdrop must cover exactly this half at any scale
	dim.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dim.position = -layer.offset / s
	dim.size = half / s


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
