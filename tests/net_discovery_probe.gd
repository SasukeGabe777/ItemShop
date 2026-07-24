extends Node
## M4: LAN discovery logic, single process. Hosting starts the responder on
## UDP 8911; a second lan_discovery instance searches and must hear back via
## the 127.0.0.1 unicast path (broadcast-to-self is unreliable on Windows —
## the real broadcast path gets checked by hand on the actual LAN).

var failures: Array[String] = []
var _found_info: Dictionary = {}
var _found_ip := ""


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_expect(Net.host_game("DiscoGabe") == OK, "host_game failed")

	var searcher: Node = preload("res://scripts/net/lan_discovery.gd").new()
	add_child(searcher)
	searcher.lobby_found.connect(func(info: Dictionary, ip: String) -> void:
		_found_info = info
		_found_ip = ip)
	searcher.start_search()

	var heard := await _wait_for(func() -> bool: return not _found_info.is_empty(), 6.0)
	_expect(heard, "searcher never heard the responder")
	if heard:
		_expect(String(_found_info.get("name", "")) == "DiscoGabe",
			"lobby name wrong: %s" % _found_info.get("name"))
		_expect(int(_found_info.get("players", 0)) == 1,
			"player count wrong: %s" % _found_info.get("players"))
		_expect(int(_found_info.get("port", 0)) == Net.PORT,
			"advertised port wrong: %s" % _found_info.get("port"))
		_expect(_found_ip == "127.0.0.1",
			"reply ip unexpected: %s" % _found_ip)

	searcher.stop()
	Net.leave()
	if failures.is_empty():
		print("NET_DISCOVERY_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("NET_DISCOVERY_PROBE_FAIL: ", failure)
		get_tree().quit(1)


func _wait_for(cond: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if bool(cond.call()):
			return true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return bool(cond.call())


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
