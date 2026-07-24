extends Node
## Client half of tests/net_avatar_probe. Joins, changes its avatar to a known
## pick, readies, follows into town, and reports the manifest its OWN town body
## ended up using.


class Worker:
	extends Node

	const OUT_PATH := "user://net_avatar_client.json"

	var report := {"joined": false, "in_town": false, "my_sheet": "", "error": ""}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "AvatarBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true
		# pick "mari" explicitly
		Net.request("lobby.set_avatar", {"avatar": "mari"})
		await _wait_for(func() -> bool:
			return String(PartyState.player(Net.my_index).get("avatar", "")) == "mari", 5.0)

		var in_town := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("town.tscn"), 20.0)
		report["in_town"] = in_town
		if in_town:
			await get_tree().create_timer(0.6).timeout
			var town := get_tree().current_scene
			var body: TownPlayer = town.get("player")
			report["my_sheet"] = _sheet_of(body)
			_write()  # publish the verdict early...
			await get_tree().create_timer(6.0).timeout  # ...then linger so the host sees our puppet
		_finish("" if in_town else "never reached town")


	func _sheet_of(body: TownPlayer) -> String:
		if body == null or body.visual == null or body.visual.animated == null:
			return ""
		var frames := body.visual.animated.sprite_frames
		var anim := frames.get_animation_names()[0]
		var tex := frames.get_frame_texture(anim, 0)
		if tex is AtlasTexture:
			return (tex as AtlasTexture).atlas.resource_path
		return tex.resource_path if tex != null else ""


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _write() -> void:
		var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report))
			f = null


	func _finish(err: String) -> void:
		report["error"] = err
		_write()
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
