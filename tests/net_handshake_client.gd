extends Node
## Client half of tests/net_handshake_probe — run by the host probe in a
## SECOND headless instance. Joins 127.0.0.1, records what happened, leaves,
## retries with a wrong version expecting rejection, then writes its verdict
## to user://net_probe_client.json for the host probe to read.

const OUT_PATH := "user://net_probe_client.json"

var report: Dictionary = {
	"joined": false,
	"index": 0,
	"roster_size": 0,
	"online_mode": false,
	"reject_reason": "",
	"error": "",
}


func _ready() -> void:
	await get_tree().create_timer(0.4).timeout
	Net.join_succeeded.connect(_on_joined)
	Net.join_failed.connect(_on_failed)
	var err := Net.join_game("127.0.0.1", "ClientBro")
	if err != OK:
		_finish("create_client returned %s" % error_string(err))
		return
	await get_tree().create_timer(8.0).timeout
	if not bool(report["joined"]):
		_finish("no welcome within 8s")
	elif String(report["reject_reason"]) == "":
		_finish("wrong-version join was not rejected within 8s")


func _on_joined(idx: int) -> void:
	report["joined"] = true
	report["index"] = idx
	report["roster_size"] = PartyState.count()
	report["online_mode"] = PartyState.is_online()
	await get_tree().create_timer(0.5).timeout
	Net.leave()
	await get_tree().create_timer(0.5).timeout
	Net.version_override = "999.0.0"
	Net.join_game("127.0.0.1", "WrongVersionBro")


func _on_failed(reason: String) -> void:
	report["reject_reason"] = reason
	_finish("")


func _finish(err: String) -> void:
	report["error"] = err
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report))
		f = null
	get_tree().quit(0)
