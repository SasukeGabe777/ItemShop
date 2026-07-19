extends Node2D
## Test stand-in for an enemy: records damage packets it receives.


func take_packet(packet: Dictionary, _from: Vector2) -> void:
	set_meta("dmg", int(get_meta("dmg", 0)) + int(packet.get("damage", 0)))
