extends Node
## DebugManager: F3 console with cheat/inspection commands, plus logging hooks.

var console_layer: CanvasLayer
var output_label: RichTextLabel
var input_line: LineEdit
var visible_console: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console"):
		toggle_console()


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
	input_line.placeholder_text = "help | gold N | advance N | day | give ITEM [N] | shard WORLD | repair WORLD | unlock_all | scene ID | sim WORLD HERO"
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
			log_line("gold N / advance N / day / give ITEM [N] / shard WORLD / repair WORLD / unlock_all / scene ID / sim WORLD HERO / save / load")
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
	if output_label != null:
		output_label.append_text(text + "\n")
	print("[Debug] " + text)
