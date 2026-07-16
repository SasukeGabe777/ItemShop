class_name DamageComponent
extends Node
## Produces damage packets for an entity, applying its stats and status buffs.

@export var base_damage: int = 10
var status: StatusEffectComponent


func packet(multiplier: float = 1.0, knockback: float = 120.0) -> Dictionary:
	var dmg := float(base_damage)
	if status != null:
		dmg += status.attack_bonus()
	return {"damage": maxi(1, int(round(dmg * multiplier))), "knockback": knockback, "source": get_parent()}
