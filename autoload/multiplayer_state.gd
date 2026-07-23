extends Node
## Local 2-player split-screen support. Player 1 owns the root viewport (top
## half — its camera shifts so P1 reads centered); Player 2 lives in a
## bottom-half SubViewport that shares the same world. While enabled, every
## base action's joypad bindings pin to device 0 and cloned p2_* actions poll
## device 1, so the two pads never cross. P2's menus are parented inside the
## SubViewport: they render only on P2's half and use that viewport's own GUI
## focus, driven by device-1 events re-pushed as device-0 into it.

const P2_DEVICE := 1
const UI_SCALE_PRESETS := [
	{"label": "SMALL", "factor": 0.85},
	{"label": "NORMAL", "factor": 1.0},
	{"label": "LARGE", "factor": 1.25},
]
const CLONE_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "interact", "cancel",
	"attack", "special", "dodge", "use_item", "finisher", "zoom_in", "zoom_out"]
const PIN_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down", "interact", "cancel",
	"attack", "special", "dodge", "use_item", "finisher", "menu",
	"ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down",
	"zoom_in", "zoom_out",
]

var enabled: bool = false
var ui_scale_preset: int = 1
var p2_zoom: float = 1.5        # P2's own zoom level (P1 keeps ZoomCamera's)
var p2_zoom_factor: float = 1.0  # physical-pixel factor of the P2 viewport
var next_customer_player := 1   # persists across shop scenes while co-op stays on
var _rig: CanvasLayer = null
var _p2_view: SubViewport = null
var _ready_sets: Dictionary = {}  # action id -> {player_idx: true}
var pending_confirm: Dictionary = {}  # {key, player, text, on_confirm}


func ui_scale_label() -> String:
	return String(UI_SCALE_PRESETS[ui_scale_preset]["label"])


func ui_scale_factor() -> float:
	return float(UI_SCALE_PRESETS[ui_scale_preset]["factor"])


func cycle_ui_scale() -> void:
	ui_scale_preset = (ui_scale_preset + 1) % UI_SCALE_PRESETS.size()


func set_ui_scale_preset(value: int) -> void:
	ui_scale_preset = clampi(value, 0, UI_SCALE_PRESETS.size() - 1)


func toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if fullscreen
		else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Ask the OTHER player to approve something with a world-side A press
## (used for expeditions: the gates menu holds one player, the partner
## just needs to say yes from wherever they stand).
func request_confirm(key: String, player_idx: int, text: String, on_confirm: Callable) -> void:
	pending_confirm = {"key": key, "player": player_idx, "text": text, "on_confirm": on_confirm}


func clear_confirm(key: String = "") -> void:
	if key == "" or String(pending_confirm.get("key", "")) == key:
		pending_confirm = {}


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	next_customer_player = 1
	_ready_sets.clear()
	pending_confirm = {}
	_focus_mem.clear()
	_focus_paint.clear()
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


var _svc: SubViewportContainer = null


## Build the right-half view + P2 body inside `scene`. Returns the P2 player.
## The SubViewport renders at NATIVE window resolution (then scales down into
## the stretched canvas space) so P2's half is exactly as sharp as P1's.
func attach_split(scene: Node2D, p1: TownPlayer) -> TownPlayer:
	_ready_sets.clear()
	pending_confirm = {}
	_focus_mem.clear()
	_focus_paint.clear()
	var p2 := TownPlayer.new()
	p2.input_prefix = "p2_"
	p2.position = p1.position + Vector2(24, 0)
	p2.modulate = Color(1.0, 0.88, 0.82)  # subtle tint so the twins read apart
	scene.add_child(p2)
	_rig = CanvasLayer.new()
	_rig.layer = 15  # under menus/HUD, over the world
	_rig.set_meta("pad_recovery_skip", true)
	scene.add_child(_rig)
	_svc = SubViewportContainer.new()
	_svc.set_script(preload("res://scripts/systems/p2_view_container.gd"))
	_svc.stretch = false
	_svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(_svc)
	_p2_view = SubViewport.new()
	# New SubViewports default to linear filtering even though this pixel-art
	# project renders the root viewport with nearest filtering. Match P1 before
	# any P2 world or menu controls are created so the two halves stay equally
	# crisp at the same physical scale.
	_p2_view.canvas_item_default_texture_filter = \
		scene.get_viewport().canvas_item_default_texture_filter
	_p2_view.world_2d = scene.get_viewport().world_2d
	_p2_view.gui_disable_input = false
	_p2_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svc.add_child(_p2_view)
	var gate := Node.new()
	gate.set_script(preload("res://scripts/systems/p2_input_gate.gd"))
	_p2_view.add_child(gate)
	var cam := Camera2D.new()
	p2_zoom = ZoomCamera.preferred_zoom
	cam.zoom = Vector2.ONE * p2_zoom
	_p2_view.add_child(cam)
	# keep P2's camera glued to their body, and P1's camera centered on the
	# visible left half (the rig owns this so scenes stay untouched)
	var follower := Node.new()
	follower.set_script(_FollowerScript)
	follower.set("cam", cam)
	follower.set("target", p2)
	follower.set("p1", p1)
	_rig.add_child(follower)
	var divider := ColorRect.new()
	divider.color = Color(0.08, 0.08, 0.14)
	divider.set_anchors_preset(Control.PRESET_CENTER)
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.anchor_top = 0.0
	divider.anchor_bottom = 1.0
	divider.offset_left = -1
	divider.offset_right = 1
	divider.offset_top = 0
	divider.offset_bottom = 0
	_rig.add_child(divider)
	_fit_rig()
	var root := scene.get_viewport()
	if not root.size_changed.is_connected(_fit_rig):
		root.size_changed.connect(_fit_rig)
	return p2


## Size the P2 viewport to physical pixels: half the window wide, full height,
## displayed scaled down by the window's stretch factor so pixels map 1:1.
func _fit_rig() -> void:
	if _svc == null or not is_instance_valid(_svc) or _p2_view == null:
		return
	var logical: Vector2 = _svc.get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var factor: float = maxf(1.0, win.x / maxf(1.0, logical.x))
	var half := Vector2(logical.x * 0.5, logical.y)
	_p2_view.size = Vector2i((half * factor).round())
	_svc.scale = Vector2.ONE / factor
	_svc.position = Vector2(logical.x * 0.5, 0.0)
	_svc.size = Vector2(_p2_view.size)
	# P2's viewport is `factor`x more pixels than P1's logical view, so its
	# camera zoom must scale by the same factor or P2 sees far more world
	p2_zoom_factor = factor


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

const _NAV_DIRS := [
	["ui_up", JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
	["ui_down", JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
	["ui_left", JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
	["ui_right", JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
]
const _REPEAT_DELAY := 0.38
const _REPEAT_RATE := 0.14
const _SCROLL_SPEED := 620.0

var _p2_held: Dictionary = {}       # ui action -> time until next synthetic press
var _p2_last_focus: Control = null
var _focus_mem: Dictionary = {}     # player idx -> last real focus in their viewport
var _focus_paint: Dictionary = {}   # player idx -> button wearing the fake highlight


## The engine allows ONE GUI focus per window: grabbing focus inside the P2
## SubViewport wipes the root viewport's focus and vice versa, so two open
## menus constantly kill each other's selector. Each player's focus is
## remembered here and restored just-in-time when THEIR input arrives; the
## side that doesn't hold the engine focus keeps a painted stand-in
## highlight so both selectors stay visible.
func _remember_focus() -> void:
	_track_focus(1, get_viewport())
	_track_focus(2, p2_viewport())


func _track_focus(idx: int, vp: Viewport) -> void:
	if vp == null:
		return
	var f := vp.gui_get_focus_owner()
	if f != null:
		_focus_mem[idx] = f
		_paint_focus(idx, null)
		return
	var remembered: Variant = _focus_mem.get(idx)
	if remembered != null and is_instance_valid(remembered) \
			and remembered is Control and remembered.is_inside_tree() \
			and remembered.get_viewport() == vp and UIKit.modal_open(vp):
		_paint_focus(idx, remembered as Control)
	else:
		_focus_mem.erase(idx)
		_paint_focus(idx, null)


## Regrab a player's remembered focus (their selector) if the other player's
## menu activity wiped it. Returns whatever ends up focused.
func _restore_focus(idx: int) -> Control:
	var vp: Viewport = get_viewport() if idx == 1 else p2_viewport()
	if vp == null:
		return null
	var f := vp.gui_get_focus_owner()
	if f != null:
		return f
	if not UIKit.modal_open(vp):
		return null
	var remembered: Variant = _focus_mem.get(idx)
	if remembered != null and is_instance_valid(remembered) and remembered is Control \
			and remembered.is_inside_tree() and remembered.get_viewport() == vp:
		var m := remembered as Control
		m.grab_focus()
		return m
	_focus_mem.erase(idx)
	# no memory (e.g. both menus opened the same frame and the later grab
	# wiped this one before it was ever seen): recover onto the topmost menu
	var lay := _topmost_layer_in(vp)
	if lay != null:
		var b := UIKit._first_button_in(lay)
		if b != null:
			b.grab_focus()
			return b
	return null


## Highest-layered visible CanvasLayer belonging to `vp` that holds a button.
func _topmost_layer_in(vp: Viewport) -> Node:
	var best: CanvasLayer = null
	for layer: Node in vp.find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		if cl == null or not cl.visible or cl.get_meta("pad_recovery_skip", false):
			continue
		if cl.get_viewport() != vp:
			continue
		if UIKit._first_button_in(cl) == null:
			continue
		if best == null or cl.layer >= best.layer:
			best = cl
	return best


## The stand-in highlight: the focus look, worn as the "normal" style.
func _paint_focus(idx: int, c: Control) -> void:
	var previous: Variant = _focus_paint.get(idx)
	if previous == c:
		return
	if previous != null and is_instance_valid(previous) and previous is Control:
		var prev := previous as Control
		prev.remove_theme_stylebox_override("normal")
		prev.remove_theme_color_override("font_color")
	_focus_paint[idx] = c
	if c is Button:
		var t := UIKit.light_theme()
		if t.has_stylebox("focus", "Button"):
			c.add_theme_stylebox_override("normal", t.get_stylebox("focus", "Button"))
		c.add_theme_color_override("font_color", Color.WHITE)


## PadNav for Player 2's half. Their menus live inside the SubViewport, whose
## built-in focus navigation ignores pumped JoypadMotion events (the engine
## double-checks those against the global Input state, which is pinned to
## device 0) — so the left stick is polled here and turned into synthetic
## ui_* presses, which also gives P2 held-direction repeat like P1 has.
func _process(delta: float) -> void:
	if not enabled or p2_viewport() == null:
		_p2_held.clear()
		_p2_last_focus = null
		return
	_remember_focus()
	if not UIKit.modal_open(_p2_view):
		_p2_held.clear()
		_p2_last_focus = null
		return
	var focus := _p2_view.gui_get_focus_owner()
	if focus == null:
		for dir: Array in _NAV_DIRS:
			if Input.get_joy_axis(P2_DEVICE, dir[1]) * float(dir[2]) > 0.55 \
					or Input.is_joy_button_pressed(P2_DEVICE, dir[3]):
				focus = _restore_focus(2)
				break
	if focus != _p2_last_focus and focus != null and _p2_last_focus != null:
		AudioManager.play_sfx("menu_movement", -8.0)
	_p2_last_focus = focus
	for dir: Array in _NAV_DIRS:
		var action: String = dir[0]
		var stick: bool = Input.get_joy_axis(P2_DEVICE, dir[1]) * float(dir[2]) > 0.55
		var dpad: bool = Input.is_joy_button_pressed(P2_DEVICE, dir[3])
		if (stick or dpad) and focus != null:
			if not _p2_held.has(action):
				_p2_held[action] = _REPEAT_DELAY
				if stick and not dpad:
					# a D-pad press already navigated via its own pumped event;
					# a stick push did not (see above), so fire the first step
					_push_p2_nav(action)
			else:
				_p2_held[action] -= delta
				if _p2_held[action] <= 0.0:
					_p2_held[action] = _REPEAT_RATE
					_push_p2_nav(action)
		else:
			_p2_held.erase(action)
	# right stick scrolls whatever list holds P2's focus, like PadNav for P1
	var rv := Input.get_joy_axis(P2_DEVICE, JOY_AXIS_RIGHT_Y)
	if absf(rv) >= 0.3 and focus != null:
		var node: Node = focus
		while node != null and not (node is ScrollContainer):
			node = node.get_parent()
		if node is ScrollContainer:
			(node as ScrollContainer).scroll_vertical += int(rv * _SCROLL_SPEED * delta)


func _push_p2_nav(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.set_meta("p2src", true)
	_p2_view.push_input(ev)


## Route P2's pad into their SubViewport's GUI as device-0 events (the base
## ui_* actions are pinned to device 0 while split-screen is on). Each
## player's events first win back their own selector if the other player's
## focus grabs wiped it (one engine focus per window — see _remember_focus).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_F11 or event.physical_keycode == KEY_F11):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if not enabled:
		return
	var is_joy := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if is_joy and event.device == P2_DEVICE and p2_viewport() != null:
		if _deliberate(event) and _p2_view.gui_get_focus_owner() == null:
			_restore_focus(2)
		var dup := event.duplicate()
		dup.device = 0
		dup.set_meta("p2src", true)  # the gate inside the viewport admits only these
		_p2_view.push_input(dup)
	elif (is_joy and event.device == 0) or event is InputEventKey:
		var rvp := get_viewport()
		if _deliberate(event) and rvp.gui_get_focus_owner() == null:
			_restore_focus(1)
		# PadNav's _unhandled_input rescues never fire while the split rig
		# exists (the view container consumes the chain), so P1's B-to-close
		# jump lives here in split-screen
		if event.is_action_pressed("ui_cancel") and UIKit.modal_open(rvp):
			var f := rvp.gui_get_focus_owner()
			if f != null:
				var close := PadNav._find_close_button(PadNav._menu_root_of(f))
				if close != null and close != f:
					close.grab_focus()
					rvp.set_input_as_handled()


## A press or a firm stick push — stick drift must not thrash the focus.
func _deliberate(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.5
	return event.is_pressed()


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
