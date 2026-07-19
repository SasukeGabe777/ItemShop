extends Node2D
## Probe: the Final Fantasy world pass. Lines up the FF roster + the three
## rotation bosses, verifies Cloud's animations and the boss rotation +
## music variant cycling, then screenshots a real FF dungeon run as Cloud.

const IDS := ["ghost", "giant_rat", "guard_hound", "imperial_shadow", "soldier_3rd",
	"tonberry", "flan", "sand_worm", "ahriman", "malboro", "magitek_armor",
	"behemoth", "red_dragon", "kaiser_dragon", "goddess"]


func _ready() -> void:
	await get_tree().process_frame
	# --- logic checks -------------------------------------------------------
	GameState.reset_campaign()
	DungeonManager.reset()
	var rot: Array[String] = []
	for wins in range(4):
		GameState.stats["expedition_wins_final_fantasy"] = wins
		rot.append(DungeonManager.boss_for_world("final_fantasy"))
	print("FF boss rotation by wins 0..3: ", rot)
	var v1: AudioStream = AudioManager._resolve_stream("dungeon_final_fantasy")
	var v2: AudioStream = AudioManager._resolve_stream("dungeon_final_fantasy")
	var v3: AudioStream = AudioManager._resolve_stream("dungeon_final_fantasy")
	print("FF music variants: ", v1 != null, " ", v2 != null, " alternated=", v1 != v2, " cycles=", v1 == v3)
	var cloud_frames := SpriteFramesBuilder.from_manifest_path("res://assets/franchises/final_fantasy/manifests/cloud.json")
	var need := ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side", "attack_1", "attack_2"]
	var missing: Array[String] = []
	for a in need:
		if cloud_frames == null or not cloud_frames.has_animation(a):
			missing.append(a)
	print("CLOUD anims missing: ", missing)
	for id in IDS:
		var f := SpriteFramesBuilder.from_manifest_path("res://assets/franchises/final_fantasy/manifests/%s.json" % id)
		if f == null:
			print("ENEMY manifest FAILED: ", id)
	# --- enemy lineup screenshot -------------------------------------------
	var bg := ColorRect.new()
	bg.color = Color("#2c3050")
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
		e.position = Vector2(80 + (i % 6) * 128, 140 + (i / 6) * 190)
		e.set_physics_process(false)
		var tag := UIKit.label(IDS[i], 6, UIKit.COL_ACCENT)
		tag.position = e.position + Vector2(-30, 8)
		add_child(tag)
	# Cloud walking each direction beside the roster
	var dirs := {"down": Vector2(0, 1), "up": Vector2(0, -1), "side": Vector2(1, 0)}
	var i := 0
	for dname: String in dirs:
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest("res://assets/franchises/final_fantasy/manifests/cloud.json")
		cv.position = Vector2(1000 + i * 70, 560)
		cv.face(dirs[dname], true)
		var tag2 := UIKit.label("cloud " + dname, 6, UIKit.COL_GOOD)
		tag2.position = cv.position + Vector2(-20, 8)
		add_child(tag2)
		i += 1
	# one attacking Cloud
	var atk := CharacterVisual.new()
	add_child(atk)
	atk.setup_from_manifest("res://assets/franchises/final_fantasy/manifests/cloud.json")
	atk.position = Vector2(1000 + i * 70, 560)
	atk.play_action("attack_1", Vector2(1, 0))
	var tag3 := UIKit.label("cloud atk", 6, UIKit.COL_GOOD)
	tag3.position = atk.position + Vector2(-20, 8)
	add_child(tag3)
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	get_viewport().get_texture().get_image().save_png("user://screenshots/ff_lineup.png")
	# --- real dungeon run as Cloud: hand off to a ROOT-parented prober so
	# the scene change below doesn't free the code that's still running
	var prober := Node.new()
	prober.set_script(preload("res://tests/ff_shot_dungeon.gd"))
	get_tree().root.add_child(prober)
	TimeManager.reset(3)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	DungeonManager.plan_expedition("final_fantasy", "cloud", [], false)
	SceneRouter.go("dungeon")
