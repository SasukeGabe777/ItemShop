class_name StatusEffectComponent
extends Node
## Timed buffs/debuffs: attack/defense bonuses, stun, invincibility, regen.

var effects: Dictionary = {}  # name -> {value: float, time_left: float}


func _process(delta: float) -> void:
	var expired: Array[String] = []
	for key: String in effects:
		effects[key]["time_left"] = float(effects[key]["time_left"]) - delta
		if float(effects[key]["time_left"]) <= 0.0:
			expired.append(key)
	for key in expired:
		effects.erase(key)


func apply_effect(effect_name: String, value: float, duration: float) -> void:
	effects[effect_name] = {"value": value, "time_left": duration}


func attack_bonus() -> float:
	return float(effects.get("buff_atk", {}).get("value", 0.0))


func defense_bonus() -> float:
	return float(effects.get("buff_def", {}).get("value", 0.0))


func is_stunned() -> bool:
	return effects.has("stun")


func is_invincible() -> bool:
	return effects.has("invincible")
