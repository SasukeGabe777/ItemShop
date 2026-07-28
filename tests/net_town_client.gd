extends Node
## Client half of tests/net_town_probe. Follows the host into town, parks its
## body at a known spot (streamed to the host), verifies the host's puppet
## exists locally, joins the enter-shop gate, and lands in the shop.


class Worker:
	extends Node

	const OUT_PATH := "user://net_town_client.json"

	var report: Dictionary = {
		"joined": false, "town_seen": false, "host_puppet_seen": false,
		"local_character_and_sidekick": false, "gate_first_count": 0,
		"final_scene": "", "error": "",
	}


	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "TownBro")
		var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
		if not joined:
			_finish("no welcome within 10s")
			return
		report["joined"] = true

		var in_town := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("town.tscn"), 15.0)
		report["town_seen"] = in_town
		if not in_town:
			_finish("never followed into town")
			return

		var town := get_tree().current_scene
		var local_player := town.get("player") as TownPlayer
		var local_sidekick: PatchFollower = \
			(town.get("_net_sidekicks") as Dictionary).get(2)
		report["local_character_and_sidekick"] = \
			local_player.manifest_override == PartyState.avatar_of(2) \
			and local_sidekick != null and local_sidekick.target == local_player \
			and local_sidekick.manifest_path \
				== "res://assets/shared/effects/p2_sidekick.json"
		var pupped := await _wait_for(func() -> bool:
			return (town.get("_net_puppets") as Dictionary).has(1), 10.0)
		report["host_puppet_seen"] = pupped

		# Park our body at a known spot for the host to verify via the stream.
		town.get("player").global_position = Vector2(123, 231)
		await get_tree().create_timer(2.0).timeout

		Net.request("party.gate", {"action_id": "enter_shop"},
			func(_ok: bool, data: Dictionary) -> void:
				report["gate_first_count"] = int(data.get("count", 0)))

		var in_shop := await _wait_for(func() -> bool:
			var scene := get_tree().current_scene
			return scene != null and scene.scene_file_path.ends_with("shop.tscn"), 20.0)
		var scene := get_tree().current_scene
		report["final_scene"] = scene.scene_file_path if scene != null else ""
		_finish("" if in_shop else "never entered the shop")


	func _wait_for(cond: Callable, timeout: float) -> bool:
		var waited := 0.0
		while waited < timeout:
			if bool(cond.call()):
				return true
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		return bool(cond.call())


	func _finish(err: String) -> void:
		report["error"] = err
		var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report))
			f = null
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
