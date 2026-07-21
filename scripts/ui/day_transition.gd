class_name DayTransition
extends CanvasLayer
## Full-screen end-of-day scene: the sky cycles through all four periods of
## the finished day, then a panel sums the day up — sales, Patch's verdict —
## and a single button starts the new morning. Unmissable day boundary.

const SKY := "res://assets/shared/ui/backgrounds/processed/daycycle_%s.png"
const KEYS := ["morning", "afternoon", "evening", "night"]

var _finished_day := 0
var _summary: Dictionary = {}
var _on_done: Callable
var _host: Node
var period_mode := false  # mid-day variant: one sky, no cycle animation
var _sky_a: TextureRect
var _sky_b: TextureRect
var _title: Label
var _panel_shown := false
var _tween: Tween


## "x2 Potion — 130g" lines aggregated from a [{item, price}] sale log,
## biggest earners first. Shared by the session modal and this scene.
static func sales_lines(sold: Array, max_lines: int = 8) -> Array[String]:
	if sold.is_empty():
		return []
	var agg := {}  # item_id -> [qty, total]
	for e: Dictionary in sold:
		var id := String(e.get("item", ""))
		if not agg.has(id):
			agg[id] = [0, 0]
		agg[id][0] += 1
		agg[id][1] += int(e.get("price", 0))
	var entries := []
	for id: String in agg:
		entries.append([id, agg[id][0], agg[id][1]])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
	var lines: Array[String] = ["Sold:"]
	for i in range(mini(entries.size(), max_lines)):
		lines.append("  x%d %s — %dg" % [int(entries[i][1]), ContentDatabase.item_name(String(entries[i][0])), int(entries[i][2])])
	if entries.size() > max_lines:
		lines.append("  ...and %d more" % (entries.size() - max_lines))
	return lines


static func show_transition(parent: Node, finished_day: int, summary: Dictionary, on_done: Callable) -> void:
	var t := DayTransition.new()
	t._finished_day = finished_day
	t._summary = summary
	t._on_done = on_done
	t._host = parent
	parent.add_child(t)


## Mid-day version: shown after every period-consuming activity so the player
## always sees the session result and the Fade's countdown.
static func show_period(parent: Node, summary: Dictionary, on_done: Callable) -> void:
	var t := DayTransition.new()
	t.period_mode = true
	t._finished_day = TimeManager.day
	t._summary = summary
	t._on_done = on_done
	t._host = parent
	parent.add_child(t)


func _ready() -> void:
	layer = 58
	# gameplay treats this exactly like a modal (blocks world interact polling)
	var vp := get_viewport()
	UIKit._count_modal(vp, 1)
	tree_exiting.connect(func() -> void: UIKit._count_modal(vp, -1))
	if _host != null and "busy" in _host:
		_host.busy = true
	# day boundaries stop BOTH local players; player 1 holds the controls
	for key in ["player", "player2"]:
		var hp: Variant = _host.get(key) if _host != null else null
		if hp is TownPlayer:
			(hp as TownPlayer).frozen = true
	var dim := ColorRect.new()
	dim.color = Color.BLACK
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var start_key: String = KEYS[clampi(TimeManager.period, 0, KEYS.size() - 1)] if period_mode else KEYS[0]
	_sky_a = _sky_rect(start_key)
	add_child(_sky_a)
	_sky_b = _sky_rect(start_key)
	_sky_b.modulate.a = 0.0
	add_child(_sky_b)
	var title_text := "Day %d — %s" % [TimeManager.day, TimeManager.period_name()] if period_mode else "Day %d" % _finished_day
	_title = UIKit.label(title_text, 26, Color.WHITE)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 44
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_title)
	_animate()


func _sky_rect(key: String) -> TextureRect:
	var tr := TextureRect.new()
	if ResourceLoader.exists(SKY % key):
		tr.texture = load(SKY % key)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr


func _animate() -> void:
	_tween = create_tween()
	if period_mode:
		_tween.tween_interval(0.5)
		_tween.tween_callback(_show_panel)
		return
	_tween.tween_interval(0.6)
	for i in range(1, KEYS.size()):
		var key: String = KEYS[i]
		_tween.tween_callback(func() -> void:
			if ResourceLoader.exists(SKY % key):
				_sky_b.texture = load(SKY % key)
			_sky_b.modulate.a = 0.0)
		_tween.tween_property(_sky_b, "modulate:a", 1.0, 0.7)
		_tween.tween_callback(func() -> void:
			_sky_a.texture = _sky_b.texture
			_sky_b.modulate.a = 0.0)
		_tween.tween_interval(0.45)
	_tween.tween_callback(_show_panel)


func _unhandled_input(event: InputEvent) -> void:
	# A / E / click skips straight to the summary
	if _panel_shown:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		get_viewport().set_input_as_handled()
		if _tween != null:
			_tween.kill()
		_sky_b.modulate.a = 0.0
		if not period_mode and ResourceLoader.exists(SKY % "night"):
			_sky_a.texture = load(SKY % "night")
		_show_panel()


func _show_panel() -> void:
	if _panel_shown:
		return
	_panel_shown = true
	if not period_mode:
		_title.text = "Day %d complete" % _finished_day
		AudioManager.play_sfx("achievement_unlocked", 2.0)
	AudioManager.play_voice("patch")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIKit.ornate_panel(Vector2(430, 0))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var head := "Day %d — %s" % [TimeManager.day, TimeManager.period_name()] if period_mode else "Day %d — closing time" % _finished_day
	vb.add_child(UIKit.header(head))
	vb.add_child(UIKit.hsep())
	if not _summary.is_empty():
		if String(_summary.get("boom_name", "")) != "":
			vb.add_child(UIKit.label("BOOM COMPLETE: %s  |  %d customers arrived" % [
				String(_summary["boom_name"]), int(_summary.get("customers", 0))], 13, UIKit.COL_ACCENT))
		vb.add_child(UIKit.label("Sales: %d   Revenue: %dg" % [
			int(_summary.get("sales", 0)), int(_summary.get("revenue", 0))]))
		if _summary.has("perfect"):
			vb.add_child(UIKit.label("Perfect deals: %d   Walked away: %d   New orders: %d" % [
				int(_summary.get("perfect", 0)), int(_summary.get("left", 0)), int(_summary.get("orders", 0))]))
		vb.add_child(UIKit.label("Gold: %dg   Merchant Lv.%d" % [
			EconomyManager.gold, GameState.merchant_level], 9, UIKit.COL_DIM))
		for line in sales_lines(_summary.get("sold", [])):
			vb.add_child(UIKit.label(line, 9, UIKit.COL_INK))
		vb.add_child(UIKit.hsep())
	var status := fade_status()
	if status != null:
		vb.add_child(status)
		vb.add_child(UIKit.hsep())
	var patch_lines := PatchDebrief._pick_lines(_summary)
	if period_mode and patch_lines.is_empty():
		# quiet mid-day stretch (a rest, an errand): no Patch commentary
		var begin_quiet := UIKit.button("Continue", _finish, 12)
		vb.add_child(begin_quiet)
		UIKit.focus_first_button(vb)
		return
	var patch_row := HBoxContainer.new()
	patch_row.add_theme_constant_override("separation", 10)
	vb.add_child(patch_row)
	var portrait := TextureRect.new()
	portrait.texture = _patch_portrait()
	portrait.custom_minimum_size = Vector2(48, 62)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	patch_row.add_child(portrait)
	if patch_lines.is_empty():
		patch_lines = ["A quiet day at the Crossroads. Rest well — tomorrow the Bridge needs us again."]
	var speech := UIKit.label("Patch: " + "\n".join(patch_lines), 10)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.custom_minimum_size = Vector2(300, 0)
	patch_row.add_child(speech)
	vb.add_child(UIKit.hsep())
	var begin_text := "Continue" if period_mode else "Begin Day %d — Morning" % TimeManager.day
	var begin := UIKit.button(begin_text, _finish, 12)
	vb.add_child(begin)
	UIKit.focus_first_button(vb)


## The stakes, restated every night: repair fund vs cost, shard status, and
## the countdown — key numbers color-coded so they can't be missed.
## Static so other debriefs (expeditions) can show the same block.
static func fade_status() -> Control:
	if not GameState.campaign_active or GameState.endless_mode:
		return null
	var chap := TimeManager.chapter
	if chap > 7:
		return UIKit.label("The Fade waits beyond the final gate...", 11, UIKit.COL_BAD)
	var world := ContentDatabase.world_for_chapter(chap)
	var wid := String(world.get("id", ""))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_color_override("default_color", UIKit.COL_INK)
	rt.add_theme_font_size_override("normal_font_size", 11)
	rt.add_theme_font_size_override("bold_font_size", 11)
	if BridgeManager.is_chapter_complete(chap):
		rt.append_text("[b]The %s gate holds.[/b] [color=#4a9a55]Chapter complete[/color] — the Fade falls back, for now." % String(world.get("name", "?")))
		return rt
	var cost := BridgeManager.repair_cost(wid)
	var gold := EconomyManager.gold
	var shard := BridgeManager.has_shard(wid)
	var days_left := TimeManager.chapter_deadline_day() - TimeManager.day + 1
	var gold_col := "#4a9a55" if gold >= cost else "#c65555"
	var shard_txt := "[color=#4a9a55]SECURED[/color]" if shard else "[color=#c65555]STILL MISSING[/color]"
	var days_col := "#c65555" if days_left <= 2 else "#c8922a"
	rt.append_text("[b]The Fade advances on %s (Ch.%d):[/b]\n" % [String(world.get("name", "?")), chap])
	rt.append_text("- Repair fund: [color=%s]%sg[/color] of [color=#c8922a]%sg[/color] needed\n" % [gold_col, _fmt(gold), _fmt(cost)])
	rt.append_text("- World Shard (win it on an expedition): %s\n" % shard_txt)
	rt.append_text("- Time: [color=%s]%d day%s left[/color] — due by the end of Day %d" % [
		days_col, days_left, "" if days_left == 1 else "s", TimeManager.chapter_deadline_day()])
	return rt


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _patch_portrait() -> Texture2D:
	const SHEET := "res://assets/shared/patch/sheets/patch.png"
	if ResourceLoader.exists(SHEET):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(SHEET)
		atlas.region = Rect2(0, 0, 28, 36)
		return atlas
	const FALLBACK := "res://assets/shared/placeholders/patch.png"
	return load(FALLBACK) if ResourceLoader.exists(FALLBACK) else null


func _finish() -> void:
	if _host != null and is_instance_valid(_host) and "busy" in _host:
		_host.busy = false
		for key in ["player", "player2"]:
			var hp: Variant = _host.get(key)
			if hp is TownPlayer:
				(hp as TownPlayer).frozen = false
	var cb := _on_done
	queue_free()
	if cb.is_valid():
		cb.call()
