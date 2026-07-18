extends Node2D
## End-to-end smoke test for the first playable Kingdom Hearts loop. It uses
## the real furniture, display, customer, negotiation, dungeon, loot and save
## managers, plus the live Dungeon scene for the Shadow encounter.

const SHOP_SCENE := preload("res://scenes/shop/shop.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon/dungeon.tscn")
const TEST_SLOT := 3

var failures: Array[String] = []
var dungeon: Node2D
var phase := "setup"
var elapsed := 0.0
var original_slot_exists := false
var original_slot_text := ""
var moved_furniture_uid := 0
var moved_furniture_position := Vector2.ZERO
var attack_pressed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_test_slot()
	_reset_as_new_campaign()
	_check(DevHubManager.start_playtest_session(), "Playtest Workspace session starts")
	_check(InventoryManager.count("kh_potion") == 3, "new game starts with three Potions")
	_check(InventoryManager.count("kh_ether") == 2, "new game starts with two Ethers")
	_check(InventoryManager.count("rupee") == 2, "new game starts with a generic valuable")
	_check(String(InventoryManager.hero_equipment.get("sora", {}).get("weapon", "")) == "kingdom_key", "Sora starts with the Kingdom Key")
	_test_first_shop_sale()
	_start_live_expedition()


func _reset_as_new_campaign() -> void:
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
	var cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	GameState.set_flag(String(cfg.get("active_flag", "kh_vertical_slice_started")))


func _test_first_shop_sale() -> void:
	ShopFurnitureManager.ensure_layout()
	_check(not ShopFurnitureManager.layout.is_empty(), "the shop starts with movable display furniture")
	var first: Dictionary = ShopFurnitureManager.layout[0]
	moved_furniture_uid = int(first.get("uid", 0))
	var candidate := _find_valid_furniture_position(moved_furniture_uid)
	_check(candidate != Vector2.ZERO, "a valid moved stand position exists")
	if candidate != Vector2.ZERO:
		_check(ShopFurnitureManager.move_instance(moved_furniture_uid, candidate), "the item stand can be moved")
		moved_furniture_position = candidate
	_check(InventoryManager.place_display(0, "kh_potion"), "a Potion can be placed on the moved stand")
	GameState.tutorials_seen.append("first_shop_vertical_slice")
	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	_check(not shop.browse_points.is_empty(), "customers receive dynamic display-slot targets")
	var slot: Dictionary = ShopFurnitureManager.get_all_available_display_slots()[0]
	_check((slot.get("position", Vector2.ZERO) as Vector2).distance_to(moved_furniture_position) < 40.0, "the browse target follows the moved stand")
	var customers := CustomerGen.generate_session_customers()
	_check(customers.size() == 1, "the onboarding shop session uses one deterministic customer")
	if not customers.is_empty():
		var interest := ShopFurnitureManager.choose_display_slot_for_customer(customers[0])
		_check(String(interest.get("item_id", "")) == "kh_potion", "the customer inspects the displayed Potion")
		shop._spawn_customer(customers[0])
		var live_customer: ShopCustomer = shop.live_customers[0]
		_check(not live_customer._waypoints.is_empty() and live_customer._waypoints[-1].distance_to(shop.browse_points[0]) < 20.0, "the live customer walks to the stocked stand")
		var before_gold := EconomyManager.gold
		var nego := Negotiation.start(customers[0], "kh_potion")
		var outcome := nego.propose(nego.market_value)
		_check(String(outcome.get("result", "")) in [Negotiation.RESULT_ACCEPT, Negotiation.RESULT_PERFECT], "the first negotiation can complete")
		nego.finalize_sale(outcome)
		_check(EconomyManager.gold > before_gold, "the purchase increases money")
		_check(not ("kh_potion" in InventoryManager.displayed_ids()), "the purchase removes the displayed item")
	TimeManager.advance(TimeManager.activity_cost("open_shop"))
	shop.queue_free()


func _find_valid_furniture_position(uid: int) -> Vector2:
	for pos in [Vector2(170, 360), Vector2(470, 360), Vector2(320, 360), Vector2(320, 210)]:
		if ShopFurnitureManager.placement_valid(uid, pos, Rect2(150, 132, 340, 258)):
			return pos
	return Vector2.ZERO


func _start_live_expedition() -> void:
	var cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	DungeonManager.plan_expedition(String(cfg.get("world_id", "kingdom_hearts")), String(cfg.get("hero_id", "sora")), [], true)
	var layout := DungeonManager.generate_layout("kingdom_hearts", 7, true)
	_check(layout.size() == 2, "the first Traverse Town expedition has two rooms")
	if layout.size() == 2:
		_check(String(layout[0].get("kind", "")) == "start", "the first room is a readable arrival room")
		_check(layout[1].get("enemies", []) == ["shadow_heartless"], "the combat room contains one Shadow")
	dungeon = DUNGEON_SCENE.instantiate()
	add_child(dungeon)
	_check(dungeon.hero != null and dungeon.hero.hero_id == "sora", "the live expedition launches with Sora")
	phase = "leave_arrival"


func _physics_process(delta: float) -> void:
	if phase in ["done", "setup"] or dungeon == null or not is_instance_valid(dungeon):
		return
	elapsed += delta
	if elapsed > 25.0:
		var enemy := _live_enemy()
		var detail := "phase=%s room=%d door=%s loot=%s" % [phase, int(dungeon.room_index), bool(dungeon.door_open), DungeonManager.run_loot]
		if enemy is Enemy:
			detail += " enemy_hp=%d" % int((enemy as Enemy).health.hp)
		_fail("the live expedition did not finish within 25 seconds (%s)" % detail)
		_finish_test()
		return
	if dungeon.finished:
		_complete_after_dungeon()
		return
	match phase:
		"leave_arrival":
			if dungeon.door_open:
				dungeon.hero.global_position = Vector2(320, 0)
				phase = "fight_shadow"
		"fight_shadow":
			var enemy := _live_enemy()
			if enemy != null:
				dungeon.hero.global_position = enemy.global_position + Vector2(0, 20)
				dungeon.hero.facing = Vector2.UP
				attack_pressed = not attack_pressed
				if attack_pressed:
					Input.action_press("attack")
				else:
					Input.action_release("attack")
			elif dungeon.room_index == 1:
				Input.action_release("attack")
				phase = "collect_reward"
		"collect_reward":
			var pickup := _live_reward_pickup()
			if pickup != null:
				dungeon.hero.global_position = pickup.global_position
			elif DungeonManager.run_loot.has("lucid_shard"):
				phase = "leave_combat"
		"leave_combat":
			if dungeon.door_open:
				dungeon.hero.global_position = Vector2(320, 0)
				phase = "await_finish"
		"await_finish":
			if dungeon.finished:
				_complete_after_dungeon()


func _live_enemy() -> Node2D:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and dungeon.is_ancestor_of(node):
			return node as Node2D
	return null


func _live_reward_pickup() -> LootPickup:
	for node in dungeon.room_root.get_children():
		if node is LootPickup and String((node as LootPickup).item_id) == "lucid_shard":
			return node as LootPickup
	return null


func _complete_after_dungeon() -> void:
	phase = "verifying"
	Input.action_release("attack")
	var cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	_check(InventoryManager.count("lucid_shard") >= 1, "collected dungeon loot returns to shop storage")
	_check(GameState.has_flag(String(cfg.get("completion_flag", ""))), "vertical-slice progress is recorded")
	dungeon.queue_free()
	_test_recovered_item_sale(cfg)
	_test_save_reload(cfg)
	_finish_test()


func _test_recovered_item_sale(cfg: Dictionary) -> void:
	_check(InventoryManager.place_display(0, "lucid_shard"), "the recovered Lucid Shard can be displayed")
	var customers := CustomerGen.generate_session_customers()
	_check(customers.size() == 1, "the recovered-item session uses the same deterministic customer")
	if customers.is_empty():
		return
	var interest := ShopFurnitureManager.choose_display_slot_for_customer(customers[0])
	_check(String(interest.get("item_id", "")) == "lucid_shard", "the customer selects the recovered item dynamically")
	var before_gold := EconomyManager.gold
	var nego := Negotiation.start(customers[0], "lucid_shard")
	var outcome := nego.propose(nego.market_value)
	nego.finalize_sale(outcome)
	_check(EconomyManager.gold > before_gold, "selling recovered loot increases money")
	_check(GameState.has_flag(String(cfg.get("reward_sale_flag", ""))), "the recovered-item sale is recorded")


func _test_save_reload(cfg: Dictionary) -> void:
	_check(InventoryManager.place_display(0, "kh_ether"), "an Ether can remain displayed for the save test")
	var saved_gold := EconomyManager.gold
	var saved_storage: Dictionary = {}
	for id: String in InventoryManager.storage:
		saved_storage[id] = InventoryManager.count(id)
	var saved_chapter := TimeManager.chapter
	_check(SaveManager.save_to_slot(TEST_SLOT), "the completed loop saves to a normal campaign slot")
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	InventoryManager.reset()
	ShopFurnitureManager.reset()
	_check(SaveManager.load_from_slot(TEST_SLOT), "the completed loop reloads")
	_check(EconomyManager.gold == saved_gold, "money persists after reload")
	var storage_matches := true
	for id: String in saved_storage:
		if InventoryManager.count(id) != int(saved_storage[id]):
			storage_matches = false
	for id: String in InventoryManager.storage:
		if not saved_storage.has(id):
			storage_matches = false
	_check(storage_matches, "shop storage persists after reload")
	_check(String(InventoryManager.display[0]) == "kh_ether", "displayed items persist after reload")
	_check(TimeManager.chapter == saved_chapter, "chapter progress persists after reload")
	_check(GameState.has_flag(String(cfg.get("completion_flag", ""))), "world-slice progress persists after reload")
	var moved := ShopFurnitureManager.instance_by_uid(moved_furniture_uid)
	var pos: Array = moved.get("pos", [0.0, 0.0])
	_check(Vector2(float(pos[0]), float(pos[1])).is_equal_approx(moved_furniture_position), "movable stand placement persists after reload")


func _capture_test_slot() -> void:
	var path := SaveManager.slot_path(TEST_SLOT)
	original_slot_exists = FileAccess.file_exists(path)
	if original_slot_exists:
		original_slot_text = FileAccess.open(path, FileAccess.READ).get_as_text()


func _restore_test_slot() -> void:
	var path := SaveManager.slot_path(TEST_SLOT)
	if original_slot_exists:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(original_slot_text)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [KH slice] " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	printerr("KH_VERTICAL_SLICE_FAIL: " + message)


func _finish_test() -> void:
	if phase == "done":
		return
	phase = "done"
	Input.action_release("attack")
	_restore_test_slot()
	if failures.is_empty():
		DevHubManager.add_playtest_note("polish", "Automated full Kingdom Hearts vertical-slice route passed: shop sale, Sora expedition, Shadow combat, Lucid Shard return and resale, save/reload.")
	else:
		DevHubManager.add_playtest_note("blocking bug", "Automated Kingdom Hearts vertical-slice route failed: %s" % "; ".join(failures))
	DevHubManager.end_playtest_session()
	if failures.is_empty():
		print("KH_VERTICAL_SLICE_PASS")
	call_deferred("_quit_after_cleanup")


func _quit_after_cleanup() -> void:
	AudioManager.stop_music()
	AudioManager.stinger_player.stop()
	await get_tree().create_timer(0.25).timeout
	AudioManager.music_player.stream = null
	AudioManager.stinger_player.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
