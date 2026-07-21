extends Node2D
## Probe: what do dungeon blockers/walls/obstacles look like in every built
## world right now? Hands off to a root-parented stage that tours the five
## worlds' dungeons and screenshots a start room and an obstacle room each.


func _ready() -> void:
	await get_tree().process_frame
	var prober := Node.new()
	prober.set_script(preload("res://tests/blocker_shot_stage.gd"))
	get_tree().root.add_child(prober)
