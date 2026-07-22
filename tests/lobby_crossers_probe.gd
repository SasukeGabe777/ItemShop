extends Node
## Logic probe for the ambient lobby travellers' central-plaza route picker.


func _ready() -> void:
	var crossers := LobbyCrossers.new()
	add_child(crossers)
	crossers.set_process(false)
	crossers._rng.seed = 20260721
	var upper := 0
	var lower := 0
	var left := 0
	var right := 0
	for i in range(512):
		var ttl := crossers._rng.randf_range(crossers.TTL_MIN, crossers.TTL_MAX)
		var route := crossers._pick_route(ttl)
		var start: Vector2 = route["position"]
		var finish := start + (route["dir"] as Vector2) * crossers.SPEED * ttl
		if not crossers._route_is_clear(start, finish):
			_fail("unsafe route %s -> %s" % [start, finish])
			return
		upper += int(start.y < 210.0)
		lower += int(start.y >= 270.0)
		left += int(start.x < 278.0)
		right += int(start.x >= 379.0)
	if mini(mini(upper, lower), mini(left, right)) == 0:
		_fail("distribution missed a plaza arm: U=%d D=%d L=%d R=%d" % [upper, lower, left, right])
		return
	print("LOBBY_CROSSERS_PROBE_PASS routes=512 U=%d D=%d L=%d R=%d" % [upper, lower, left, right])
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("LOBBY_CROSSERS_PROBE_FAIL: " + message)
	get_tree().quit(1)
