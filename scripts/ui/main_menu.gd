extends Control
## Main menu: three manual save slots, continue, endless mode entry, credits.

var slots_box: VBoxContainer


func _ready() -> void:
	AudioManager.play_track("main_menu")
	var bg := ColorRect.new()
	bg.color = UIKit.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIKit.panel(Vector2(360, 0))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := UIKit.label(GameState.game_title, 20, UIKit.COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	vb.add_child(UIKit.label("Rebuild the World Bridge. Mind the store.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.hsep())
	slots_box = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 6)
	vb.add_child(slots_box)
	_fill_slots()
	vb.add_child(UIKit.hsep())
	vb.add_child(UIKit.label("Move WASD/arrows | Interact E | Attack J | Special K | Dodge L | Item I | Finisher U | Debug F3", 8, UIKit.COL_DIM))
	vb.add_child(UIKit.label("Sprites: The Spriters Resource (see credits/). Original chiptune placeholders.", 8, UIKit.COL_DIM))
	var quit_btn := UIKit.button("Quit", func() -> void: get_tree().quit())
	vb.add_child(quit_btn)


func _fill_slots() -> void:
	for child in slots_box.get_children():
		child.queue_free()
	for slot in range(1, 4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var summary := SaveManager.slot_summary(slot)
		if summary.is_empty():
			var lbl := UIKit.label("Slot %d — empty" % slot, 10)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			row.add_child(UIKit.button("New game", func() -> void: SceneRouter.start_new_campaign(slot)))
		else:
			var desc := "Slot %d — Day %d, Ch.%d, %dg%s" % [slot, int(summary["day"]), int(summary["chapter"]), int(summary["gold"]), " (Endless)" if bool(summary["endless"]) else ""]
			var lbl := UIKit.label(desc, 10)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			row.add_child(UIKit.button("Continue", func() -> void: SceneRouter.continue_campaign(slot)))
			row.add_child(UIKit.button("New", func() -> void: SceneRouter.start_new_campaign(slot)))
			row.add_child(UIKit.button("X", func() -> void:
				SaveManager.delete_slot(slot)
				_fill_slots()))
		slots_box.add_child(row)
