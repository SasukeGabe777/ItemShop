extends Node
## Client half of tests/net_lobby_shot: joins the windowed host, readies up,
## then lingers so the host can screenshot a populated lobby. Two-stage: the
## welcome scene-follows this client into online_lobby, freeing the probe
## scene — the worker must ride the tree root to survive it.


class Worker:
	extends Node

	func _ready() -> void:
		await get_tree().create_timer(0.4).timeout
		Net.join_game("127.0.0.1", "BroTwo")
		var waited := 0.0
		while Net.my_index == 0 and waited < 10.0:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		if Net.my_index > 0:
			Net.request("lobby.set_ready", {"ready": true})
		# The same client drives the lobby, town, and dungeon screenshot probes.
		# Hold its locally authoritative body in-frame so the host captures a
		# useful party shot instead of a name label clipped at the spawn edge.
		var lingered := 0.0
		while lingered < 20.0:
			var scene := get_tree().current_scene
			if scene != null and scene.scene_file_path.ends_with("town.tscn"):
				var town_player: Variant = scene.get("player")
				if town_player is Node2D:
					(town_player as Node2D).global_position = Vector2(360, 300)
			elif scene != null and scene.scene_file_path.ends_with("dungeon.tscn"):
				var dungeon_hero: Variant = scene.get("hero")
				if dungeon_hero is Node2D:
					(dungeon_hero as Node2D).global_position = Vector2(360, 190)
			await get_tree().create_timer(0.1).timeout
			lingered += 0.1
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
