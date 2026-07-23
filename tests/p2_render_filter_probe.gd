extends Node
## Headless regression proof that split-screen P2 inherits P1's pixel filter.


class Probe:
	extends Node

	func _ready() -> void:
		var scale_passed := true
		var expected_factors := [0.85, 1.0, 1.25]
		var expected_labels := ["SMALL", "NORMAL", "LARGE"]
		for i in MultiplayerState.UI_SCALE_PRESETS.size():
			MultiplayerState.set_ui_scale_preset(i)
			scale_passed = scale_passed \
				and is_equal_approx(MultiplayerState.ui_scale_factor(), expected_factors[i]) \
				and MultiplayerState.ui_scale_label() == expected_labels[i]
		MultiplayerState.set_ui_scale_preset(1)
		MultiplayerState.set_enabled(true)
		SceneRouter.go("town")
		await get_tree().create_timer(1.0).timeout
		var root_filter := get_viewport().canvas_item_default_texture_filter
		var p2vp := MultiplayerState.p2_viewport() as SubViewport
		var passed := scale_passed and p2vp != null \
			and p2vp.canvas_item_default_texture_filter == root_filter
		if passed:
			print("P2_RENDER_FILTER_PROBE_PASS root=", root_filter,
				" p2=", p2vp.canvas_item_default_texture_filter)
		else:
			printerr("P2_RENDER_FILTER_PROBE_FAIL root=", root_filter,
				" p2=", p2vp.canvas_item_default_texture_filter if p2vp != null else "missing")
		MultiplayerState.set_enabled(false)
		get_tree().quit(0 if passed else 1)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
