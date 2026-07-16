class_name HealthComponent
extends Node
## Tracks hit points, invulnerability windows and death for any combat entity.

signal damaged(amount: int, source: Node)
signal healed(amount: int)
signal died()

@export var max_hp: int = 100
var hp: int = 100
var invulnerable_until_ms: int = 0
var dead: bool = false


func setup(maximum: int) -> void:
	max_hp = maximum
	hp = maximum
	dead = false


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < invulnerable_until_ms


func grant_iframes(seconds: float) -> void:
	invulnerable_until_ms = maxi(invulnerable_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))


func take_damage(amount: int, source: Node = null) -> bool:
	if dead or is_invulnerable() or amount <= 0:
		return false
	hp -= amount
	damaged.emit(amount, source)
	if hp <= 0:
		hp = 0
		dead = true
		died.emit()
	return true


func heal(amount: int) -> void:
	if dead:
		return
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp > before:
		healed.emit(hp - before)


func revive(ratio: float = 0.5) -> void:
	dead = false
	hp = maxi(1, int(max_hp * ratio))
