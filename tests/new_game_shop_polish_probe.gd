extends Node
## Headless regression coverage for the opening story promise, starter
## furniture, refreshed tutorial language, overlapping SFX, and one-person
## online shop exits.

const STORY_SCRIPT := preload("res://scripts/story/story_player.gd")
const SHOP_SCRIPT := preload("res://scripts/shop/shop.gd")

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	InventoryManager.reset()
	ShopFurnitureManager.reset()
	_check_story_space()
	_check_starting_shop()
	_check_tutorial_copy()
	_check_audio_voices()
	_check_single_player_exit_gate()
	if failures.is_empty():
		print("NEW_GAME_SHOP_POLISH_PROBE_PASS")
	else:
		for message: String in failures:
			printerr("NEW_GAME_SHOP_POLISH_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_story_space() -> void:
	var story: Node = STORY_SCRIPT.new()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	_check(story._is_continue_event(space),
		"Space does not satisfy the story's displayed continue prompt")
	story.free()


func _check_starting_shop() -> void:
	var types: Array[String] = []
	for instance: Dictionary in ShopFurnitureManager.layout:
		types.append(String(instance.get("type", "")))
	types.sort()
	var expected: Array[String] = [
		"basic_item_stand", "basic_item_stand", "small_display_crate"]
	expected.sort()
	_check(types == expected,
		"new shop layout is %s, expected two stands and one crate" % [types])
	_check(ShopFurnitureManager.total_slot_count() == 4,
		"starter furniture no longer provides four display slots")
	var attention: Array[float] = []
	for slot in 4:
		attention.append(ShopFurnitureManager.slot_attention_bonus(slot))
	_check(attention == [0.5, 0.5, 0.0, 0.0],
		"starter furniture changed the original window attention balance: %s"
			% [attention])


func _check_tutorial_copy() -> void:
	var shop: Node = SHOP_SCRIPT.new()
	var steps: Array[String] = shop._first_shop_guide_steps()
	_check(steps.size() == 4, "first-shop guide does not contain four steps")
	_check("choose an item" in steps[1].to_lower(),
		"first-shop guide still names static starter items")
	for feature: String in ["Buy Furniture", "Decorate", "Rearrange Furniture"]:
		_check(feature in steps[2],
			"first-shop guide omits %s" % feature)
	shop.free()


func _check_audio_voices() -> void:
	_check(AudioManager.sfx_players.size() == AudioManager.SFX_VOICE_COUNT,
		"AudioManager did not create the overlapping SFX voice pool")
	var cursor_before := AudioManager._sfx_cursor
	AudioManager.play_sfx("itemsale")
	AudioManager.play_sfx("achievement_unlocked")
	AudioManager.play_sfx("menu_close")
	_check(AudioManager._sfx_cursor
			== (cursor_before + 3) % AudioManager.SFX_VOICE_COUNT,
		"same-frame deal effects did not use separate SFX voices")


func _check_single_player_exit_gate() -> void:
	PartyState.set_online_roster([
		PartyState.make_seat(1, 1, "Host", false),
		PartyState.make_seat(2, 2, "Partner", false),
	], 1)
	_check(PartyState.ready_up("leave_shop_probe", 1, 1),
		"online shop exit still requires the whole party")
	PartyState.clear_online()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
