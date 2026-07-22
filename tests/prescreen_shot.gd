extends Node
## Pre-screen probe (windowed): tours the shared town + shop, then every BUILT
## world's dungeon (start room / a combat room / boss arena) and screenshots
## each into user://screenshots/prescreen_*.png. Purpose: triage obvious render
## / layout / animation breakage across all built worlds before a human plays,
## so the human's controller time is spent on pre-vetted content.
##
## Run WINDOWED (no --headless — headless returns null viewport textures):
##   tools\Godot_v4.7.1-stable_win64_console.exe --path . res://tests/prescreen_shot.tscn

const WORLDS := [
	["kingdom_hearts", "sora"],
	["mario", "mario"],
	["final_fantasy", "cloud"],
	["zelda", "link"],
	["naruto", "naruto"],
	["dragon_ball", "goku"],
]

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Runner:
	extends Node

	func _fresh() -> void:
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

	func _shot(tag: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/prescreen_%s.png" % tag)
		print("SHOT prescreen_%s" % tag)

	func _ready() -> void:
		await get_tree().create_timer(0.8).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")

		# --- shared town + shop (start of the loop) ---
		_fresh()
		EconomyManager.add_gold(5000)
		for id in ["kingdom_key", "sea_salt_ice_cream", "super_mushroom", "kh_potion"]:
			InventoryManager.add_item(id, 2)
		get_tree().change_scene_to_file("res://scenes/town/town.tscn")
		await get_tree().create_timer(1.8).timeout
		_shot("town")
		get_tree().change_scene_to_file("res://scenes/shop/shop.tscn")
		await get_tree().create_timer(1.8).timeout
		_shot("shop")

		# --- each built world's dungeon ---
		for entry in WORLDS:
			var world: String = entry[0]
			var hero: String = entry[1]
			_fresh()
			GameState.meet_hero(hero)
			DungeonManager.plan_expedition(world, hero, [])
			SceneRouter.go("dungeon")
			await get_tree().create_timer(2.2).timeout
			var dun: Node = get_tree().current_scene
			if dun == null or not "layout" in dun:
				print("WARN %s: no dungeon layout (dun=%s)" % [world, dun])
				continue
			var layout: Array = dun.layout
			print("%s: %d rooms, kinds=%s" % [world, layout.size(),
				str(layout.map(func(r): return r.get("kind", "?")))])
			_shot("%s_start" % world)
			# a combat room
			for i in range(layout.size()):
				if String(layout[i].get("kind", "")) == "combat":
					dun._enter_room(i)
					await get_tree().create_timer(1.0).timeout
					_shot("%s_combat" % world)
					break
			# boss arena (last room)
			dun._enter_room(layout.size() - 1)
			await get_tree().create_timer(1.0).timeout
			_shot("%s_boss" % world)

		print("PRESCREEN_SHOT_DONE: " + ProjectSettings.globalize_path("user://screenshots/"))
		get_tree().quit()
