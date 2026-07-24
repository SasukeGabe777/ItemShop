extends Node
## LAN lobby discovery over UDP (port 8911). Searching machines broadcast
## CROSSROADS_FIND|<version> once a second (plus a 127.0.0.1 unicast so
## same-PC test instances find each other — broadcast-to-self is unreliable
## on Windows); a hosting machine answers with a JSON info packet.

const FIND_PREFIX := "CROSSROADS_FIND"

signal lobby_found(info: Dictionary, ip: String)

var _responder: PacketPeerUDP = null
var _searcher: PacketPeerUDP = null
var _info_provider: Callable = Callable()
var _search_timer := 0.0


func start_responder(info_provider: Callable) -> void:
	stop()
	_info_provider = info_provider
	var udp := PacketPeerUDP.new()
	if udp.bind(Net.DISCOVERY_PORT) != OK:
		push_warning("[LanDiscovery] cannot bind UDP %d (another host on this PC?)"
			% Net.DISCOVERY_PORT)
		return
	_responder = udp


func start_search() -> void:
	stop()
	var udp := PacketPeerUDP.new()
	if udp.bind(0) != OK:  # any free port; replies come back to it
		push_warning("[LanDiscovery] cannot bind a search port")
		return
	udp.set_broadcast_enabled(true)
	_searcher = udp
	_search_timer = 0.0


func stop() -> void:
	if _responder != null:
		_responder.close()
		_responder = null
	if _searcher != null:
		_searcher.close()
		_searcher = null


func _process(delta: float) -> void:
	if _responder != null:
		while _responder.get_available_packet_count() > 0:
			var packet := _responder.get_packet().get_string_from_utf8()
			if not packet.begins_with(FIND_PREFIX):
				continue
			var info: Dictionary = _info_provider.call() if _info_provider.is_valid() else {}
			_responder.set_dest_address(_responder.get_packet_ip(), _responder.get_packet_port())
			_responder.put_packet(JSON.stringify(info).to_utf8_buffer())
	if _searcher != null:
		_search_timer -= delta
		if _search_timer <= 0.0:
			_search_timer = 1.0
			var find := ("%s|%s" % [FIND_PREFIX,
				ProjectSettings.get_setting("application/config/version", "0")]).to_utf8_buffer()
			_searcher.set_dest_address("255.255.255.255", Net.DISCOVERY_PORT)
			_searcher.put_packet(find)
			_searcher.set_dest_address("127.0.0.1", Net.DISCOVERY_PORT)
			_searcher.put_packet(find)
		while _searcher.get_available_packet_count() > 0:
			var reply := _searcher.get_packet().get_string_from_utf8()
			var ip := _searcher.get_packet_ip()
			var parsed: Variant = JSON.parse_string(reply)
			if parsed is Dictionary:
				lobby_found.emit(parsed as Dictionary, ip)
