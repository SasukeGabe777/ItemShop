class_name PatchDebrief
extends CanvasLayer
## Small end-of-session dialogue: Patch pops up under the summary and gives
## his opinion of how the day's trading went, with a tip when it went badly.
## Advance with [E]/click; calls `on_done` when dismissed.

var _lines: Array[String] = []
var _line_idx := 0
var _text: Label
var _on_done: Callable
var _host: Node


static func show_debrief(parent: Node, summary: Dictionary, on_done: Callable) -> void:
	var d := PatchDebrief.new()
	d._lines = _pick_lines(summary)
	d._on_done = on_done
	d._host = parent
	parent.add_child(d)


static func _pick_lines(s: Dictionary) -> Array[String]:
	var sales := int(s.get("sales", 0))
	var revenue := int(s.get("revenue", 0))
	var perfect := int(s.get("perfect", 0))
	var walked := int(s.get("left", 0))
	var out: Array[String] = []
	var boom_name := String(s.get("boom_name", ""))
	if boom_name != "" and sales == 0:
		out.append("The %s crowd came, saw empty shelves, and left. That was painful." % boom_name)
		out.append("Next Boom, use the announcement to stock its categories and tags before opening.")
	elif boom_name != "" and sales >= 8:
		out.append("%d items sold during %s! THAT is how you ride a Boom!" % [sales, boom_name])
		out.append("Watch the next announcement. A matching shop style can pull in an even larger crowd.")
	elif sales == 0:
		out.append("Not a single sale?! The Bridge isn't going to repair itself, you know...")
		out.append("Check the day's market report — stock what's selling HIGH and price near market value.")
	elif perfect >= 2 and perfect * 2 >= sales:
		out.append("%d perfect deals out of %d! You read those customers like open books." % [perfect, sales])
		out.append("Keep the combo going — every perfect deal pushes your prices a little higher.")
	elif walked > sales:
		out.append("Hmm. %d customers walked out and only %d bought. My non-existent stomach hurts." % [walked, sales])
		out.append("Watch their purse hints — someone with light pockets will never pay far over market.")
	elif revenue >= 2000:
		out.append("%dg in one session! I felt the World Bridge hum. Or maybe that was me." % revenue)
		out.append("Big earnings draw bigger spenders. Tomorrow, stock the fancy stuff.")
	elif sales >= 1 and revenue > 0:
		out.append("%d sales, %dg. Honest work — the Crossroads runs on days like this." % [sales, revenue])
		out.append("A little market reading and we will do even better tomorrow.")
	return out


func _ready() -> void:
	layer = 55
	add_to_group("patch_speaking")  # the HUD period banner waits for Patch
	if _lines.is_empty():
		_finish()
		return
	if _host != null and "busy" in _host:
		_host.busy = true
	var host_player: Variant = _host.get("player") if _host != null else null
	if host_player is TownPlayer:
		(host_player as TownPlayer).frozen = true
	AudioManager.play_voice("patch")
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.12, 0.94)
	sb.border_color = Color("#66e0ff")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -124
	panel.offset_bottom = -24
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = _portrait()
	portrait.custom_minimum_size = Vector2(56, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	row.add_child(vb)
	vb.add_child(UIKit.label("Patch", 12, Color("#66e0ff")))
	_text = UIKit.label(_lines[0], 11, Color("#efe8d8"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(340, 40)
	vb.add_child(_text)
	var hint := UIKit.label("[%s] continue" % UIKit.interact_key(), 8, Color("#8fa0b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)


func _portrait() -> Texture2D:
	const SHEET := "res://assets/shared/patch/sheets/patch.png"
	if ResourceLoader.exists(SHEET):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(SHEET)
		atlas.region = Rect2(0, 0, 28, 36)
		return atlas
	const FALLBACK := "res://assets/shared/placeholders/patch.png"
	return load(FALLBACK) if ResourceLoader.exists(FALLBACK) else null


func _unhandled_input(event: InputEvent) -> void:
	var advance := event.is_action_pressed("interact") \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return
	get_viewport().set_input_as_handled()
	_line_idx += 1
	if _line_idx >= _lines.size():
		_finish()
		return
	AudioManager.play_voice("patch")
	_text.text = _lines[_line_idx]


func _finish() -> void:
	if _host != null and is_instance_valid(_host) and "busy" in _host:
		_host.busy = false
		var host_player: Variant = _host.get("player")
		if host_player is TownPlayer:
			(host_player as TownPlayer).frozen = false
	var cb := _on_done
	queue_free()
	if cb.is_valid():
		cb.call()
