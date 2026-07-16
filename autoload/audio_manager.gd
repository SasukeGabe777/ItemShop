extends Node
## AudioManager: music playback with user-override resolution. A file named
## after a track id in user://music_overrides/ (or the project override folder)
## replaces the default track. OGG and WAV supported.

var music_player: AudioStreamPlayer
var stinger_player: AudioStreamPlayer
var current_track: String = ""
var music_volume_db: float = -8.0
var muted: bool = false


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	stinger_player = AudioStreamPlayer.new()
	stinger_player.bus = "Master"
	add_child(stinger_player)
	DirAccess.make_dir_recursive_absolute("user://music_overrides/")


func play_track(track_id: String) -> void:
	if track_id == current_track and music_player.playing:
		return
	var stream := _resolve_stream(track_id)
	current_track = track_id
	if stream == null:
		music_player.stop()
		return
	var manifest_tracks: Dictionary = ContentDatabase.music.get("tracks", {})
	var loop := bool(manifest_tracks.get(track_id, {}).get("loop", true))
	_set_loop(stream, loop)
	music_player.stream = stream
	music_player.volume_db = music_volume_db
	if not muted:
		music_player.play()


func play_stinger(track_id: String) -> void:
	var stream := _resolve_stream(track_id)
	if stream == null or muted:
		return
	_set_loop(stream, false)
	stinger_player.stream = stream
	stinger_player.volume_db = music_volume_db
	stinger_player.play()


func stop_music() -> void:
	music_player.stop()
	current_track = ""


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		music_player.stop()
	elif current_track != "":
		var t := current_track
		current_track = ""
		play_track(t)


func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			w.loop_begin = 0
			w.loop_end = w.data.size() / 2  # 16-bit mono frames
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop


## Resolution order: user:// overrides, project override folder, defaults.
func _resolve_stream(track_id: String) -> AudioStream:
	var manifest: Dictionary = ContentDatabase.music
	var tracks: Dictionary = manifest.get("tracks", {})
	var file_base := String(tracks.get(track_id, {}).get("file", track_id))
	var formats: Array = manifest.get("formats", ["ogg", "wav"])
	var dirs: Array[String] = [
		String(manifest.get("override_dir", "user://music_overrides/")),
		String(manifest.get("project_override_dir", "res://assets/music/user_overrides/")),
		String(manifest.get("default_dir", "res://assets/music/default/")),
	]
	for dir in dirs:
		for ext: String in formats:
			var path := dir + file_base + "." + ext
			var stream := _load_stream(path)
			if stream != null:
				return stream
	return null


func _load_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			var res: Variant = load(path)
			if res is AudioStream:
				return res
		return null
	if not FileAccess.file_exists(path):
		return null
	if path.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	if path.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	return null
