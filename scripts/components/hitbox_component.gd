class_name HitboxComponent
extends Area2D
## An attack volume that deals a damage packet to overlapping HurtboxComponents.
## Enable briefly during attacks; remembers who it already hit this swing.

var packet: Dictionary = {}
var _hit_this_swing: Array = []


func _init() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


func begin_swing(damage_packet: Dictionary) -> void:
	packet = damage_packet
	_hit_this_swing.clear()
	set_deferred("monitoring", true)


func end_swing() -> void:
	set_deferred("monitoring", false)


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent and not (area in _hit_this_swing):
		_hit_this_swing.append(area)
		(area as HurtboxComponent).receive(packet, global_position)
