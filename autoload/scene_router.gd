extends Node
## SceneRouter: central scene navigation with a context dictionary for passing
## parameters between scenes.

signal scene_transition_requested(scene_key: String, path: String, context: Dictionary)

const SCENES := {
	"main_menu": "res://scenes/ui/main_menu.tscn",
	"town": "res://scenes/town/town.tscn",
	"shop": "res://scenes/shop/shop.tscn",
	"dungeon": "res://scenes/dungeon/dungeon.tscn",
	"story": "res://scenes/story/story_player.tscn",
	"dev_location": "res://scenes/dev/dev_location.tscn",
}

var context: Dictionary = {}
var last_town_position: Vector2 = Vector2.ZERO


func go(scene_key: String, ctx: Dictionary = {}) -> void:
	context = ctx
	var path: String = SCENES.get(scene_key, "")
	if path == "":
		push_error("[SceneRouter] unknown scene key %s" % scene_key)
		return
	scene_transition_requested.emit(scene_key, path, context.duplicate(true))
	AudioManager.play_sfx("loading_screens", -10.0)
	_drop_curtain()
	get_tree().call_deferred("change_scene_to_file", path)


## Instant black curtain over the old scene, fading out once the new scene
## has rendered — otherwise slow first loads leave a stale frame of the old
## scene on screen while the new scene's music/modals already run.
func _drop_curtain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	get_tree().root.add_child(layer)
	_lift_curtain(layer, black)


func _lift_curtain(layer: CanvasLayer, black: ColorRect) -> void:
	# wait until the new scene exists and has rendered a couple of frames
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var tw := black.create_tween()
	tw.tween_property(black, "modulate:a", 0.0, 0.22)
	tw.tween_callback(layer.queue_free)


func start_new_campaign(slot: int) -> void:
	GameState.reset_campaign()
	GameState.current_slot = slot
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	BoomManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	ShopFurnitureManager.reset()
	var slice_cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	var slice_active_flag := String(slice_cfg.get("active_flag", ""))
	if slice_active_flag != "":
		GameState.set_flag(slice_active_flag)
	StoryEventManager.fire("game_start")
	StoryEventManager.fire("chapter_start", {"chapter": 1})
	SaveManager.checkpoint_chapter()
	SaveManager.save_to_slot(slot)
	# day 1 morning never *advances* into a period, so seed the autosave here
	# to keep "every day portion has one" true from the very first minute
	SaveManager.autosave()
	go("town")


func continue_campaign(slot: int) -> bool:
	if not SaveManager.load_from_slot(slot):
		return false
	go("town")
	return true


## Resume from the rolling autosave taken at the last day portion.
func continue_autosave() -> bool:
	if not SaveManager.load_autosave():
		return false
	go("town")
	return true
