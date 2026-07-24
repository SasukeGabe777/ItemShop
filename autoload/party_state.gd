extends Node
## PartyState: the seat roster shared by every player-count mode. player_index
## (1..5) is the stable identity everywhere in gameplay code; peer ids are
## transport details owned by Net and may change when a player reconnects.
## Couch split-screen fills seats 1-2 locally (MultiplayerState keeps doing
## that mode's heavy lifting); online play fills seats with remote peers.

enum Mode { SINGLE, COUCH, ONLINE }

const MAX_PLAYERS := 5
## P1/P2 keep their historical label colors; P3-P5 extend the family.
const PLAYER_COLORS: Array[Color] = [
	Color("ff9999"), Color("8fd8ff"), Color("a8f0a0"),
	Color("ffd98f"), Color("e0a8ff"),
]
## Subtle body modulates so identical sprites read apart (P2's couch tint is
## the historical model).
const PLAYER_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.88, 0.82), Color(0.86, 1.0, 0.86),
	Color(1.0, 0.96, 0.8), Color(0.94, 0.86, 1.0),
]

signal changed
signal player_left(player_index: int)

var mode: int = Mode.SINGLE
## player_index -> {player_index, peer_id, name, color, hero, is_local,
## connected, ready, session_token}
var players: Dictionary = {}
var _ready_sets: Dictionary = {}  # ONLINE: action id -> {player_idx: true}


func _ready() -> void:
	_rebuild_single()


func make_seat(player_index: int, peer_id: int, player_name: String,
		is_local: bool) -> Dictionary:
	return {
		"player_index": player_index,
		"peer_id": peer_id,
		"name": player_name,
		"color": color(player_index).to_html(false),
		"hero": "",
		"is_local": is_local,
		"connected": true,
		"ready": false,
		"session_token": "",
	}


## ---- mode switching --------------------------------------------------------

func _rebuild_single() -> void:
	mode = Mode.SINGLE
	players = {1: make_seat(1, 1, "P1", true)}
	_ready_sets.clear()
	changed.emit()


## Mirror couch split-screen on/off (called by MultiplayerState.set_enabled).
func set_couch(on: bool) -> void:
	if mode == Mode.ONLINE:
		return
	if on:
		mode = Mode.COUCH
		players = {
			1: make_seat(1, 1, "P1", true),
			2: make_seat(2, 1, "P2", true),
		}
		_ready_sets.clear()
		changed.emit()
	else:
		_rebuild_single()


## Net installs/updates the online roster wholesale (host broadcasts it).
func set_online_roster(list: Array, local_idx: int) -> void:
	mode = Mode.ONLINE
	var previous := players
	players = {}
	for entry: Dictionary in list:
		var seat := entry.duplicate(true)
		var idx := int(seat.get("player_index", 0))
		if idx < 1 or idx > MAX_PLAYERS:
			continue
		seat["is_local"] = idx == local_idx
		players[idx] = seat
	for idx: int in previous:
		if not players.has(idx):
			player_left.emit(idx)
	changed.emit()


## Leaving an online session returns to a lone local seat.
func clear_online() -> void:
	if mode != Mode.ONLINE:
		return
	_rebuild_single()


## ---- accessors -------------------------------------------------------------

func is_online() -> bool:
	return mode == Mode.ONLINE


func player(idx: int) -> Dictionary:
	return players.get(idx, {})


func count() -> int:
	return players.size()


func connected_indexes() -> Array[int]:
	var out: Array[int] = []
	for idx: int in players:
		if bool(players[idx].get("connected", false)):
			out.append(idx)
	out.sort()
	return out


func local_index() -> int:
	for idx: int in players:
		if bool(players[idx].get("is_local", false)):
			return idx
	return 1


func peer_for(idx: int) -> int:
	return int(player(idx).get("peer_id", 0))


func index_for_peer(peer_id: int) -> int:
	for idx: int in players:
		if int(players[idx].get("peer_id", -1)) == peer_id:
			return idx
	return 0


func pname(idx: int) -> String:
	var n := String(player(idx).get("name", ""))
	return n if n != "" else "P%d" % idx


func color(idx: int) -> Color:
	return PLAYER_COLORS[clampi(idx - 1, 0, PLAYER_COLORS.size() - 1)]


func tint(idx: int) -> Color:
	return PLAYER_TINTS[clampi(idx - 1, 0, PLAYER_TINTS.size() - 1)]


## ---- shared-action ready gate ("3/5 ready to open the shop") ---------------
## SINGLE always passes; COUCH delegates to MultiplayerState's existing gate;
## ONLINE tracks per-seat readiness (host-authoritative — clients reach this
## through Net's command bus).

func ready_up(action_id: String, player_idx: int, needed: int = -1) -> bool:
	match mode:
		Mode.COUCH:
			return MultiplayerState.ready_up(action_id, player_idx)
		Mode.ONLINE:
			var set_ref: Dictionary = _ready_sets.get(action_id, {})
			set_ref[player_idx] = true
			_ready_sets[action_id] = set_ref
			var need := needed if needed > 0 else connected_indexes().size()
			return set_ref.size() >= need
		_:
			return true


func ready_count(action_id: String) -> int:
	if mode == Mode.COUCH:
		return MultiplayerState.ready_count(action_id)
	return (_ready_sets.get(action_id, {}) as Dictionary).size()


func clear_ready(action_id: String = "") -> void:
	if mode == Mode.COUCH:
		MultiplayerState.clear_ready(action_id)
		return
	if action_id == "":
		_ready_sets.clear()
	else:
		_ready_sets.erase(action_id)


## Re-evaluate ready sets after a disconnect shrinks the party (a pending
## "everyone ready?" gate may now be satisfied). Returns action ids that are
## now complete.
func recheck_ready() -> Array[String]:
	var done: Array[String] = []
	if mode != Mode.ONLINE:
		return done
	var need := connected_indexes().size()
	for action_id: String in _ready_sets:
		if (_ready_sets[action_id] as Dictionary).size() >= need:
			done.append(action_id)
	return done
