class_name NegotiationProfile
extends Node
## Data view over a customer's negotiation parameters (archetype + overrides).
## Attach to customer entities so designers can inspect live values.

var customer: Dictionary = {}


func setup(cust: Dictionary) -> void:
	customer = cust


func archetype() -> Dictionary:
	return ContentDatabase.get_archetype(String(customer.get("archetype", "")))


func markup_tolerance() -> float:
	return float(archetype().get("markup_tolerance", 1.3))


func haggle_skill() -> float:
	return float(archetype().get("haggle", 0.4))


func patience() -> int:
	return int(archetype().get("patience", 3))


func budget() -> int:
	return int(customer.get("budget", 0))
