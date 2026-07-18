extends Node2D
## Dialogue scene player. Plays queued story scenes (portrait blobs + typed
## text), then routes onward. Also hosts the chapter-failure restart flow.

const BACKDROP := "res://assets/shared/ui/titlescreenupdated.png"

var lines: Array = []
var line_index: int = 0
var name_label: Label
var text_label: RichTextLabel
var portrait: TextureRect
var continue_hint: Label
var typing: bool = false
var scene_data: Dictionary = {}


func _ready() -> void:
	var failure := bool(SceneRouter.context.get("failure", false))
	if failure:
		StoryEventManager.fire("chapter_failed", {})
	scene_data = StoryEventManager.pop_next()
	if scene_data.is_empty():
		_route_out()
		return
	lines = scene_data.get("lines", [])
	_apply_scene_music()
	_build_ui()
	_show_line(0)


## Scenes may name a music track ("music" in story_scenes.json); scenes
## without one keep whatever is already playing.
func _apply_scene_music() -> void:
	var track := String(scene_data.get("music", ""))
	if track != "":
		AudioManager.play_track(track)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = UIKit.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	# the Crossroads key art, dimmed, as the storytelling backdrop
	if ResourceLoader.exists(BACKDROP):
		var art := TextureRect.new()
		art.texture = load(BACKDROP)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.add_child(art)
		var dim := ColorRect.new()
		dim.color = Color(0.05, 0.06, 0.12, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	layer.add_child(margin)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_END
	margin.add_child(center)
	var panel := UIKit.ornate_panel()
	panel.custom_minimum_size = Vector2(0, 124)
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vb)
	name_label = UIKit.label("", 12, UIKit.COL_ACCENT)
	vb.add_child(name_label)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = false
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("normal_font_size", 11)
	text_label.add_theme_color_override("default_color", UIKit.COL_INK)
	vb.add_child(text_label)
	continue_hint = UIKit.label("[E / Space] continue", 8, UIKit.COL_DIM)
	vb.add_child(continue_hint)


## Speaker colors were tuned for the dark HUD; darken the bright ones so
## they stay readable on the white ornate panel.
func _panel_speaker_color(who: String) -> Color:
	var c := StoryEventManager.speaker_color(who)
	if c.get_luminance() > 0.55:
		c = c.darkened(0.45)
	return c


func _show_line(idx: int) -> void:
	line_index = idx
	var line: Dictionary = lines[idx]
	var who := String(line.get("who", ""))
	AudioManager.play_voice(who)
	name_label.text = StoryEventManager.speaker_display_name(who)
	name_label.add_theme_color_override("font_color", _panel_speaker_color(who))
	var hero_data: Dictionary = ContentDatabase.heroes.get(who, ContentDatabase.npcs.get(who, {}))
	portrait.texture = ContentDatabase.entity_texture(who, String(hero_data.get("world", "crossroads")), String(hero_data.get("color", "#c0c0c0")), 24)
	text_label.text = ""
	typing = true
	var full := String(line.get("text", ""))
	var tw := create_tween()
	tw.tween_method(func(n: int) -> void: text_label.text = full.substr(0, n), 0, full.length(), minf(1.2, full.length() * 0.018))
	tw.tween_callback(func() -> void: typing = false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		if typing:
			# skip typing
			typing = false
			text_label.text = String(lines[line_index].get("text", ""))
			for tween in get_tree().get_processed_tweens():
				tween.kill()
			return
		if line_index + 1 < lines.size():
			_show_line(line_index + 1)
		else:
			_scene_done()


func _scene_done() -> void:
	var trigger_type := String(scene_data.get("trigger", {}).get("type", ""))
	if trigger_type == "chapter_failed":
		_failure_restart_flow()
		return
	if trigger_type == "ending":
		GameState.set_flag("campaign_complete")
		GameState.endless_mode = true
		StoryEventManager.fire("endless_start")
		SaveManager.autosave()
	if StoryEventManager.has_pending():
		scene_data = StoryEventManager.pop_next()
		lines = scene_data.get("lines", [])
		_apply_scene_music()
		_show_line(0)
		return
	_route_out()


func _route_out() -> void:
	var dest := String(SceneRouter.context.get("return_to", "town"))
	if String(scene_data.get("trigger", {}).get("type", "")) == "boss_defeated" and int(scene_data.get("trigger", {}).get("chapter", 0)) == 8:
		StoryEventManager.fire("ending")
		if StoryEventManager.has_pending():
			scene_data = StoryEventManager.pop_next()
			lines = scene_data.get("lines", [])
			_apply_scene_music()
			_show_line(0)
			return
	SceneRouter.go(dest if dest != "dungeon" else "dungeon")


## Failure: pick up to N items to keep, then restart the chapter checkpoint.
func _failure_restart_flow() -> void:
	AudioManager.play_stinger("failure_stinger")
	var max_keep := int(ContentDatabase.bal("chapter_failure", {}).get("keep_inventory_items", 10))
	var parts := UIKit.modal(self, "The gate collapsed...")
	var vb: VBoxContainer = parts[1]
	vb.add_child(UIKit.label("Restart chapter %d from day %d." % [TimeManager.chapter, (TimeManager.chapter - 1) * TimeManager.chapter_len() + 1], 10))
	vb.add_child(UIKit.label("You keep: merchant level, customer bonds, encyclopedia, tutorials, decorations.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.label("Choose up to %d inventory items to carry back:" % max_keep, 10, UIKit.COL_ACCENT))
	var chosen: Array = []
	var chosen_lbl := UIKit.label("(none)", 9, UIKit.COL_DIM)
	var list_parts := UIKit.scroll_list(Vector2(340, 160))
	vb.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	for id in InventoryManager.sorted_ids("price"):
		var iid := id
		list.add_child(UIKit.item_row(iid, "x%d" % InventoryManager.count(iid), "Keep", func() -> void:
			if chosen.size() < max_keep and chosen.count(iid) < InventoryManager.count(iid):
				chosen.append(iid)
				var names: Array[String] = []
				for c in chosen:
					names.append(ContentDatabase.item_name(String(c)))
				chosen_lbl.text = ", ".join(names)))
	vb.add_child(chosen_lbl)
	vb.add_child(UIKit.button("Restart the chapter", func() -> void:
		SaveManager.restart_chapter(chosen)
		SceneRouter.go("town")))
