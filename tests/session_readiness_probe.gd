extends Node
## Regression checks for fresh-clone audio, inventory reset, and campaign buying.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	InventoryManager.reset()
	_check_inventory_reset()
	_check_sim_purchases()
	_check_music()
	if failures.is_empty():
		print("SESSION_READINESS_PROBE_PASS")
	else:
		for message: String in failures:
			printerr("SESSION_READINESS_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_inventory_reset() -> void:
	InventoryManager.add_item("kingdom_key")
	InventoryManager.place_display(0, "kingdom_key")
	InventoryManager.reset()
	_check(InventoryManager.displayed_ids().is_empty(),
		"new campaign retained merchandise on old display stands")
	_check(InventoryManager.count("kingdom_key") == 0,
		"reset returned old displayed merchandise into new storage")


func _check_sim_purchases() -> void:
	InventoryManager.storage.clear()
	EconomyManager.gold = 100000
	ShopSim.auto_buy_stock(0.8)
	for id: String in InventoryManager.storage:
		_check(MarketManager.is_item_accessible(id),
			"autoplay bought sealed merchandise: " + id)
	var before := EconomyManager.gold
	ShopSim.auto_buy_stock(0.8)
	_check(EconomyManager.gold == before,
		"autoplay bought more inventory without consuming its existing stock")


func _check_music() -> void:
	for track: String in ContentDatabase.music.get("tracks", {}):
		_check(AudioManager._resolve_stream(track) != null,
			"no shipped or override audio for " + track)
	var original := ContentDatabase.music.duplicate(true)
	var dir := "user://session_audio_probe/"
	DirAccess.make_dir_recursive_absolute(dir)
	ContentDatabase.music["override_dir"] = dir
	# A canonical track-id override beats the manifest's bundled alias/fallback.
	var custom := AudioStreamWAV.new()
	custom.format = AudioStreamWAV.FORMAT_8_BITS
	custom.mix_rate = 8000
	custom.stereo = true
	custom.data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	_check(custom.save_to_wav(dir + "crossroads_day.wav") == OK,
		"could not create isolated music fixture")
	var resolved := AudioManager._resolve_stream("crossroads_day")
	_check(resolved is AudioStreamWAV and resolved.mix_rate == 8000,
		"track-id override did not take precedence over bundled fallback")
	AudioManager._set_loop(custom, true)
	_check(custom.loop_end == 4,
		"8-bit stereo loop length used bytes instead of audio frames")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "crossroads_day.wav"))
	ContentDatabase.music = original


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
