extends Node
## Probe: fresh state -> Dragon Ball dungeon with Piccolo. Verifies the new
## room backgrounds (start cabin / combat / ruined-dome treasure / crater
## boss), obstacle props, the SBC beam special in a live room, the fly dodge,
## and the dungeon music track.
class Probe:
	extends Node
	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
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
		GameState.meet_hero("piccolo")
		DungeonManager.plan_expedition("dragon_ball", "piccolo", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(2.5).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		print("TRACK=", AudioManager.current_track, " stream=", AudioManager.music_player.stream != null)
		Input.action_press("move_down")
		await get_tree().create_timer(0.45).timeout
		Input.action_release("move_down")
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_start.png")
		# ESC pause menu: opens with a Retreat option, then close it again
		print("HASACTION=", InputMap.has_action("pause_menu"),
			" MODAL=", UIKit.modal_open(),
			" FINISHED=", get_tree().current_scene.get("finished"))
		Input.action_press("pause_menu")
		await get_tree().create_timer(0.05).timeout
		Input.action_release("pause_menu")
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_pause.png")
		print("PAUSED=", get_tree().paused)
		get_tree().paused = false
		for holder: Node in [get_tree().root, get_tree().current_scene]:
			for l in holder.get_children():
				if l is CanvasLayer and l.process_mode == Node.PROCESS_MODE_WHEN_PAUSED:
					l.queue_free()
		await get_tree().create_timer(0.2).timeout
		var dun: Node = get_tree().current_scene
		# combat room: props + enemies + the SBC beam
		dun._enter_room(1)
		await get_tree().create_timer(0.9).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_combat.png")
		dun.hero.meter = 100.0
		Input.action_press("move_right")
		await get_tree().create_timer(0.25).timeout
		Input.action_release("move_right")
		Input.action_press("special")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("special")
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_beam.png")
		# fly dodge
		Input.action_press("move_down")
		await get_tree().create_timer(0.1).timeout
		Input.action_release("move_down")
		Input.action_press("dodge")
		await get_tree().create_timer(0.12).timeout
		Input.action_release("dodge")
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_fly.png")
		# a later combat room variant + treasure + boss arena
		dun._enter_room(2)
		await get_tree().create_timer(0.9).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_combat2.png")
		for i in range(dun.layout.size()):
			if String(dun.layout[i].get("kind", "")) == "treasure":
				dun._enter_room(i)
				await get_tree().create_timer(0.9).timeout
				get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_treasure.png")
				break
		dun._enter_room(dun.layout.size() - 1)
		await get_tree().create_timer(0.9).timeout
		dun.hero.global_position = Vector2(320, 220)
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("user://screenshots/dbz_boss.png")
		# Goku still selectable for this world too (hero switch data intact)
		print("WORLD_HEROES=", ContentDatabase.get_world("dragon_ball").get("heroes"))
		print("DBZ_DUNGEON_SHOT_DONE")
		get_tree().quit()

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
