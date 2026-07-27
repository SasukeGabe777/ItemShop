extends Node
## Realm of the Mad God must resolve its explicitly mapped user-override MP3.


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var world := ContentDatabase.get_world("rotmg")
	var track := "final_dungeon" if bool(world.get("final", false)) \
		else "dungeon_rotmg"
	var stream := AudioManager._resolve_stream(track)
	if stream != null and stream.resource_path.ends_with("rotmg_dungeon.mp3"):
		print("ROTMG_MUSIC_PROBE_PASS track=%s stream=%s" % [
			track, stream.resource_path])
		get_tree().quit(0)
	else:
		printerr("ROTMG_MUSIC_PROBE_FAIL track=%s stream=%s" % [
			track, stream.resource_path if stream != null else "null"])
		get_tree().quit(1)
