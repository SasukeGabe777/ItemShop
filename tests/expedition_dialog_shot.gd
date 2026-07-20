extends Node2D
## Probe: the expedition dialog. Opens the real GatesPanel expedition modal in
## co-op, screenshots the two consumable pickers, and dumps what the dropdown
## offers so the heal amounts can be read without squinting at the shot.


func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_campaign()
	TimeManager.reset(1)
	EconomyManager.reset()
	InventoryManager.reset()
	BridgeManager.reset()
	MultiplayerState.enabled = true
	EconomyManager.add_gold(9999)
	# stock a spread of healing items so the picker has something to show
	for id in ["hi_potion", "kh_potion", "super_potion", "oran_berry", "ff_elixir",
			"ramen_bowl", "mega_burger", "poke_ball", "escape_rope", "senzu_bean"]:
		InventoryManager.add_item(id, 3)
	var panel := GatesPanel.new()
	get_tree().root.add_child(panel)
	await get_tree().create_timer(1.2).timeout
	panel.call("_expedition_dialog", "kingdom_hearts")
	await get_tree().create_timer(1.6).timeout

	# report what the picker actually offers
	var offered: Array[String] = []
	for id in InventoryManager.sorted_ids("name"):
		var cat := String(ContentDatabase.get_item(id).get("category", ""))
		if cat in ["consumable", "food"] and ContentDatabase.is_field_usable(id):
			offered.append("%s x%d — %s" % [ContentDatabase.item_name(id),
				InventoryManager.count(id), ContentDatabase.item_effect_summary(id)])
	print("DIALOG picker offers:")
	for line in offered:
		print("   ", line)
	var hidden: Array[String] = []
	for id in InventoryManager.sorted_ids("name"):
		var cat2 := String(ContentDatabase.get_item(id).get("category", ""))
		if cat2 in ["consumable", "food"] and not ContentDatabase.is_field_usable(id):
			hidden.append(ContentDatabase.item_name(id))
	print("DIALOG hidden (no field effect): ", hidden)

	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	get_viewport().get_texture().get_image().save_png("user://screenshots/expedition_dialog.png")
	print("DIALOG_SHOT_DONE")
	get_tree().quit()
