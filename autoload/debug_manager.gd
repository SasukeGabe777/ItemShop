extends Node
## DebugManager: F3 console with cheat/inspection commands, plus logging hooks.

var console_layer: CanvasLayer
var output_label: RichTextLabel
var input_line: LineEdit
var visible_console: bool = false
var history: Array[String] = []
const HISTORY_LIMIT := 300

# admin/test mode: tap # three times in a row (within 1.5s) to unlock everything
var admin_mode: bool = false
var _hash_taps: int = 0
var _hash_last: float = 0.0
const HASH_WINDOW := 1.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console"):
		toggle_console()
		return
	# secret: * adds pocket money
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ASTERISK or k.keycode == KEY_KP_MULTIPLY or k.unicode == 42:
			EconomyManager.add_gold(10000)
			AudioManager.play_sfx("acquired")
		# secret: # x3 in a row flips on admin/test mode (unlock everything)
		elif k.keycode == KEY_NUMBERSIGN or k.unicode == 35:
			var now := Time.get_ticks_msec() / 1000.0
			_hash_taps = _hash_taps + 1 if now - _hash_last <= HASH_WINDOW else 1
			_hash_last = now
			if _hash_taps >= 3:
				_hash_taps = 0
				enable_admin_mode()


## Flip on admin/test mode: max gold, every item in the bag, every hero met, every
## dungeon repaired (which also frees all crossover heroes), and the campaign
## advanced past the last chapter so every world — including the final one — is
## reachable. Idempotent; safe to trigger again.
func enable_admin_mode() -> void:
	admin_mode = true
	# max gold
	EconomyManager.add_gold(maxi(0, 9_999_999 - EconomyManager.gold))
	# every hero greeted + every gate repaired (repaired worlds also unlock their
	# heroes anywhere, so this covers "all heroes" and "all dungeons" at once)
	for h: String in ContentDatabase.heroes:
		GameState.meet_hero(h)
	for w: String in BridgeManager.gates:
		BridgeManager.gates[w] = {"shard": true, "paid": true, "repaired": true}
	# advance to the highest world chapter so chapter-gated worlds all show
	var max_chapter := 8
	for wid: String in ContentDatabase.worlds:
		max_chapter = maxi(max_chapter, int(ContentDatabase.worlds[wid].get("chapter", 0)))
	TimeManager.begin_chapter(max_chapter)
	# every sellable item in the bag + logged in the encyclopedia
	var items := 0
	for id: String in ContentDatabase.live_items:
		InventoryManager.add_item(id, 10)
		GameState.learn_item(id)
		items += 1
	AudioManager.play_sfx("acquired")
	log_line("ADMIN MODE ON: 9,999,999g, %d items x10, %d heroes, all %d dungeons unlocked"
		% [items, ContentDatabase.heroes.size(), BridgeManager.gates.size()])
	_show_admin_toast()


func _show_admin_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	var label := Label.new()
	label.text = "⚙ ADMIN MODE ENABLED\nmax gold · all items · all heroes · all dungeons"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	var tw := layer.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)


func toggle_console() -> void:
	if console_layer == null:
		_build_console()
	visible_console = not visible_console
	console_layer.visible = visible_console
	if visible_console:
		input_line.grab_focus()


func _build_console() -> void:
	console_layer = CanvasLayer.new()
	console_layer.layer = 100
	add_child(console_layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 160)
	console_layer.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	output_label = RichTextLabel.new()
	output_label.custom_minimum_size = Vector2(0, 120)
	output_label.scroll_following = true
	vb.add_child(output_label)
	input_line = LineEdit.new()
	input_line.placeholder_text = "help | boom ID [WORLD] | boom random | boom clear | gold N | advance N | day | give ITEM [N] | shard WORLD | repair WORLD"
	input_line.text_submitted.connect(_on_command)
	vb.add_child(input_line)
	console_layer.visible = false


func _on_command(text: String) -> void:
	input_line.clear()
	log_line("> " + text)
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	run_command(parts)


func run_command(parts: PackedStringArray) -> void:
	match parts[0]:
		"help":
			log_line("boom ID [WORLD] / boom random / boom clear / gold N / advance N / day / give ITEM [N] / shard WORLD / repair WORLD / unlock_all / admin / scene ID / sim WORLD HERO / save / load")
		"admin":
			enable_admin_mode()
		"boom":
			if parts.size() <= 1:
				log_line("boom = %s (%d sessions)" % [BoomManager.display_name() if BoomManager.is_active() else "none", BoomManager.sessions_left])
			elif parts[1] == "clear":
				BoomManager.clear_active()
				log_line("boom cleared")
			elif parts[1] == "random":
				BoomManager.clear_active()
				BoomManager._roll_daily_boom(true)
				log_line("boom = %s" % (BoomManager.display_name() if BoomManager.is_active() else "none rolled"))
			else:
				var world := String(parts[2]) if parts.size() > 2 else ""
				log_line("boom %s -> %s" % [parts[1], BoomManager.force_boom(String(parts[1]), world)])
		"gold":
			EconomyManager.add_gold(int(parts[1]) if parts.size() > 1 else 10000)
			log_line("gold = %d" % EconomyManager.gold)
		"advance":
			var n := int(parts[1]) if parts.size() > 1 else 1
			var ev := TimeManager.advance(n)
			log_line("day %d %s (%s)" % [TimeManager.day, TimeManager.period_name(), ", ".join(ev)])
		"day":
			log_line("day %d period %d chapter %d" % [TimeManager.day, TimeManager.period, TimeManager.chapter])
		"give":
			if parts.size() > 1:
				InventoryManager.add_item(parts[1], int(parts[2]) if parts.size() > 2 else 1)
				log_line("gave %s" % parts[1])
		"shard":
			if parts.size() > 1:
				BridgeManager.collect_shard(parts[1])
				log_line("shard %s" % parts[1])
		"repair":
			if parts.size() > 1:
				log_line("repair %s -> %s" % [parts[1], BridgeManager.pay_repair(parts[1])])
		"unlock_all":
			for w: String in BridgeManager.gates:
				BridgeManager.gates[w] = {"shard": true, "paid": true, "repaired": true}
			TimeManager.begin_chapter(8)
			log_line("all gates repaired; final chapter")
		"scene":
			if parts.size() > 1:
				StoryEventManager.queue.append(parts[1])
				SceneRouter.go("story")
		"sim":
			if parts.size() > 2:
				var r := DungeonManager.simulate_expedition(parts[1], parts[2], randi())
				log_line(JSON.stringify(r))
		"save":
			SaveManager.autosave()
			log_line("autosaved")
		"load":
			log_line("loaded: %s" % SaveManager.load_autosave())
		_:
			log_line("unknown command")


func log_line(text: String) -> void:
	history.append("%s  %s" % [Time.get_time_string_from_system(), text])
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	if output_label != null:
		output_label.append_text(text + "\n")
	print("[Debug] " + text)


func recent_lines(limit: int = 100) -> Array[String]:
	var start := maxi(0, history.size() - limit)
	var out: Array[String] = []
	for i in range(start, history.size()):
		out.append(history[i])
	return out
