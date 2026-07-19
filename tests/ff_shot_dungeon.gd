extends Node
## Second stage of ff_shot: lives on the root so it survives the scene
## change into the dungeon, screenshots it, and quits.


func _ready() -> void:
	await get_tree().create_timer(1.8).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/ff_dungeon.png")
	print("FF music track playing: ", AudioManager.current_track)
	print("FF_SHOT_DONE")
	get_tree().quit()
