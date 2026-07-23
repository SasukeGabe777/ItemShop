extends Node
## Regression and screenshot probe for the two-player world identities.

const SHOT_DIR := "user://screenshots/multiplayer_identity/"


class Probe:
	extends Node

	var failures: Array[String] = []


	func _ready() -> void:
		await get_tree().create_timer(0.6).timeout
		GameState.reset_campaign()
		TimeManager.reset(1)
		EconomyManager.reset()
		MarketManager.reset()
		InventoryManager.reset()
		RelationshipManager.reset()
		BridgeManager.reset()
		DungeonManager.reset()
		StoryEventManager.reset()
		ShopFurnitureManager.reset()
		DayBriefing.last_shown_day = TimeManager.day
		MultiplayerState.set_enabled(true)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))

		SceneRouter.go("town")
		await get_tree().create_timer(1.4).timeout
		var town := get_tree().current_scene
		_check_world_companions(town, "town")
		await _save_shot("01_town.png")

		SceneRouter.go("shop")
		await get_tree().create_timer(1.4).timeout
		var shop := get_tree().current_scene
		_check_world_companions(shop, "shop")
		await _save_shot("02_shop.png")

		DungeonManager.plan_expedition("kingdom_hearts", "sora", [], false, "sora")
		SceneRouter.go("dungeon")
		await get_tree().create_timer(1.6).timeout
		var dungeon := get_tree().current_scene
		_check_dungeon_identities(dungeon)
		await _save_shot("03_expedition.png")

		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await get_tree().create_timer(0.3).timeout
		MultiplayerState.set_enabled(false)
		if failures.is_empty():
			print("MULTIPLAYER_IDENTITY_PROBE_PASS")
			get_tree().quit(0)
		else:
			for failure in failures:
				printerr("MULTIPLAYER_IDENTITY_PROBE_FAIL: ", failure)
			get_tree().quit(1)


	func _check_world_companions(scene: Node, context: String) -> void:
		var p1 := scene.get("player") as Node2D
		var p2 := scene.get("player2") as Node2D
		var patch := scene.get_node_or_null("PatchSidekick") as PatchFollower
		var sidekick := scene.get_node_or_null("P2Sidekick") as PatchFollower
		_expect(p1 != null and p2 != null, "%s did not create both players" % context)
		_expect(patch != null and patch.target == p1, "%s Patch is not attached to P1" % context)
		_check_p2_sidekick(sidekick, p2, context)


	func _check_dungeon_identities(dungeon: Node) -> void:
		var p1 := dungeon.get("hero") as CombatHero
		var p2 := dungeon.get("hero2") as CombatHero
		var patch := dungeon.get_node_or_null("PatchSidekick") as PatchFollower
		var sidekick := dungeon.get_node_or_null("P2Sidekick") as PatchFollower
		_expect(p1 != null and p2 != null, "expedition did not create both heroes")
		_expect(patch != null and patch.target == p1, "expedition Patch is not attached to P1")
		_check_p2_sidekick(sidekick, p2, "expedition")
		_check_label(p1, "P1", Color("#ff9999"))
		_check_label(p2, "P2", Color("#8fd8ff"))


	func _check_p2_sidekick(sidekick: PatchFollower, p2: Node2D, context: String) -> void:
		_expect(sidekick != null and sidekick.target == p2,
			"%s blue sidekick is not attached to P2" % context)
		if sidekick == null:
			return
		_expect(sidekick.manifest_path == "res://assets/shared/effects/p2_sidekick.json",
			"%s P2 sidekick has the wrong manifest" % context)
		_expect(sidekick.visual != null and sidekick.visual.use_frames,
			"%s P2 sidekick art did not load" % context)
		if sidekick.visual != null and sidekick.visual.animated != null:
			var tex := sidekick.visual.animated.sprite_frames.get_frame_texture("idle_down", 0)
			_expect(tex != null and tex.get_width() == 17 and tex.get_height() == 17,
				"%s P2 sidekick frame was not sliced to 17x17" % context)


	func _check_label(hero: CombatHero, expected_text: String, expected_color: Color) -> void:
		if hero == null:
			return
		var tag := hero.get_node_or_null("PlayerIdentityLabel") as Label
		_expect(tag != null, "%s expedition label is missing" % expected_text)
		if tag == null:
			return
		_expect(tag.text == expected_text, "%s expedition label text is wrong" % expected_text)
		_expect(tag.get_theme_font_size("font_size") == 12,
			"%s expedition label is not the larger 12px size" % expected_text)
		_expect(tag.get_theme_color("font_color").is_equal_approx(expected_color),
			"%s expedition label color is wrong" % expected_text)
		_expect(tag.position.y < hero.visual.top_y(),
			"%s expedition label is not above the hero" % expected_text)


	func _save_shot(filename: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)
		_expect(error == OK, "could not save screenshot %s" % filename)


	func _expect(condition: bool, message: String) -> void:
		if not condition:
			failures.append(message)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
