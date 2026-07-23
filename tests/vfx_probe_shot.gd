extends Node
## Verify the move_VFX wiring: 8-direction projectile ring (mapping check),
## enemy shooter art, boss volley/slam/charge effects, Naruto substitution
## dodge + rasengan clones special.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")

class Probe:
	extends Node
	func _shot(t: String) -> void:
		get_viewport().get_texture().get_image().save_png("user://screenshots/vfx_%s.png" % t)
		print("SHOT ", t)
	func _reset() -> void:
		GameState.reset_campaign(); TimeManager.reset(5); EconomyManager.reset()
		MarketManager.reset(); InventoryManager.reset(); RelationshipManager.reset()
		BridgeManager.reset(); DungeonManager.reset(); StoryEventManager.reset()
		ShopFurnitureManager.reset()
	func _ready() -> void:
		await get_tree().create_timer(0.9).timeout
		DirAccess.make_dir_recursive_absolute("user://screenshots/")
		# --- naruto: dodge sub + rasengan clones ---
		_reset()
		GameState.meet_hero("naruto")
		DungeonManager.plan_expedition("naruto", "naruto", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		var dun: Node = get_tree().current_scene
		var hero = dun.hero
		hero.facing = Vector2(1, 0)
		hero._do_dodge(true)
		await get_tree().create_timer(0.15).timeout
		_shot("naruto_sub")
		await get_tree().create_timer(0.6).timeout
		hero.meter = 100.0
		hero._do_special()
		await get_tree().create_timer(0.3).timeout
		_shot("naruto_rasengan")
		# 8-direction ring: flame set (rows S,SW,W,NW,N,NE,E,SE)
		await get_tree().create_timer(0.5).timeout
		for i in range(8):
			var ang := TAU * float(i) / 8.0
			var dirv := Vector2.RIGHT.rotated(ang)
			var p := Projectile.new()
			p.setup({"damage": 0, "knockback": 0.0, "source": hero}, dirv, 40.0, Color.WHITE, 0)
			p.global_position = hero.global_position + Vector2(0, -10)
			dun.add_child(p)
			p.set_art("res://assets/shared/effects/processed/shot_flame.png", 4, 8, EffectFlipbook.dir8(dirv), 14)
		await get_tree().create_timer(0.6).timeout
		_shot("dir_ring")
		# --- boss effects: mewtwo room ---
		_reset()
		GameState.meet_hero("pikachu")
		GameState.stats["expedition_wins_pokemon"] = 2
		DungeonManager.plan_expedition("pokemon", "pikachu", [])
		SceneRouter.go("dungeon")
		await get_tree().create_timer(3.0).timeout
		dun = get_tree().current_scene
		hero = dun.hero
		dun._enter_room(dun.layout.size() - 1)
		await get_tree().create_timer(1.0).timeout
		var boss = null
		for b in get_tree().get_nodes_in_group("boss"):
			boss = b; break
		if boss != null:
			boss.set_physics_process(false)
			boss._volley()
			await get_tree().create_timer(0.35).timeout
			_shot("boss_volley")
			await get_tree().create_timer(0.8).timeout
			boss._slam()
			await get_tree().create_timer(0.25).timeout
			_shot("boss_slam")
			await get_tree().create_timer(0.6).timeout
			boss._charge()
			await get_tree().create_timer(0.2).timeout
			_shot("boss_charge")
		# --- standard shooter art: magnemite room ---
		var shooter = null
		for i in range(dun.layout.size()):
			if String(dun.layout[i].get("kind", "")) == "combat":
				dun._enter_room(i)
				await get_tree().create_timer(0.8).timeout
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e.behavior in ["shooter", "skitter_shooter"]:
						shooter = e; break
				if shooter != null: break
		if shooter != null:
			shooter.global_position = hero.global_position + Vector2(120, 0)
			shooter._shoot(Vector2.LEFT)
			shooter._shoot(Vector2(0, 1))
			await get_tree().create_timer(0.3).timeout
			_shot("enemy_shots")
		else:
			print("NO_SHOOTER_FOUND")
		print("VFX_VERIFY_DONE")
		get_tree().quit()
