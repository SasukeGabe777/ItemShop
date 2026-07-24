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
		await get_tree().create_timer(20.0).timeout
		get_tree().quit(0)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Worker.new())
