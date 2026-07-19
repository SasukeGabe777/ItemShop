extends Node
## Local 2-player split-screen support. Player 1 owns the root viewport (top
## half — its camera shifts so P1 reads centered); Player 2 lives in a
## bottom-half SubViewport that shares the same world. While enabled, every
## base action's joypad bindings pin to device 0 and cloned p2_* actions poll
## device 1, so the two pads never cross. P2's menus are parented inside the
## SubViewport: they render only on P2's half and use that viewport's own GUI
## focus, driven by device-1 events re-pushed as device-0 into it.

const P2_DEVICE := 1
const CLONE_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "interact", "cancel"]
const PIN_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down", "interact", "cancel",
	"attack", "special", "dodge", "use_item", "finisher", "menu",
	"ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down",
	"zoom_in", "zoom_out",
]

var enabled: bool = false
var _rig: CanvasLayer = null
var _p2_view: SubViewport = null
var _ready_sets: Dictionary = {}  # action id -> {player_idx: true}


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_ready_sets.clear()
	if enabled:
		_split_input_devices()
	else:
		_restore_input_devices()
		if _rig != null and is_instance_valid(_rig):
			_rig.queue_free()
		_rig = null
		_p2_view = null


func p2_viewport() -> Viewport:
	return _p2_view if _p2_view != null and is_instance_valid(_p2_view) else null


## Where a player's menus should live: P2's render inside their SubViewport,
## P1's (and single-player) wherever the caller intended.
func menu_parent(player_idx: int, fallback: Node) -> Node:
	if player_idx == 2 and p2_viewport() != null:
		return _p2_view
	return fallback


## Build the bottom-half view + P2 body inside `scene`. Returns the P2 player.
func attach_split(scene: Node2D, p1: TownPlayer) -> TownPlayer:
	_ready_sets.clear()
	var p2 := TownPlayer.new()
	p2.input_prefix = "p2_"
	p2.position = p1.position + Vector2(24, 0)
	p2.modulate = Color(1.0, 0.88, 0.82)  # subtle tint so the twins read apart
	scene.add_child(p2)
	_rig = CanvasLayer.new()
	_rig.layer = 15  # under menus/HUD, over the world
	_rig.set_meta("pad_recovery_skip", true)
	scene.add_child(_rig)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	svc.anchor_top = 0.5
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(svc)
	_p2_view = SubViewport.new()
	_p2_view.world_2d = scene.get_viewport().world_2d
	_p2_view.gui_disable_input = false
	_p2_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_p2_view)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * ZoomCamera.preferred_zoom
	_p2_view.add_child(cam)
	# keep P2's camera glued to their body, and P1's camera centered on the
	# visible top half (the rig owns this so scenes stay untouched)
	var follower := Node.new()
	follower.set_script(_FollowerScript)
	follower.set("cam", cam)
	follower.set("target", p2)
	follower.set("p1", p1)
	_rig.add_child(follower)
	var divider := ColorRect.new()
	divider.color = Color(0.08, 0.08, 0.14)
	divider.set_anchors_preset(Control.PRESET_TOP_WIDE)
	divider.anchor_top = 0.5
	divider.anchor_bottom = 0.5
	divider.offset_top = -2
	divider.offset_bottom = 2
	_rig.add_child(divider)
	return p2


const _FollowerScript := preload("res://scripts/systems/split_follower.gd")


## ---- ready queue ("1/2 ready to open the shop") --------------------------

## Marks a player ready for a shared action; true once everyone is in.
func ready_up(action_id: String, player_idx: int, needed: int = 2) -> bool:
	if not enabled:
		return true
	var set_ref: Dictionary = _ready_sets.get(action_id, {})
	set_ref[player_idx] = true
	_ready_sets[action_id] = set_ref
	return set_ref.size() >= needed


func ready_count(action_id: String) -> int:
	return (_ready_sets.get(action_id, {}) as Dictionary).size()


func clear_ready(action_id: String = "") -> void:
	if action_id == "":
		_ready_sets.clear()
	else:
		_ready_sets.erase(action_id)


## ---- input plumbing -------------------------------------------------------

## Route P2's pad into their SubViewport's GUI as device-0 events (the base
## ui_* actions are pinned to device 0 while split-screen is on).
func _input(event: InputEvent) -> void:
	if not enabled or p2_viewport() == null:
		return
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device == P2_DEVICE:
		var dup := event.duplicate()
		dup.device = 0
		_p2_view.push_input(dup)


func _split_input_devices() -> void:
	for action in PIN_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = 0
	for action in CLONE_ACTIONS:
		var p2a := "p2_%s" % action
		if InputMap.has_action(p2a):
			InputMap.erase_action(p2a)
		InputMap.add_action(p2a, InputMap.action_get_deadzone(action))
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				var dup: InputEvent = ev.duplicate()
				dup.device = P2_DEVICE
				InputMap.action_add_event(p2a, dup)


func _restore_input_devices() -> void:
	for action in PIN_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = -1
	for action in CLONE_ACTIONS:
		var p2a := "p2_%s" % action
		if InputMap.has_action(p2a):
			InputMap.erase_action(p2a)
