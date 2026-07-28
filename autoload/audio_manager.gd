extends Node
## AudioManager: music playback with user-override resolution. A file named
## after a track id in user://music_overrides/ (or the project override folder)
## replaces the default track. OGG, WAV and MP3 supported. Also plays one-shot
## SFX and character voice blips from the manifest's sound_effects dir.

signal mixer_changed

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var music_player: AudioStreamPlayer
var stinger_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var current_track: String = ""
var music_volume_db: float = -8.0
var master_level: float = 1.0
var music_level: float = 0.8
var sfx_level: float = 0.8
var muted: bool = false
var _last_voice: Dictionary = {}  # speaker -> last file index, avoids repeats


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load_mixer()
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	stinger_player = AudioStreamPlayer.new()
	stinger_player.bus = MUSIC_BUS
	add_child(stinger_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = SFX_BUS
	add_child(sfx_player)
	_apply_mixer()
	DirAccess.make_dir_recursive_absolute("user://music_overrides/")
	_connect_global_sfx.call_deferred()


## Cross-cutting jingles wired to gameplay signals (other autoloads exist by
## the time this deferred call runs).
func _connect_global_sfx() -> void:
	BridgeManager.gate_repaired.connect(func(_w: String) -> void: play_sfx("new_world_unlock", 2.0))
	GameState.merchant_level_up.connect(func(_lv: int) -> void: play_sfx("achievement_unlocked"))


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
	# optional per-track start offset ("start" seconds in the manifest):
	# playback AND every loop restart skip the intro (user request for
	# dungeon_pokemon — first 30s unused)
	var start := float(manifest_tracks.get(track_id, {}).get("start", 0.0))
	if start > 0.0 and (stream is AudioStreamMP3 or stream is AudioStreamOggVorbis):
		stream.set("loop_offset", start)
	music_player.stream = stream
	music_player.volume_db = music_volume_db
	if not muted:
		music_player.play(start)


func play_stinger(track_id: String) -> void:
	var stream := _resolve_stream(track_id)
	if stream == null or muted:
		return
	_set_loop(stream, false)
	stinger_player.stream = stream
	stinger_player.volume_db = music_volume_db
	stinger_player.play()


## One-shot effect from the manifest's sfx dir (file name without extension).
func play_sfx(sfx_name: String, volume_offset_db: float = 0.0) -> void:
	if muted:
		return
	var dir := String(ContentDatabase.music.get("sfx_dir", "res://assets/music/sound_effects/"))
	var stream := _load_stream(dir + sfx_name + ".wav")
	if stream == null:
		return
	_set_loop(stream, false)
	sfx_player.stream = stream
	sfx_player.volume_db = music_volume_db + volume_offset_db
	sfx_player.play()


## Character voice blip: picks one of the speaker's files from the manifest
## "voices" map, never repeating the previous pick when there is a choice.
func play_voice(speaker: String) -> void:
	var voices: Dictionary = ContentDatabase.music.get("voices", {})
	var files: Array = voices.get(speaker, [])
	if files.is_empty():
		return
	var idx := 0
	if files.size() > 1:
		idx = randi() % files.size()
		if idx == int(_last_voice.get(speaker, -1)):
			idx = (idx + 1) % files.size()
	_last_voice[speaker] = idx
	play_sfx(String(files[idx]), 4.0)


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
	mixer_changed.emit()


func set_master_level(value: float) -> void:
	master_level = clampf(value, 0.0, 1.0)
	_apply_mixer()
	_save_mixer()


func set_music_level(value: float) -> void:
	music_level = clampf(value, 0.0, 1.0)
	_apply_mixer()
	_save_mixer()


func set_sfx_level(value: float) -> void:
	sfx_level = clampf(value, 0.0, 1.0)
	_apply_mixer()
	_save_mixer()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _apply_mixer() -> void:
	_set_bus_level("Master", master_level)
	_set_bus_level(MUSIC_BUS, music_level)
	_set_bus_level(SFX_BUS, sfx_level)
	mixer_changed.emit()


func _set_bus_level(bus_name: String, level: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var clamped := clampf(level, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, clamped <= 0.001)
	AudioServer.set_bus_volume_db(
		idx, linear_to_db(maxf(clamped, 0.001)))


func _load_mixer() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_level = clampf(float(
		cfg.get_value("audio", "master", master_level)), 0.0, 1.0)
	music_level = clampf(float(
		cfg.get_value("audio", "music", music_level)), 0.0, 1.0)
	sfx_level = clampf(float(
		cfg.get_value("audio", "sfx", sfx_level)), 0.0, 1.0)


func _save_mixer() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master", master_level)
	cfg.set_value("audio", "music", music_level)
	cfg.set_value("audio", "sfx", sfx_level)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("[AudioManager] couldn't save mixer settings: %s" % error_string(err))


func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			w.loop_begin = 0
			w.loop_end = w.data.size() / 2  # 16-bit mono frames
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop


var _variant_next: Dictionary = {}  # track id -> rotation cursor for _N variants


## Resolution order: user:// overrides, project override folder, defaults.
## A track may ship several numbered takes (dungeon_final_fantasy_1.mp3,
## dungeon_final_fantasy_2.mp3, ...): they play interchangeably, advancing
## the rotation every time the track starts.
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
			var candidates: Array[String] = []
			if _stream_exists(dir + file_base + "." + ext):
				candidates.append(dir + file_base + "." + ext)
			for n in range(1, 6):
				var vp := "%s%s_%d.%s" % [dir, file_base, n, ext]
				if _stream_exists(vp):
					candidates.append(vp)
			if candidates.is_empty():
				continue
			var idx := int(_variant_next.get(track_id, 0)) % candidates.size()
			_variant_next[track_id] = idx + 1
			return _load_stream(candidates[idx])
	return null


func _stream_exists(path: String) -> bool:
	if path.begins_with("res://"):
		return ResourceLoader.exists(path)
	return FileAccess.file_exists(path)


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
	if path.ends_with(".mp3"):
		return AudioStreamMP3.load_from_file(path)
	return null
