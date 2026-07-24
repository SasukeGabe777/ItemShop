extends Node
## Best-effort UPnP port opener so the out-of-town friend can join the host
## directly. Discovery blocks for seconds, so the work runs on a Thread; the
## result comes back on the main thread via finished. When the router says
## no, the lobby shows the VPN/port-forward fallback instead.

signal finished(ok: bool, external_ip: String, message: String)

var _thread: Thread = null
var _mapped := false


func open() -> void:
	if _thread != null:
		return
	_thread = Thread.new()
	_thread.start(_work_open)


## Best-effort unmap on leave. Skipped if the opener is still running — the
## mapping is harmless and a future session reclaims it.
func close_mapping() -> void:
	if _thread != null or not _mapped:
		return
	_mapped = false
	_thread = Thread.new()
	_thread.start(_work_close)


func _work_open() -> void:
	var upnp := UPNP.new()
	var res := upnp.discover(2000, 2, "InternetGatewayDevice")
	if res != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null \
			or not upnp.get_gateway().is_valid_gateway():
		call_deferred("_done", false, "", "No UPnP gateway answered")
		return
	var map_res := upnp.add_port_mapping(Net.PORT, Net.PORT, "Crossroads co-op", "UDP", 0)
	if map_res != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_done", false, "", "Router refused the port mapping")
		return
	_mapped = true
	var ext := upnp.query_external_address()
	call_deferred("_done", true, ext, "UDP %d is open to the internet" % Net.PORT)


func _work_close() -> void:
	var upnp := UPNP.new()
	if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS \
			and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		upnp.delete_port_mapping(Net.PORT, "UDP")
	call_deferred("_done_quiet")


func _done(ok: bool, ext: String, msg: String) -> void:
	_join_thread()
	finished.emit(ok, ext, msg)


func _done_quiet() -> void:
	_join_thread()


func _join_thread() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
