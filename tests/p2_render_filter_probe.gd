extends Node
## Headless regression proof that split-screen P2 inherits P1's pixel filter.


class Probe:
	extends Node

	func _ready() -> void:
		MultiplayerState.set_enabled(true)
		SceneRouter.go("town")
		await get_tree().create_timer(1.0).timeout
		var root_filter := get_viewport().canvas_item_default_texture_filter
		var p2vp := MultiplayerState.p2_viewport() as SubViewport
		var passed := p2vp != null \
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
