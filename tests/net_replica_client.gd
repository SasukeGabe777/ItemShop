extends Node
## Client half of tests/net_replica_probe. Registers a puppet factory, joins,
## streams its own player state, and records everything the replica layer
## delivers: spawn args, tracked position, events, despawn, stale-gen drops.

const OUT_PATH := "user://net_replica_client.json"

var report: Dictionary = {
	"joined": false, "spawn_kind": "", "spawn_tag": "", "final_pos": [0, 0],
	"event_name": "", "event_n": 0, "despawn_reason": "", "entity_gone": false,
	"stale_spawned": false, "error": "",
}
var _spawned_eid := 0


func _ready() -> void:
	await get_tree().create_timer(0.4).timeout
	Replica.register_factory("dummy", func(args: Dictionary) -> Node:
		var node := Node2D.new()
		node.set_meta("spawn_tag", String(args.get("tag", "")))
		add_child(node)
		return node)
	Replica.entity_spawned.connect(func(eid: int, kind: String, node: Node) -> void:
		_spawned_eid = eid
		report["spawn_kind"] = kind
		report["spawn_tag"] = String(node.get_meta("spawn_tag", "")))
	Replica.entity_event.connect(func(_eid: int, event_name: String, args: Dictionary) -> void:
		report["event_name"] = event_name
		report["event_n"] = int(args.get("n", 0)))
	Replica.entity_despawned.connect(func(_eid: int, reason: String, _args: Dictionary) -> void:
		report["despawn_reason"] = reason)

	Net.join_game("127.0.0.1", "ReplicaBro")
	var joined := await _wait_for(func() -> bool: return Net.my_index > 0, 10.0)
	if not joined:
		_finish("no welcome within 10s")
		return
	report["joined"] = true
	Replica.register_local_player(Net.my_index,
		func() -> Array: return [111.0, 222.0, 0.0, 0.0, 0])

	var spawned := await _wait_for(func() -> bool: return _spawned_eid > 0, 10.0)
	if not spawned:
		_finish("entity never spawned")
		return

	# Let the host walk the dummy to its target, then read our tracked copy.
	await get_tree().create_timer(4.0).timeout
	var node := Replica.entity(_spawned_eid) as Node2D
	if node != null:
		report["final_pos"] = [node.global_position.x, node.global_position.y]

	var gone := await _wait_for(func() -> bool:
		return report["despawn_reason"] != "", 10.0)
	if not gone:
		_finish("entity never despawned")
		return
	await get_tree().create_timer(0.3).timeout
	report["entity_gone"] = Replica.entity(_spawned_eid) == null
	report["stale_spawned"] = Replica.entity(999) != null
	_finish("")


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
