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
signal upnp_result(ok: bool, message: String)

## True while a host-pushed sync is being applied locally, so manager signal
## handlers can tell remote-driven refreshes from local mutations.
var applying_sync := false
## True while this machine is executing a host-ordered scene change.
var applying_remote_go := false

## Client: our seat's reconnect token and index, learned from _welcome.
var session_token := ""
var my_index := 0
## Testing hook: overrides the version string sent in _hello.
var version_override := ""

## Last UPnP outcome ("", or the message shown in the lobby info strip).
var upnp_ok := false
var upnp_message := ""

var _active := false  # an ENet peer of ours is installed
var _local_name := ""
var _last_ip := ""
var _commands: Dictionary = {}
var _managers: Dictionary = {}
var _next_request_id := 1
var _pending_results: Dictionary = {}  # request_id -> Callable(ok, data)
var _discovery: Node = null
var _upnp: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_discovery = preload("res://scripts/net/lan_discovery.gd").new()
	add_child(_discovery)
	_upnp = preload("res://scripts/net/upnp_opener.gd").new()
	add_child(_upnp)
	_upnp.finished.connect(_on_upnp_finished)
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


## ---- peer lifecycle --------------------------------------------------------

func host_game(player_name: String = "") -> Error:
	if is_online():
		leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("[Net] create_server failed: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_active = true
	_local_name = player_name if player_name != "" else "P1"
	my_index = 1
	PartyState.set_online_roster([PartyState.make_seat(1, 1, _local_name, false)], 1)
	_discovery.start_responder(_lobby_info)
	upnp_ok = false
	upnp_message = "Checking whether the router can auto-open a port..."
	_upnp.open()
	roster_changed.emit()
	hosting_started.emit()
	return OK


func join_game(ip: String, player_name: String = "") -> Error:
	if is_online():
		leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("[Net] create_client failed: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_active = true
	_local_name = player_name if player_name != "" else "Player"
	_last_ip = ip
	my_index = 0
	return OK


func leave() -> void:
	_discovery.stop()
	_upnp.close_mapping()
	if _active and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_active = false
	session_token = ""
	my_index = 0
	_pending_results.clear()
	PartyState.clear_online()
	roster_changed.emit()


## What LAN discovery replies with when someone is searching for lobbies.
func _lobby_info() -> Dictionary:
	return {
		"name": _local_name,
		"version": _game_version(),
		"players": PartyState.count(),
		"max": PartyState.MAX_PLAYERS,
		"port": PORT,
	}


func _on_upnp_finished(ok: bool, _external_ip: String, message: String) -> void:
	upnp_ok = ok
	upnp_message = message
	upnp_result.emit(ok, message)


## The lobby scene borrows Net's discovery node to search for LAN games.
func discovery() -> Node:
	return _discovery


func _game_version() -> String:
	if version_override != "":
		return version_override
	return String(ProjectSettings.get_setting("application/config/version", "0"))


## The Wi-Fi-extender allowance: ride out several seconds of silence on ENet
## retransmission instead of dropping the peer (limit factor, min ms, max ms).
func _relax_peer_timeout(peer_id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	var packet_peer := enet.get_peer(peer_id)
	if packet_peer != null:
		packet_peer.set_timeout(32, 15000, 45000)


func _on_peer_connected(peer_id: int) -> void:
	if is_host():
		_relax_peer_timeout(peer_id)  # seat assignment waits for _hello


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	var idx := PartyState.index_for_peer(peer_id)
	if idx <= 1:
		return
	PartyState.players[idx]["connected"] = false
	_broadcast_roster()
	PartyState.player_left.emit(idx)


func _on_connected_to_server() -> void:
	_relax_peer_timeout(1)
	_hello.rpc_id(1, {
		"version": _game_version(),
		"name": _local_name,
		"session_token": session_token,
	})


func _on_connection_failed() -> void:
	leave()
	join_failed.emit("Could not reach the host")


func _on_server_disconnected() -> void:
	if my_index == 0:
		# never seated: treat as a failed join (e.g. kicked after _reject)
		leave()
		return
	connection_lost.emit()
	leave()


## ---- handshake -------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _hello(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var version := String(info.get("version", ""))
	if version != _game_version():
		_reject_and_kick(peer_id,
			"Version mismatch — host runs %s, you run %s" % [_game_version(), version])
		return
	var idx := _lowest_free_index()
	if idx == 0:
		_reject_and_kick(peer_id, "The game is full (5 players)")
		return
	var seat := PartyState.make_seat(idx, peer_id,
		String(info.get("name", "P%d" % idx)), false)
	seat["session_token"] = _make_token()
	PartyState.players[idx] = seat
	_welcome.rpc_id(peer_id, snapshot_all(), _roster_payload(),
		current_scene_key(), SceneRouter.context, idx, String(seat["session_token"]))
	_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func _welcome(snapshot: Dictionary, roster: Array, scene_key: String,
		ctx: Dictionary, your_index: int, token: String) -> void:
	my_index = your_index
	session_token = token
	_apply_snapshot(snapshot)
	PartyState.set_online_roster(roster, my_index)
	roster_changed.emit()
	join_succeeded.emit(my_index)
	if scene_key != "" and scene_key != current_scene_key():
		applying_remote_go = true
		SceneRouter.go(scene_key, ctx)
		applying_remote_go = false


@rpc("authority", "call_remote", "reliable")
func _reject(reason: String) -> void:
	join_failed.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _roster(list: Array) -> void:
	if my_index == 0:
		return  # not seated yet; _welcome carries our first roster
	PartyState.set_online_roster(list, my_index)
	roster_changed.emit()


func _reject_and_kick(peer_id: int, reason: String) -> void:
	_reject.rpc_id(peer_id, reason)
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	await get_tree().create_timer(0.5).timeout
	if is_host() and enet == multiplayer.multiplayer_peer:
		enet.disconnect_peer(peer_id)


func _lowest_free_index() -> int:
	for idx in range(2, PartyState.MAX_PLAYERS + 1):
		if not PartyState.players.has(idx):
			return idx
	return 0


func _make_token() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()


## Roster as shipped to clients: session tokens are secrets between the host
## and each seat's owner, so they never ride the shared broadcast.
func _roster_payload() -> Array:
	var out: Array = []
	for idx: int in PartyState.players:
		var seat: Dictionary = PartyState.players[idx].duplicate(true)
		seat.erase("session_token")
		out.append(seat)
	return out


func _broadcast_roster() -> void:
	if not is_host():
		return
	PartyState.changed.emit()
	roster_changed.emit()
	_roster.rpc(_roster_payload())


func current_scene_key() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	for key: String in SceneRouter.SCENES:
		if String(SceneRouter.SCENES[key]) == scene.scene_file_path:
			return key
	return ""


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
