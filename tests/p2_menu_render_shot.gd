extends Node
## Windowed proof that identical P1/P2 menus render at matching sharpness.

const SHOT_DIR := "user://screenshots/p2_menu_render/"


class Probe:
	extends Node

	func _ready() -> void:
		MultiplayerState.set_enabled(true)
		SceneRouter.go("town")
		await get_tree().create_timer(1.2).timeout
		var town := get_tree().current_scene
		var p2vp := MultiplayerState.p2_viewport() as SubViewport
		var p1_parts := UIKit.modal(town, "Player 1 — Render Test")
		var p2_parts := UIKit.modal(p2vp, "Player 2 — Render Test")
		_fill_identical(p1_parts[1])
		_fill_identical(p2_parts[1])
		await get_tree().create_timer(0.8).timeout
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		get_viewport().get_texture().get_image().save_png(
			SHOT_DIR + "01_matching_multiplayer_menus.png")
		print("P2_MENU_RENDER_SHOT_DONE folder=",
			ProjectSettings.globalize_path(SHOT_DIR))
		MultiplayerState.set_enabled(false)
		get_tree().quit()

	func _fill_identical(vb: VBoxContainer) -> void:
		vb.add_child(UIKit.label("The same text, art, and layout on both screens.", 10))
		for item_id in ["dragon_ball", "fairy_harp_keyblade", "field_medkit"]:
			vb.add_child(UIKit.item_row(item_id, "×1  ~500g", "Select",
				func() -> void: pass))
		vb.add_child(UIKit.button("Close", func() -> void: pass))


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
