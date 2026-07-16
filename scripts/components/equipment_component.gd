class_name EquipmentComponent
extends Node
## View over a hero's four equipment slots (weapon/armor/accessory/charm),
## backed by InventoryManager so loadouts persist in saves.

var hero_id: String = ""


func setup(id: String) -> void:
	hero_id = id


func slots() -> Dictionary:
	return InventoryManager.hero_equipment.get(hero_id, {"weapon": "", "armor": "", "accessory": "", "charm": ""})


func equipped(slot: String) -> String:
	return String(slots().get(slot, ""))


func stats() -> Dictionary:
	return InventoryManager.hero_stats(hero_id)


func equip(slot: String, item_id: String) -> bool:
	return InventoryManager.equip(hero_id, slot, item_id)
