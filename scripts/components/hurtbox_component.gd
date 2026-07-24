class_name HurtboxComponent
extends Area2D
## Receives damage packets and forwards them to the owner's HealthComponent.

signal hit_received(packet: Dictionary, from_position: Vector2)

@export var health_path: NodePath
var guard_reduction: float = 0.0  # 0..1, set while guarding


func _init() -> void:
	monitorable = true
	monitoring = false


func receive(packet: Dictionary, from_position: Vector2) -> void:
	# Online: hits are DETECTED wherever the attacker simulates, but damage is
	# APPLIED where the defender's HP is authoritative. A puppet's hurtbox
	# forwards the packet to the machine that owns the real body.
	var body := get_parent()
	if body != null and body.get_meta("net_puppet", false):
		Replica.forward_hit(body, packet, from_position)
		return
	var health := get_node_or_null(health_path) as HealthComponent
	if health == null:
		health = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if health == null or health.dead or health.is_invulnerable():
		return
	var dmg := int(packet.get("damage", 1))
	if guard_reduction > 0.0:
		dmg = maxi(1, int(round(dmg * (1.0 - guard_reduction))))
	if health.take_damage(dmg, packet.get("source")):
		hit_received.emit(packet, from_position)
