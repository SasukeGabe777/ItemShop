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


func time_left(effect_name: String) -> float:
	return float(effects.get(effect_name, {}).get("time_left", 0.0))


## Short, continuously accurate HUD readout. Keeping this on the component
## means gameplay and presentation cannot disagree about which buffs are live.
func summary_parts() -> Array[String]:
	var parts: Array[String] = []
	if effects.has("invincible"):
		parts.append("Invincible %.1fs" % time_left("invincible"))
	if effects.has("buff_atk"):
		parts.append("ATK +%s %.1fs" % [
			str(float(effects["buff_atk"].get("value", 0.0))),
			time_left("buff_atk")])
	if effects.has("buff_def"):
		parts.append("DEF +%s %.1fs" % [
			str(float(effects["buff_def"].get("value", 0.0))),
			time_left("buff_def")])
	if effects.has("stun"):
		parts.append("Stunned %.1fs" % time_left("stun"))
	return parts
