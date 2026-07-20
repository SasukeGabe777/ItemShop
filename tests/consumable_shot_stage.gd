extends Node
## Stage 2: inside a real co-op run, confirm hero 2 actually carries the belt
## that was planned for them, that using it heals them, and that both item
## readouts appear in the HUD.


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots/")
	await get_tree().create_timer(3.0).timeout
	var d: Node = get_tree().get_first_node_in_group("dungeon_runtime")
	if d == null:
		print("CONSUM FAIL: no dungeon_runtime")
		get_tree().quit()
		return
	var h1: CombatHero = d.get("hero")
	var h2: CombatHero = d.get("hero2")
	print("RUN p1 carries: ", h1.consumables)
	if h2 == null:
		print("RUN FAIL: hero2 is null (co-op did not spawn)")
	else:
		print("RUN p2 carries: ", h2.consumables)
		h2.health.take_damage(h2.health.max_hp - 6, self)
		var before := h2.health.hp
		h2._use_consumable()
		print("RUN p2 heal: %d -> %d, belt now %s" % [before, h2.health.hp, h2.consumables])
	var lbl: Label = d.get("consum_label")
	var lbl2: Label = d.get("consum_label2")
	print("HUD p1 label: ", lbl.text if lbl != null else "<none>")
	print("HUD p2 label: ", lbl2.text if lbl2 != null else "<none>")
	get_viewport().get_texture().get_image().save_png("user://screenshots/consum_hud.png")
	print("CONSUM_SHOT_DONE")
	get_tree().quit()
