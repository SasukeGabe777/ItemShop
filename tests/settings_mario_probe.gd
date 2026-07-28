extends Node2D
## Logic and windowed presentation proof for the pause-menu mixer, online
## partner appearances, Mario/Luigi action facing, and Mario boss rotation.

const SHOT_DIR := "user://screenshots/settings_mario/"

var failures: Array[String] = []


func _ready() -> void:
	var old_master := AudioManager.master_level
	var old_music := AudioManager.music_level
	var old_sfx := AudioManager.sfx_level
	var old_ui := MultiplayerState.ui_scale_preset
	_check_mixer()
	_check_partner_avatars()
	_check_boss_rotation()
	_check_action_facing()
	await _show_settings()
	await _show_mario_roster()
	AudioManager.set_master_level(old_master)
	AudioManager.set_music_level(old_music)
	AudioManager.set_sfx_level(old_sfx)
	MultiplayerState.set_ui_scale_preset(old_ui)
	if failures.is_empty():
		print("SETTINGS_MARIO_PROBE_PASS folder=",
			ProjectSettings.globalize_path(SHOT_DIR))
	else:
		for failure in failures:
			printerr("SETTINGS_MARIO_PROBE_FAIL: ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_mixer() -> void:
	for bus_name in ["Master", "Music", "SFX"]:
		_expect(AudioServer.get_bus_index(bus_name) >= 0,
			"missing %s audio bus" % bus_name)
	AudioManager.set_master_level(0.65)
	AudioManager.set_music_level(0.55)
	AudioManager.set_sfx_level(0.45)
	_expect(is_equal_approx(AudioManager.master_level, 0.65),
		"master volume did not update")
	_expect(is_equal_approx(AudioManager.music_level, 0.55),
		"music volume did not update")
	_expect(is_equal_approx(AudioManager.sfx_level, 0.45),
		"SFX volume did not update")
	var cfg := ConfigFile.new()
	_expect(cfg.load("user://settings.cfg") == OK,
		"mixer settings were not persisted")
	if cfg.load("user://settings.cfg") == OK:
		_expect(is_equal_approx(float(cfg.get_value("audio", "music", -1.0)), 0.55),
			"persisted music volume is wrong")


func _check_partner_avatars() -> void:
	var fairy := "res://assets/shared/effects/p2_sidekick.json"
	for seat in range(2, 6):
		_expect(PartyState.world_avatar_of(seat) == fairy,
			"P%d does not use the online partner sprite" % seat)
	_expect(PartyState.world_tint(2) == Color.WHITE,
		"P2 should retain the original fairy colors")
	var unique := {}
	for seat in range(3, 6):
		unique[PartyState.world_tint(seat)] = true
	_expect(unique.size() == 3, "P3-P5 partner color offsets are not distinct")


func _check_boss_rotation() -> void:
	var key := "expedition_wins_mario"
	var had := GameState.stats.has(key)
	var old: Variant = GameState.stats.get(key, 0)
	for entry in [[0, "bowser"], [1, "queen_bean"], [2, "king_boo"], [8, "king_boo"]]:
		GameState.stats[key] = int(entry[0])
		_expect(DungeonManager.boss_for_world("mario") == String(entry[1]),
			"Mario win %d selected the wrong boss" % int(entry[0]))
	if had:
		GameState.stats[key] = old
	else:
		GameState.stats.erase(key)


func _check_action_facing() -> void:
	for hero_id in ["mario", "luigi"]:
		var visual := CharacterVisual.new()
		add_child(visual)
		_expect(visual.setup_from_manifest(
			"res://assets/franchises/mario/manifests/%s.json" % hero_id),
			"%s manifest did not load" % hero_id)
		visual.play_action("attack_1", Vector2.LEFT)
		_expect(not visual.animated.flip_h,
			"%s left attack still mirrors to the right" % hero_id)
		visual.play_action("attack_1", Vector2.RIGHT)
		_expect(visual.animated.flip_h,
			"%s right attack does not mirror its left-facing source art" % hero_id)
		visual.play_action("special", Vector2.LEFT)
		_expect(not visual.animated.flip_h,
			"%s left special still mirrors to the right" % hero_id)
		visual.queue_free()


func _show_settings() -> void:
	var parts := UIKit.modal(self, "Audio & Display")
	var layer: CanvasLayer = parts[0]
	var box: VBoxContainer = parts[1]
	GameSettingsControls.add_to(box)
	box.add_child(UIKit.button("Back", func() -> void: pass))
	var sliders := box.find_children("*", "HSlider", true, false)
	_expect(sliders.size() == 3,
		"settings menu has %d volume sliders instead of 3" % sliders.size())
	var all_text := _label_and_button_text(box)
	for expected in ["Master", "Music", "Sound effects", "UI size"]:
		_expect(expected.to_lower() in all_text.to_lower(),
			"settings menu is missing %s" % expected)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(
			SHOT_DIR + "01_audio_display.png")
	layer.queue_free()
	await get_tree().process_frame


func _show_mario_roster() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#315f36")
	bg.size = Vector2(660, 380)
	bg.z_index = -20
	add_child(bg)
	var title := UIKit.label("MUSHROOM KINGDOM — THREE EXPEDITION BOSSES",
		12, UIKit.COL_ACCENT)
	title.position = Vector2(105, 24)
	add_child(title)
	var target := Node2D.new()
	target.position = Vector2(320, 340)
	add_child(target)
	var ids := ["bowser", "queen_bean", "king_boo"]
	for i in range(ids.size()):
		var boss := Boss.new()
		add_child(boss)
		boss.setup(ids[i], target)
		boss.position = Vector2(125 + i * 195, 150)
		boss.set_physics_process(false)
		var label := UIKit.label(String(ContentDatabase.get_enemy(ids[i]).get(
			"name", ids[i])), 9, UIKit.COL_INK)
		label.position = boss.position + Vector2(-40, 26)
		add_child(label)
	var directions := [Vector2.LEFT, Vector2.RIGHT]
	for h in range(2):
		for d in range(2):
			var visual := CharacterVisual.new()
			add_child(visual)
			visual.setup_from_manifest(
				"res://assets/franchises/mario/manifests/%s.json"
				% (["mario", "luigi"][h]))
			visual.position = Vector2(225 + d * 155, 272 + h * 58)
			visual.play_action("attack_1", directions[d])
			var action_label := UIKit.label("%s %s" % [
				["Mario", "Luigi"][h], ["LEFT", "RIGHT"][d]],
				7, UIKit.COL_ACCENT)
			action_label.position = visual.position + Vector2(-30, 18)
			add_child(action_label)
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.12).timeout
		get_viewport().get_texture().get_image().save_png(
			SHOT_DIR + "02_mario_bosses_and_facing.png")


func _label_and_button_text(root: Node) -> String:
	var lines: Array[String] = []
	for node in root.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	for node in root.find_children("*", "Button", true, false):
		lines.append((node as Button).text)
	return "\n".join(lines)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
