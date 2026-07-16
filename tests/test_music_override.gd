extends Node
## Verifies the music override resolution picks user files over defaults.

func _ready() -> void:
	var ok := true
	for track in ["item_shop", "main_menu"]:
		var stream: AudioStream = AudioManager._resolve_stream(track)
		var is_override := stream is AudioStreamOggVorbis  # defaults are WAV
		print("%s -> %s (%s)" % [track, stream, "OVERRIDE" if is_override else "default"])
		if stream == null or not is_override:
			ok = false
	# a track with no override must still resolve to its default
	var def_stream: AudioStream = AudioManager._resolve_stream("boss_battle")
	if def_stream == null:
		ok = false
	print("MUSIC_OVERRIDE_%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
