extends Node2D
## Probe: the Naruto world. Logic checks (boss rotation, music resolution,
## manifests, item icons) then a roster/hero screenshot, then hands off to a
## root-parented stage 2 that plays a real Hidden Leaf run.

const ENEMIES := ["giant_snake", "forest_spider", "nin_panther", "hawk_scout",
	"cave_scorpion", "rogue_ninja", "mist_swordsman", "kunoichi_blade",
	"puppet", "bandit_brute", "clone_impostor", "sound_ninja", "jirobou", "tayuya"]
const BOSSES := ["zabuza", "kidomaru", "kimimaro"]
const ITEMS := ["kunai", "shuriken", "fuma_shuriken", "explosive_tag", "soldier_pill",
	"chakra_pill", "ninja_scroll", "summoning_scroll", "forehead_protector",
	"sharingan_fragment", "chakra_crystal", "ramen_bowl", "ichiraku_ticket",
	"training_weights", "smoke_bomb", "sannin_token", "fuma_shuriken",
	"makibishi_spikes", "substitution_log", "field_medkit", "gama_wallet",
	"dango_skewer", "ryo_pouch"]


func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_campaign()
	DungeonManager.reset()
	var rot: Array[String] = []
	for wins in range(4):
		GameState.stats["expedition_wins_naruto"] = wins
		rot.append(DungeonManager.boss_for_world("naruto"))
	print("NARUTO boss rotation by wins 0..3: ", rot)
	print("NARUTO music resolves: ", AudioManager._resolve_stream("dungeon_naruto") != null)

	var hero := SpriteFramesBuilder.from_manifest_path("res://assets/franchises/naruto/manifests/naruto.json")
	var need := ["idle_down", "walk_down", "idle_up", "walk_up", "idle_side", "walk_side",
		"attack_1_side", "attack_2_side"]
	var missing: Array[String] = []
	for a in need:
		if hero == null or not hero.has_animation(a):
			missing.append(a)
	print("NARUTO hero anims missing: ", missing)
	var bad: Array[String] = []
	for id in ENEMIES + BOSSES:
		if SpriteFramesBuilder.from_manifest_path("res://assets/franchises/naruto/manifests/%s.json" % id) == null:
			bad.append(id)
	print("NARUTO manifests failed: ", bad)
	var no_icon: Array[String] = []
	for iid in ITEMS:
		if not ResourceLoader.exists("res://assets/franchises/naruto/processed/items/%s.png" % iid):
			no_icon.append(iid)
	print("NARUTO items missing icons: ", no_icon)
	var w := ContentDatabase.get_world("naruto")
	var missing_bg: Array[String] = []
	for kind: String in w.get("room_backgrounds", {}):
		for p in w["room_backgrounds"][kind]:
			if not ResourceLoader.exists(String(p)):
				missing_bg.append(String(p))
	for p in w.get("obstacle_props", []):
		if not ResourceLoader.exists(String(p)):
			missing_bg.append(String(p))
	print("NARUTO missing room/prop art: ", missing_bg)
	var live: Array[String] = []
	for id in ContentDatabase.live_items:
		if String(ContentDatabase.get_item(id).get("world", "")) == "naruto":
			live.append(id)
	print("NARUTO live (sellable) items: ", live.size(), " ", live)

	# --- roster + hero screenshot -------------------------------------------
	var bg := ColorRect.new()
	bg.color = Color("#3f5d2f")
	bg.size = Vector2(660, 380)
	bg.z_index = -50
	add_child(bg)
	var target := Node2D.new()
	target.position = Vector2(320, 360)
	add_child(target)
	for i in range(ENEMIES.size()):
		var e := Enemy.new()
		add_child(e)
		e.setup(ENEMIES[i], target)
		e.position = Vector2(45 + (i % 7) * 88, 70 + (i / 7) * 95)
		e.set_physics_process(false)
		var tag := UIKit.label(ENEMIES[i], 5, UIKit.COL_ACCENT)
		tag.position = e.position + Vector2(-26, 5)
		add_child(tag)
	for i in range(BOSSES.size()):
		var b := Boss.new()
		add_child(b)
		b.setup(BOSSES[i], target)
		b.position = Vector2(90 + i * 150, 300)
		b.set_physics_process(false)
		var tag2 := UIKit.label(BOSSES[i], 5, UIKit.COL_BAD)
		tag2.position = b.position + Vector2(-24, 6)
		add_child(tag2)
	var dirs := {"down": Vector2(0, 1), "side": Vector2(1, 0), "up": Vector2(0, -1)}
	var i2 := 0
	for dname: String in dirs:
		var cv := CharacterVisual.new()
		add_child(cv)
		cv.setup_from_manifest("res://assets/franchises/naruto/manifests/naruto.json")
		cv.position = Vector2(470 + i2 * 55, 290)
		cv.face(dirs[dname], true)
		var t3 := UIKit.label(dname, 5, UIKit.COL_GOOD)
		t3.position = cv.position + Vector2(-10, 6)
		add_child(t3)
		i2 += 1
	var atk := CharacterVisual.new()
	add_child(atk)
	atk.setup_from_manifest("res://assets/franchises/naruto/manifests/naruto.json")
	atk.position = Vector2(470 + i2 * 55, 290)
	atk.play_action("attack_1", Vector2(1, 0))
	var t4 := UIKit.label("atk", 5, UIKit.COL_GOOD)
	t4.position = atk.position + Vector2(-8, 6)
	add_child(t4)
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/naruto_roster.png")

	var prober := Node.new()
	prober.set_script(preload("res://tests/naruto_shot_stage.gd"))
	get_tree().root.add_child(prober)
	TimeManager.reset(5)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	StoryEventManager.reset()
	DungeonManager.plan_expedition("naruto", "naruto", [], false)
	SceneRouter.go("dungeon")
