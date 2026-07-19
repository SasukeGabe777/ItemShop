extends Node2D
## Probe: the Zelda world pass. Verifies the Hyrule boss rotation, the
## dungeon_zelda music override, Link's directional sword animations, the
## bomb special (fuse + contact detonation), every MC manifest, then
## screenshots the roster and a real Hyrule run as Link.

const IDS := ["keese", "octorok", "chuchu_green", "chuchu_blue", "rope", "leever",
	"ghini", "keaton", "spiked_beetle", "moblin", "stalfos", "darknut",
	"big_green_chuchu", "big_blue_chuchu", "vaati"]


func _ready() -> void:
	await get_tree().process_frame
	# --- logic checks -------------------------------------------------------
	GameState.reset_campaign()
	DungeonManager.reset()
	var rot: Array[String] = []
	for wins in range(4):
		GameState.stats["expedition_wins_zelda"] = wins
		rot.append(DungeonManager.boss_for_world("zelda"))
	print("ZELDA boss rotation by wins 0..3: ", rot)
	var stream: AudioStream = AudioManager._resolve_stream("dungeon_zelda")
	print("ZELDA music resolves: ", stream != null)
	var link_frames := SpriteFramesBuilder.from_manifest_path("res://assets/franchises/zelda/manifests/link.json")
	var need := ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side",
		"attack_1_down", "attack_1_side", "attack_1_up",
		"attack_2_down", "attack_2_side", "attack_2_up"]
	var missing: Array[String] = []
	for a in need:
		if link_frames == null or not link_frames.has_animation(a):
			missing.append(a)
	print("LINK anims missing: ", missing)
	var expl := SpriteFramesBuilder.from_manifest_path("res://assets/franchises/zelda/manifests/bomb_explosion.json")
	print("EXPLOSION anim ok: ", expl != null and expl.has_animation("explode"))
	for id in IDS:
		var f := SpriteFramesBuilder.from_manifest_path("res://assets/franchises/zelda/manifests/%s.json" % id)
		if f == null:
			print("ENEMY manifest FAILED: ", id)
	var link_def := ContentDatabase.get_hero("link")
	print("LINK special kind: ", link_def.get("combat", {}).get("special", {}).get("kind", "?"))

	# --- bomb behavior: fuse timeout ---------------------------------------
	var dummy := _make_dummy_enemy(Vector2(40, 0))
	var bomb := Bomb.new()
	bomb.setup({"damage": 25, "knockback": 100.0, "source": self}, 60.0, 0.3, 8)
	bomb.position = Vector2.ZERO
	add_child(bomb)
	await get_tree().create_timer(0.6).timeout
	print("BOMB fuse exploded: ", not bomb.is_armed(), " dealt: ", dummy.get_meta("dmg", 0))
	# --- bomb behavior: contact detonation ---------------------------------
	var bomb2 := Bomb.new()
	bomb2.setup({"damage": 25, "knockback": 100.0, "source": self}, 60.0, 30.0, 8)
	bomb2.position = Vector2(200, 0)
	add_child(bomb2)
	var hb := HurtboxComponent.new()
	hb.collision_layer = 8
	hb.collision_mask = 0
	var hs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = 8.0
	hs.shape = hc
	hb.add_child(hs)
	hb.position = Vector2(204, 0)
	add_child(hb)
	await get_tree().create_timer(0.4).timeout
	print("BOMB contact exploded: ", not bomb2.is_armed())

	# --- roster lineup screenshot ------------------------------------------
	var bg := ColorRect.new()
	bg.color = Color("#2f5d33")
	bg.size = Vector2(1300, 700)
	bg.z_index = -50
	add_child(bg)
	var target := Node2D.new()
	target.position = Vector2(640, 640)
	add_child(target)
	for i in range(IDS.size()):
		var e := Enemy.new()
		add_child(e)
		e.setup(IDS[i], target)
		e.position = Vector2(80 + (i % 6) * 130, 150 + (i / 6) * 200)
		e.set_physics_process(false)
		var tag := UIKit.label(IDS[i], 6, UIKit.COL_ACCENT)
		tag.position = e.position + Vector2(-30, 8)
		add_child(tag)
	var dirs := {"down": Vector2(0, 1), "up": Vector2(0, -1), "side": Vector2(1, 0)}
	var i := 0
	for dname: String in dirs:
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest("res://assets/franchises/zelda/manifests/link.json")
		cv.position = Vector2(1000 + i * 70, 560)
		cv.face(dirs[dname], true)
		var tag2 := UIKit.label("link " + dname, 6, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-20, 8)
		add_child(tag2)
		i += 1
	var atk := CharacterVisual.new()
	add_child(atk)
	atk.setup_from_manifest("res://assets/franchises/zelda/manifests/link.json")
	atk.position = Vector2(1000 + i * 70, 560)
	atk.play_action("attack_1", Vector2(1, 0))
	var tag3 := UIKit.label("link atk", 6, UIKit.COL_GOOD)
	tag3.position = atk.position + Vector2(-20, 8)
	add_child(tag3)
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	get_viewport().get_texture().get_image().save_png("user://screenshots/zelda_lineup.png")
	# --- real Hyrule run as Link: hand off to a ROOT-parented prober so the
	# scene change doesn't free this script mid-await
	var prober := Node.new()
	prober.set_script(preload("res://tests/zelda_shot_dungeon.gd"))
	get_tree().root.add_child(prober)
	TimeManager.reset(4)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	DungeonManager.plan_expedition("zelda", "link", [], false)
	SceneRouter.go("dungeon")


func _make_dummy_enemy(pos: Vector2) -> Node2D:
	var dummy := Node2D.new()
	dummy.set_script(preload("res://tests/dummy_enemy.gd"))
	dummy.position = pos
	dummy.add_to_group("enemies")
	dummy.set_meta("dmg", 0)
	add_child(dummy)
	return dummy
