extends Node
## Controller quality-of-life for menus:
##  - held D-pad/stick repeats focus movement (gamepads have no key echo)
##  - the right stick scrolls whatever ScrollContainer holds the focus
##  - B (ui_cancel) jumps focus to the menu's Close/Cancel button
##  - pressing A with no focused control recovers focus onto the topmost
##    menu's first button (covers menus opened before a pad connects)

const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.14
const SCROLL_SPEED := 620.0

var _held: Dictionary = {}  # action -> time until next synthetic press


func _process(delta: float) -> void:
	if not UIKit.pad_connected():
		return
	var focus := get_viewport().gui_get_focus_owner()
	_echo_directions(delta, focus)
	_right_stick_scroll(delta, focus)


func _echo_directions(delta: float, focus: Control) -> void:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if Input.is_action_pressed(action) and focus != null:
			if not _held.has(action):
				_held[action] = REPEAT_DELAY
				continue
			_held[action] -= delta
			if _held[action] <= 0.0:
				_held[action] = REPEAT_RATE
				var ev := InputEventAction.new()
				ev.action = action
				ev.pressed = true
				Input.parse_input_event(ev)
		else:
			_held.erase(action)


func _right_stick_scroll(delta: float, focus: Control) -> void:
	if focus == null:
		return
	var v := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(v) < 0.3:
		return
	var node: Node = focus
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node is ScrollContainer:
		(node as ScrollContainer).scroll_vertical += int(v * SCROLL_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not UIKit.pad_connected():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if event.is_action_pressed("ui_cancel") and focus != null:
		var close := _find_close_button(_menu_root_of(focus))
		if close != null and close != focus:
			close.grab_focus()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and focus == null:
		# a menu is open but nothing is focused (opened pre-pad, or focus
		# was lost) — recover onto the topmost layer's first button
		var root := _topmost_ui_layer()
		if root != null:
			var b := UIKit._first_button_in(root)
			if b != null:
				b.grab_focus()
				get_viewport().set_input_as_handled()


## The modal/panel this control lives in: its CanvasLayer, or the scene root.
func _menu_root_of(c: Control) -> Node:
	var node: Node = c
	while node != null and not (node is CanvasLayer):
		node = node.get_parent()
	return node if node != null else c.get_tree().current_scene


## Highest-layered CanvasLayer that contains at least one button.
func _topmost_ui_layer() -> Node:
	var best: CanvasLayer = null
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		if cl == null or not cl.visible:
			continue
		if UIKit._first_button_in(cl) == null:
			continue
		if best == null or cl.layer >= best.layer:
			best = cl
	return best


## Last Close/Cancel/Done-style button inside the menu (they sit at the end).
func _find_close_button(root: Node) -> Button:
	var found: Button = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and (node as Button).visible and not (node as Button).disabled:
			var t := (node as Button).text.to_lower()
			if "close" in t or "cancel" in t or t.begins_with("back") or "done" in t:
				found = node
		for child in node.get_children():
			stack.append(child)
	return found
