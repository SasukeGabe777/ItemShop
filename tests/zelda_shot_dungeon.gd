extends Node
## Second stage of zelda_shot: lives on the root so it survives the scene
## change into the Hyrule dungeon, screenshots it, and quits.


func _ready() -> void:
	await get_tree().create_timer(1.8).timeout
	get_viewport().get_texture().get_image().save_png("user://screenshots/zelda_dungeon.png")
	print("ZELDA music track playing: ", AudioManager.current_track)
	print("ZELDA_SHOT_DONE")
	get_tree().quit()
