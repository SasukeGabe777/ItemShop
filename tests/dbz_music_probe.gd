extends Node
## Verifies the DBZ dungeon track (dungeon_dragon_ball) resolves to a real
## stream after the dungeon_dbz.mp3 file mapping fix.
func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var world := ContentDatabase.get_world("dragon_ball")
	var track := "final_dungeon" if bool(world.get("final", false)) else "dungeon_dragon_ball"
	var stream := AudioManager._resolve_stream(track)
	if stream != null:
		print("DBZ_MUSIC_PROBE_PASS track=%s stream=%s" % [track, stream.resource_path])
		get_tree().quit(0)
	else:
		printerr("DBZ_MUSIC_PROBE_FAIL: %s resolved to null" % track)
		get_tree().quit(1)
