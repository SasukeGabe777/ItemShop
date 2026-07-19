extends Node
## Lives inside P2's SubViewport and consumes every input event that did NOT
## come from MultiplayerState's device-1 pump (tagged with meta "p2src").
## SubViewportContainer forwards root events into the viewport on some paths
## regardless of overrides — this gate guarantees Player 1's pad can never
## drive Player 2's menus.
##
## It also mirrors PadNav's menu rescue moves for this half, since PadNav
## deliberately never reaches into another player's viewport:
##  - B jumps focus to the menu's Close/Cancel button (recovers focus first
##    if it was lost)
##  - A with nothing focused recovers onto the topmost menu's first button


func _input(event: InputEvent) -> void:
	if not event.get_meta("p2src", false):
		get_viewport().set_input_as_handled()
		return
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner()
	if event.is_action_pressed("ui_cancel"):
		var root: Node = PadNav._menu_root_of(focus) if focus != null else _topmost_menu_layer()
		if root == null:
			return
		var close := PadNav._find_close_button(root)
		if close != null and close != focus:
			close.grab_focus()
			vp.set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and focus == null and UIKit.modal_open(vp):
		var root := _topmost_menu_layer()
		if root != null:
			var b := UIKit._first_button_in(root)
			if b != null:
				b.grab_focus()
				vp.set_input_as_handled()


## Highest-layered visible CanvasLayer in THIS viewport that holds a button.
func _topmost_menu_layer() -> Node:
	var best: CanvasLayer = null
	for layer: Node in get_viewport().find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		if cl == null or not cl.visible or cl.get_meta("pad_recovery_skip", false):
			continue
		if UIKit._first_button_in(cl) == null:
			continue
		if best == null or cl.layer >= best.layer:
			best = cl
	return best
