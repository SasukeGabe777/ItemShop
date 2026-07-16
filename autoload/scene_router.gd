extends Node
## SceneRouter: central scene navigation with a context dictionary for passing
## parameters between scenes.

const SCENES := {
	"main_menu": "res://scenes/ui/main_menu.tscn",
	"town": "res://scenes/town/town.tscn",
	"shop": "res://scenes/shop/shop.tscn",
	"dungeon": "res://scenes/dungeon/dungeon.tscn",
	"story": "res://scenes/story/story_player.tscn",
	"ending": "res://scenes/story/ending.tscn",
}

var context: Dictionary = {}
var last_town_position: Vector2 = Vector2.ZERO


func go(scene_key: String, ctx: Dictionary = {}) -> void:
	context = ctx
	var path: String = SCENES.get(scene_key, "")
	if path == "":
		push_error("[SceneRouter] unknown scene key %s" % scene_key)
		return
	get_tree().call_deferred("change_scene_to_file", path)


func start_new_campaign(slot: int) -> void:
	GameState.reset_campaign()
	GameState.current_slot = slot
	TimeManager.reset(1)
	EconomyManager.reset()
	MarketManager.reset()
	InventoryManager.reset()
	RelationshipManager.reset()
	BridgeManager.reset()
	DungeonManager.reset()
	StoryEventManager.reset()
	StoryEventManager.fire("game_start")
	StoryEventManager.fire("chapter_start", {"chapter": 1})
	SaveManager.checkpoint_chapter()
	SaveManager.save_to_slot(slot)
	go("town")


func continue_campaign(slot: int) -> bool:
	if not SaveManager.load_from_slot(slot):
		return false
	go("town")
	return true
