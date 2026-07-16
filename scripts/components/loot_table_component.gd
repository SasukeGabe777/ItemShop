class_name LootTableComponent
extends Node
## Rolls an enemy's data-driven loot table on death and reports drops.

var enemy_id: String = ""


func roll(bonus: float = 0.0) -> Dictionary:
	return {
		"items": DungeonManager.roll_loot(enemy_id, bonus),
		"gold": DungeonManager.roll_gold(enemy_id),
	}
