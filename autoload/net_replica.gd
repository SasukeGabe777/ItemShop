extends Node
## Replica: entity replication for online play. The host simulates shared
## entities (enemies, bosses, customers, projectiles, loot) and streams
## spawn/despawn/events (reliable, channel 0 — ordered WITH scene changes)
## plus batched position states (unreliable_ordered, channel 1). Each
## player's own body streams on channel 2, relayed through the host (star
## topology — clients only see the server).
##
## Every message carries `gen`, a scene-generation stamp aligned across
## peers by Net's welcome/scene-change RPCs, so stragglers from a dying
## scene are dropped instead of resurrecting freed nodes.
##
## Offline and couch play never touch any of this: host_register and friends
## are cheap no-ops when Net.is_online() is false.

const STATE_INTERVAL := 1.0 / 15.0   # host entity stream
const PLAYER_INTERVAL := 1.0 / 20.0  # per-player body stream

signal entity_spawned(eid: int, kind: String, node: Node)
signal entity_event(eid: int, event_name: String, args: Dictionary)
signal entity_despawned(eid: int, reason: String, args: Dictionary)
signal remote_player_event(idx: int, event_name: String, args: Dictionary)

var gen: int = 0

var _factories: Dictionary = {}       # kind -> Callable(args) -> Node
var _entities: Dictionary = {}        # eid -> Node
var _entity_meta: Dictionary = {}     # host: eid -> {kind, args} for late-join replay
## Spawns that arrived before their factory: scene changes are deferred, so
## a welcome's replayed spawns can beat the new scene's _ready registration.
var _pending_spawns: Array = []
var _next_eid := 1
var _state_accum := 0.0
var _player_accum := 0.0
var _local_provider: Callable = Callable()  # -> Array state for the local body
var _local_index := 0
var _local_body: Node = null
var _player_puppets: Dictionary = {}  # player_index -> Node (with smoother)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called on every machine for every scene change (see SceneRouter.go); Net
## re-aligns the counter across peers afterwards.
func bump_gen() -> void:
	gen += 1
	_entities.clear()
	_entity_meta.clear()
	_pending_spawns.clear()
	_factories.clear()
	_player_puppets.clear()
	_local_provider = Callable()
	_local_body = null
	_local_index = 0
	_next_eid = 1


## ---- scene-side registration -----------------------------------------------

## The active scene registers how to build local puppets for each entity kind.
## The factory receives the spawn args, adds the puppet to the scene tree and
## returns it; Replica attaches the smoother and identity metas.
func register_factory(kind: String, factory: Callable) -> void:
	_factories[kind] = factory
	var still: Array = []
	for pending: Array in _pending_spawns:
		if int(pending[0]) == gen and String(pending[2]) == kind:
			_spawn(int(pending[0]), int(pending[1]), String(pending[2]), pending[3])
		elif int(pending[0]) == gen:
			still.append(pending)
	_pending_spawns = still


## The machine that OWNS a player body registers a provider returning its
## state array [x, y, vx, vy, flags] (or [] to skip a tick). `body` (when
## given) receives forwarded damage packets addressed to this player.
func register_local_player(idx: int, provider: Callable, body: Node = null) -> void:
	_local_index = idx
	_local_provider = provider
	_local_body = body


## Any machine showing a remote player's body registers it here; incoming
## states drive its smoother, and forwarded hits route to its owner.
func register_player_puppet(idx: int, body: Node) -> void:
	_ensure_smoother(body)
	body.set_meta("net_puppet", true)
	body.set_meta("net_player_index", idx)
	_player_puppets[idx] = body


## ---- damage forwarding -------------------------------------------------------
## Called by HurtboxComponent when a puppet is hit. Node refs cannot ride the
## wire, so the packet flattens to plain data; the applying side's HP,
## guard and iframes evaluate on authoritative state.

func forward_hit(body: Node, packet: Dictionary, from_position: Vector2) -> void:
	if not Net.is_online():
		return
	var clean := {
		"damage": int(packet.get("damage", 1)),
		"knockback": float(packet.get("knockback", 120.0)),
		"source_player": 0,
	}
	var src: Variant = packet.get("source")
	if src is CombatHero and not (src as CombatHero).is_puppet:
		clean["source_player"] = (src as CombatHero).player_index
		# meter optimism: the attacker felt the hit land, grant it now
		(src as CombatHero).on_enemy_hit()
	var from := [from_position.x, from_position.y]
	var eid := int(body.get_meta("net_eid", 0))
	if eid != 0:
		# puppet of a host entity (enemy/boss/customer) -> apply on the host
		if Net.is_host():
			_hit_entity(gen, eid, clean, from)
		else:
			_hit_entity.rpc_id(1, gen, eid, clean, from)
		return
	var pidx := int(body.get_meta("net_player_index", 0))
	if pidx != 0:
		var peer := PartyState.peer_for(pidx)
		if peer == 1 and Net.is_host():
			return  # host's own body is never a puppet locally
		if peer > 0:
			_hit_player.rpc_id(peer, gen, pidx, clean, from)


@rpc("any_peer", "call_remote", "reliable")
func _hit_entity(g: int, eid: int, packet: Dictionary, from: Array) -> void:
	if g != gen or not multiplayer.is_server():
		return
	var node := entity(eid)
	if node != null and node.has_method("take_packet"):
		node.take_packet(packet, Vector2(float(from[0]), float(from[1])))


@rpc("any_peer", "call_remote", "reliable")
func _hit_player(g: int, idx: int, packet: Dictionary, from: Array) -> void:
	if g != gen or idx != _local_index:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return  # only the host simulates things that can hit us
	if _local_body != null and is_instance_valid(_local_body) \
			and _local_body.has_method("take_packet"):
		_local_body.take_packet(packet, Vector2(float(from[0]), float(from[1])))


func entity(eid: int) -> Node:
	var node: Variant = _entities.get(eid)
	if node == null or not is_instance_valid(node):
		return null
	return node as Node


## ---- host API ---------------------------------------------------------------

func host_register(node: Node, kind: String, args: Dictionary = {}) -> int:
	if not Net.is_host():
		return 0
	var eid := _next_eid
	_next_eid += 1
	_entities[eid] = node
	_entity_meta[eid] = {"kind": kind, "args": args}
	node.set_meta("net_eid", eid)
	_spawn.rpc(gen, eid, kind, args)
	return eid


## A peer welcomed after entities already exist (late join into the shop,
## unparking) replays the living set so its factories catch up. Reliable on
## channel 0 like the welcome itself, so ordering holds.
func host_replay_to(peer_id: int) -> void:
	if not Net.is_host():
		return
	for eid: int in _entities:
		if not is_instance_valid(_entities[eid]):
			continue
		var meta: Dictionary = _entity_meta.get(eid, {})
		_spawn.rpc_id(peer_id, gen, eid, String(meta.get("kind", "")),
			meta.get("args", {}))


func host_despawn(node_or_eid: Variant, reason: String, args: Dictionary = {}) -> void:
	if not Net.is_host():
		return
	var eid: int = node_or_eid if node_or_eid is int \
		else int((node_or_eid as Node).get_meta("net_eid", 0))
	if eid == 0 or not _entities.has(eid):
		return
	_entities.erase(eid)
	_entity_meta.erase(eid)
	_despawn.rpc(gen, eid, reason, args)


func host_event(node_or_eid: Variant, event_name: String, args: Dictionary = {}) -> void:
	if not Net.is_host():
		return
	var eid: int = node_or_eid if node_or_eid is int \
		else int((node_or_eid as Node).get_meta("net_eid", 0))
	if eid == 0:
		return
	_event.rpc(gen, eid, event_name, args)


## ---- owner API for player bodies --------------------------------------------

## Reliable, relayed to every other machine: attack swings, hp, downs, emotes.
func send_player_event(event_name: String, args: Dictionary = {}) -> void:
	if not Net.is_online() or _local_index == 0:
		return
	if Net.is_host():
		_player_event.rpc(gen, _local_index, event_name, args)
	else:
		_player_event.rpc_id(1, gen, _local_index, event_name, args)


## ---- streaming ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not Net.is_online() or not _peer_connected():
		return
	if Net.is_host():
		_state_accum += delta
		if _state_accum >= STATE_INTERVAL:
			_state_accum = 0.0
			_send_entity_states()
	_player_accum += delta
	if _player_accum >= PLAYER_INTERVAL:
		_player_accum = 0.0
		_send_local_player_state()


func _send_entity_states() -> void:
	var batch: Array = []
	for eid: int in _entities.keys():
		var node: Variant = _entities[eid]
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			_entities.erase(eid)
			_entity_meta.erase(eid)
			continue
		var n2 := node as Node2D
		var vel := Vector2.ZERO
		if n2 is CharacterBody2D:
			vel = (n2 as CharacterBody2D).velocity
		batch.append([eid, n2.global_position.x, n2.global_position.y, vel.x, vel.y])
	if not batch.is_empty():
		_state.rpc(gen, batch)


func _send_local_player_state() -> void:
	if _local_index == 0 or not _local_provider.is_valid():
		return
	var data: Variant = _local_provider.call()
	if not (data is Array) or (data as Array).is_empty():
		return
	if Net.is_host():
		_player_state.rpc(gen, _local_index, data)
	else:
		_player_state.rpc_id(1, gen, _local_index, data)


## Streaming during a reconnect gap (peer swapped, not yet connected) would
## error on every tick — hold fire until the transport is live.
func _peer_connected() -> bool:
	var mp := multiplayer.multiplayer_peer
	return mp != null \
		and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## ---- wire handlers -----------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _spawn(g: int, eid: int, kind: String, args: Dictionary) -> void:
	if g != gen:
		return
	var factory: Callable = _factories.get(kind, Callable())
	if not factory.is_valid():
		_pending_spawns.append([g, eid, kind, args])
		return
	var node: Variant = factory.call(args)
	if node == null or not is_instance_valid(node) or not (node is Node):
		return
	var built := node as Node
	_entities[eid] = built
	built.set_meta("net_eid", eid)
	built.set_meta("net_puppet", true)
	_ensure_smoother(built)
	entity_spawned.emit(eid, kind, built)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _state(g: int, batch: Array) -> void:
	if g != gen:
		return
	for entry: Array in batch:
		var node := entity(int(entry[0]))
		if node == null:
			continue
		var sm := node.get_node_or_null("PuppetSmoother") as PuppetSmoother
		if sm != null:
			sm.push_state(Vector2(float(entry[1]), float(entry[2])),
				Vector2(float(entry[3]), float(entry[4])))


@rpc("authority", "call_remote", "reliable")
func _event(g: int, eid: int, event_name: String, args: Dictionary) -> void:
	if g != gen:
		return
	entity_event.emit(eid, event_name, args)


@rpc("authority", "call_remote", "reliable")
func _despawn(g: int, eid: int, reason: String, args: Dictionary) -> void:
	if g != gen:
		return
	var node := entity(int(eid))
	_entities.erase(eid)
	entity_despawned.emit(eid, reason, args)
	if node != null:
		node.queue_free()


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _player_state(g: int, idx: int, data: Array) -> void:
	if g != gen:
		return
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		if sender != PartyState.peer_for(idx):
			return
		_apply_player_state(idx, data)
		for peer: int in multiplayer.get_peers():
			if peer != sender:
				_player_state.rpc_id(peer, g, idx, data)
	else:
		if sender != 1 or idx == _local_index:
			return
		_apply_player_state(idx, data)


@rpc("any_peer", "call_remote", "reliable")
func _player_event(g: int, idx: int, event_name: String, args: Dictionary) -> void:
	if g != gen:
		return
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		if sender != PartyState.peer_for(idx):
			return
		remote_player_event.emit(idx, event_name, args)
		for peer: int in multiplayer.get_peers():
			if peer != sender:
				_player_event.rpc_id(peer, g, idx, event_name, args)
	else:
		if sender != 1 or idx == _local_index:
			return
		remote_player_event.emit(idx, event_name, args)


## ---- internals ----------------------------------------------------------------

func _apply_player_state(idx: int, data: Array) -> void:
	if data.size() < 4:
		return
	var body: Variant = _player_puppets.get(idx)
	if body == null or not is_instance_valid(body):
		return
	var sm := (body as Node).get_node_or_null("PuppetSmoother") as PuppetSmoother
	if sm != null:
		sm.push_state(Vector2(float(data[0]), float(data[1])),
			Vector2(float(data[2]), float(data[3])))


func _ensure_smoother(node: Node) -> void:
	if node.get_node_or_null("PuppetSmoother") == null:
		var sm := PuppetSmoother.new()
		sm.name = "PuppetSmoother"
		node.add_child(sm)
