extends Node
## Net: transport + authority layer for online co-op (up to 5 players).
## The host (peer 1 = player 1) runs the one true simulation; clients send
## named requests and mirror the host's manager snapshots. All @rpc methods
## live on this autoload (and Replica) so a scene change can never free an
## RPC target mid-flight.
##
## Channel map: 0 (default, reliable) carries commands, state syncs and scene
## changes — reliable ordering is per-channel, so a sync and the scene change
## that follows it MUST share a channel. Channels 1-2 are reserved for
## Replica's unreliable entity/player streams.
##
## Offline and couch play never install a peer, so is_online() is false and
## every request() runs locally — gameplay code can call Net unconditionally.

const PORT := 8910
const DISCOVERY_PORT := 8911
const MAX_CLIENTS := 4

signal hosting_started
signal join_succeeded(your_index: int)
signal join_failed(reason: String)
signal connection_lost
signal reconnected
signal parked(reason: String)
signal roster_changed
signal state_applied(manager: String)

## True while a host-pushed sync is being applied locally, so manager signal
## handlers can tell remote-driven refreshes from local mutations.
var applying_sync := false
## True while this machine is executing a host-ordered scene change.
var applying_remote_go := false

var _active := false  # an ENet peer of ours is installed
var _commands: Dictionary = {}
var _managers: Dictionary = {}
var _next_request_id := 1
var _pending_results: Dictionary = {}  # request_id -> Callable(ok, data)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_commands = preload("res://scripts/net/net_commands.gd").build()
	# Net manager names double as sync payload keys. A manager syncs via
	# to_net()/from_net() when it has them (runtime-only state like the
	# expedition plan), else its save-file to_save()/from_save() pair.
	_managers = {
		"game_state": GameState,
		"time": TimeManager,
		"economy": EconomyManager,
		"market": MarketManager,
		"inventory": InventoryManager,
		"relationships": RelationshipManager,
		"bridge": BridgeManager,
		"boom": BoomManager,
		"story": StoryEventManager,
		"furniture": ShopFurnitureManager,
		"dungeon": DungeonManager,
	}


## ---- role predicates -------------------------------------------------------

func is_online() -> bool:
	return _active and multiplayer.multiplayer_peer != null


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


## The one guard gameplay code uses: may THIS machine mutate shared state?
func is_authority() -> bool:
	return not is_online() or multiplayer.is_server()


## Tripwire for mutators that must never run directly on an online client.
func assert_authority(context: String) -> void:
	if not is_authority():
		push_error("[Net] client-side mutation blocked at %s — use Net.request" % context)


## ---- command bus -----------------------------------------------------------
## Gameplay calls request() everywhere; offline/host it runs the registered
## mutator immediately, online clients ship it to the host. on_result (if
## given) is called with (ok: bool, data: Dictionary) either way.

func request(cmd: String, args: Dictionary = {}, on_result: Callable = Callable()) -> void:
	if not _commands.has(cmd):
		push_error("[Net] unknown command %s" % cmd)
		return
	if is_authority():
		var result := _run_command(PartyState.local_index(), cmd, args)
		if on_result.is_valid():
			on_result.call(bool(result.get("ok", true)), result)
	else:
		var rid := _next_request_id
		_next_request_id += 1
		if on_result.is_valid():
			_pending_results[rid] = on_result
		_cmd.rpc_id(1, cmd, args, rid)


func _run_command(sender_index: int, cmd: String, args: Dictionary) -> Dictionary:
	var entry: Dictionary = _commands[cmd]
	var raw: Variant = (entry["run"] as Callable).call(sender_index, args)
	var result: Dictionary = raw if raw is Dictionary else {}
	sync_managers(entry.get("syncs", []))
	return result


@rpc("any_peer", "call_remote", "reliable")
func _cmd(cmd: String, args: Dictionary, request_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_peer := multiplayer.get_remote_sender_id()
	var sender_index := PartyState.index_for_peer(sender_peer)
	if sender_index <= 0:
		push_warning("[Net] command %s from unseated peer %d dropped" % [cmd, sender_peer])
		return
	if not _commands.has(cmd):
		push_error("[Net] peer %d requested unknown command %s" % [sender_peer, cmd])
		return
	var result := _run_command(sender_index, cmd, args)
	if request_id > 0:
		_cmd_result.rpc_id(sender_peer, request_id, bool(result.get("ok", true)), result)


@rpc("authority", "call_remote", "reliable")
func _cmd_result(request_id: int, ok: bool, data: Dictionary) -> void:
	var cb: Variant = _pending_results.get(request_id)
	_pending_results.erase(request_id)
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(ok, data)


## ---- state sync ------------------------------------------------------------

func sync_managers(names: Array) -> void:
	if not is_host():
		return
	for entry in names:
		var manager_name := String(entry)
		_apply_state.rpc(manager_name, _manager_data(manager_name))


func sync_all() -> void:
	if not is_host():
		return
	_apply_snapshot.rpc(snapshot_all())


func snapshot_all() -> Dictionary:
	var out: Dictionary = {}
	for manager_name: String in _managers:
		out[manager_name] = _manager_data(manager_name)
	return out


func _manager_data(manager_name: String) -> Dictionary:
	var mgr: Node = _managers.get(manager_name)
	if mgr == null:
		push_error("[Net] unknown manager %s" % manager_name)
		return {}
	if mgr.has_method("to_net"):
		return mgr.to_net()
	if mgr.has_method("to_save"):
		return mgr.to_save()
	return {}


func _apply_manager_data(manager_name: String, data: Dictionary) -> void:
	var mgr: Node = _managers.get(manager_name)
	if mgr == null:
		return
	if mgr.has_method("from_net"):
		mgr.from_net(data)
	elif mgr.has_method("from_save"):
		mgr.from_save(data)


@rpc("authority", "call_remote", "reliable")
func _apply_state(manager_name: String, data: Dictionary) -> void:
	applying_sync = true
	_apply_manager_data(manager_name, data)
	applying_sync = false
	state_applied.emit(manager_name)


@rpc("authority", "call_remote", "reliable")
func _apply_snapshot(snapshot: Dictionary) -> void:
	applying_sync = true
	for manager_name: String in snapshot:
		_apply_manager_data(manager_name, snapshot[manager_name])
	applying_sync = false
	state_applied.emit("*")


## ---- scene coordination ----------------------------------------------------
## The party always moves together: the host's SceneRouter.go calls this, and
## every client follows behind a fresh full sync (same reliable channel, so
## the sync always lands first).

func broadcast_scene_change(scene_key: String, ctx: Dictionary) -> void:
	if not is_host():
		return
	sync_all()
	_net_go.rpc(scene_key, ctx)


@rpc("authority", "call_remote", "reliable")
func _net_go(scene_key: String, ctx: Dictionary) -> void:
	applying_remote_go = true
	SceneRouter.go(scene_key, ctx)
	applying_remote_go = false
