extends Control
## Online co-op lobby. Choose panel: pick a name, then HOST, join a
## discovered LAN game, or JOIN BY IP (the out-of-town friend types the
## host's Tailscale/Hamachi or forwarded IP). Lobby panel: the 5-seat roster
## with ready checks; the host starts or continues a campaign once everyone
## is ready and the whole party rides along.

const PROFILE_PATH := "user://net_profile.json"

var ui_root: Control
var _choose_box: VBoxContainer
var _lobby_box: VBoxContainer
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _lan_list: VBoxContainer
var _roster_box: VBoxContainer
var _status: Label
var _host_info: Label
var _ready_btn: Button
var _start_new_btn: Button
var _continue_btn: Button
var _found: Dictionary = {}  # ip -> info


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_root)
	var bg := ColorRect.new()
	bg.color = UIKit.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(center)
	var panel := UIKit.ornate_panel(Vector2(430, 0))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title := UIKit.label("ONLINE CO-OP", 16, UIKit.COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_status = UIKit.label("", 9, UIKit.COL_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)
	_choose_box = VBoxContainer.new()
	_choose_box.add_theme_constant_override("separation", 6)
	vb.add_child(_choose_box)
	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 6)
	vb.add_child(_lobby_box)
	_build_choose_panel()
	_build_lobby_panel()

	Net.roster_changed.connect(_refresh_roster)
	Net.hosting_started.connect(_enter_lobby)
	Net.join_succeeded.connect(func(_idx: int) -> void: _enter_lobby())
	Net.join_failed.connect(func(reason: String) -> void:
		_set_status(reason)
		_show_choose())
	Net.upnp_result.connect(func(_ok: bool, _msg: String) -> void: _refresh_host_info())

	var disc: Node = Net.discovery()
	if not disc.lobby_found.is_connected(_on_lobby_found):
		disc.lobby_found.connect(_on_lobby_found)

	if Net.is_online():
		_enter_lobby()
	else:
		_show_choose()


func _exit_tree() -> void:
	var disc: Node = Net.discovery()
	if disc != null and disc.lobby_found.is_connected(_on_lobby_found):
		disc.lobby_found.disconnect(_on_lobby_found)


## ---- choose panel ----------------------------------------------------------

func _build_choose_panel() -> void:
	var profile := _load_profile()
	_choose_box.add_child(UIKit.label("Your name:", 9, UIKit.COL_DIM))
	_name_edit = LineEdit.new()
	_name_edit.text = String(profile.get("name", _default_name()))
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 22)
	_choose_box.add_child(_name_edit)
	_choose_box.add_child(UIKit.button("HOST A GAME", _on_host_pressed, 11))
	_choose_box.add_child(UIKit.hsep())
	_choose_box.add_child(UIKit.label("Games on your network:", 9, UIKit.COL_DIM))
	_lan_list = VBoxContainer.new()
	_lan_list.add_theme_constant_override("separation", 3)
	_choose_box.add_child(_lan_list)
	_lan_list.add_child(UIKit.label("Searching...", 9, UIKit.COL_DIM))
	_choose_box.add_child(UIKit.hsep())
	_choose_box.add_child(UIKit.label(
		"Friend in another town? They join by IP (Tailscale/Hamachi IP,\nor your public IP if the port opens).", 8, UIKit.COL_DIM))
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 6)
	_ip_edit = LineEdit.new()
	_ip_edit.text = String(profile.get("last_ip", ""))
	_ip_edit.placeholder_text = "host IP address"
	_ip_edit.custom_minimum_size = Vector2(220, 22)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip_edit)
	ip_row.add_child(UIKit.button("JOIN BY IP", _on_join_by_ip, 10))
	_choose_box.add_child(ip_row)
	_choose_box.add_child(UIKit.spacer_px(4))
	_choose_box.add_child(UIKit.button("BACK", _on_back, 10))


func _on_host_pressed() -> void:
	_save_profile()
	var err := Net.host_game(_player_name())
	if err != OK:
		_set_status("Could not host: %s (is another host running on this PC?)"
			% error_string(err))


func _on_join_by_ip() -> void:
	_join(_ip_edit.text.strip_edges())


func _join(ip: String) -> void:
	if ip == "":
		_set_status("Enter the host's IP address first.")
		return
	_save_profile()
	_set_status("Joining %s..." % ip)
	var err := Net.join_game(ip, _player_name())
	if err != OK:
		_set_status("Could not start joining: %s" % error_string(err))


func _on_lobby_found(info: Dictionary, ip: String) -> void:
	if Net.is_online():
		return
	var known: bool = _found.has(ip)
	_found[ip] = info
	if not known:
		_refresh_lan_list()


func _refresh_lan_list() -> void:
	for child in _lan_list.get_children():
		child.queue_free()
	if _found.is_empty():
		_lan_list.add_child(UIKit.label("Searching...", 9, UIKit.COL_DIM))
		return
	for ip: String in _found:
		var info: Dictionary = _found[ip]
		var text := "%s's game — %d/%d — v%s (%s)" % [
			String(info.get("name", "?")), int(info.get("players", 0)),
			int(info.get("max", 5)), String(info.get("version", "?")), ip]
		_lan_list.add_child(UIKit.button(text, _join.bind(ip), 9))


## ---- lobby panel -----------------------------------------------------------

func _build_lobby_panel() -> void:
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 3)
	_lobby_box.add_child(_roster_box)
	_lobby_box.add_child(UIKit.spacer_px(2))
	_host_info = UIKit.label("", 8, UIKit.COL_DIM)
	_host_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_box.add_child(_host_info)
	_lobby_box.add_child(UIKit.hsep())
	_lobby_box.add_child(UIKit.button("CHOOSE CHARACTER", _open_character_select, 10))
	_ready_btn = UIKit.button("READY UP", _on_ready_pressed, 11)
	_lobby_box.add_child(_ready_btn)
	_start_new_btn = UIKit.button("START NEW GAME", _on_start_new, 11)
	_lobby_box.add_child(_start_new_btn)
	_continue_btn = UIKit.button("CONTINUE", _on_continue, 11)
	_lobby_box.add_child(_continue_btn)
	_lobby_box.add_child(UIKit.spacer_px(4))
	_lobby_box.add_child(UIKit.button("LEAVE", _on_leave, 10))


func _enter_lobby() -> void:
	_set_status("")
	_choose_box.visible = false
	_lobby_box.visible = true
	_refresh_roster()
	_refresh_host_info()
	UIKit.focus_first_button(_lobby_box)


func _show_choose() -> void:
	_choose_box.visible = true
	_lobby_box.visible = false
	Net.discovery().start_search()
	UIKit.focus_first_button(_choose_box)


func _refresh_roster() -> void:
	if _roster_box == null or not _lobby_box.visible:
		return
	for child in _roster_box.get_children():
		child.queue_free()
	for idx in range(1, PartyState.MAX_PLAYERS + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		if PartyState.players.has(idx):
			var seat: Dictionary = PartyState.player(idx)
			swatch.color = PartyState.color(idx)
			var tag := " (host)" if idx == 1 else ""
			var state := ""
			if not bool(seat.get("connected", true)):
				state = "  — connection lost"
			elif bool(seat.get("ready", false)):
				state = "  [READY]"
			var char_name := PartyState.avatar_name(String(seat.get("avatar", "omori")))
			row.add_child(UIKit.label("P%d  %s  [%s]%s%s" % [idx, PartyState.pname(idx),
				char_name, tag, state], 10, PartyState.color(idx)))
		else:
			swatch.color = Color(1, 1, 1, 0.12)
			row.add_child(UIKit.label("P%d  — open seat —" % idx, 10, UIKit.COL_DIM))
		_roster_box.add_child(row)
	var mine := bool(PartyState.player(PartyState.local_index()).get("ready", false))
	_ready_btn.text = "NOT READY (press to unready)" if mine else "READY UP"
	var can_start := Net.is_host() and _all_ready()
	_start_new_btn.visible = Net.is_host()
	_continue_btn.visible = Net.is_host()
	_start_new_btn.disabled = not can_start
	_continue_btn.disabled = not can_start


func _all_ready() -> bool:
	for idx: int in PartyState.players:
		var seat: Dictionary = PartyState.players[idx]
		if bool(seat.get("connected", true)) and not bool(seat.get("ready", false)):
			return false
	return true


func _refresh_host_info() -> void:
	if not Net.is_host():
		_host_info.text = "Waiting for the host to start..."
		return
	var ips: Array[String] = []
	for addr in IP.get_local_addresses():
		var a := String(addr)
		if a.begins_with("192.168.") or a.begins_with("10.") or _is_172_private(a):
			ips.append(a)
	var lines: Array[String] = []
	lines.append("Brothers on this network join from their LAN list, or by IP: %s"
		% (", ".join(ips) if not ips.is_empty() else "?"))
	lines.append(Net.upnp_message if Net.upnp_message != ""
		else "Remote friends: Tailscale/Hamachi IP, or forward UDP %d." % Net.PORT)
	if not Net.upnp_ok and Net.upnp_message != "" \
			and not Net.upnp_message.begins_with("Checking"):
		lines.append("Auto-open failed — remote friends should use Tailscale/Hamachi, or forward UDP %d." % Net.PORT)
	_host_info.text = "\n".join(lines)


func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var parts := a.split(".")
	return parts.size() > 1 and int(parts[1]) >= 16 and int(parts[1]) <= 31


func _on_ready_pressed() -> void:
	var mine := bool(PartyState.player(PartyState.local_index()).get("ready", false))
	Net.request("lobby.set_ready", {"ready": not mine})


## Grid of every avatar's sprite in a white menu — click one to play as it.
func _open_character_select() -> void:
	var parts := UIKit.modal(self, "Choose your character")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	(vb.get_parent() as PanelContainer).custom_minimum_size = Vector2(560, 0)
	var current := String(PartyState.player(PartyState.local_index()).get("avatar", ""))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for entry: Dictionary in PartyState.AVATARS:
		var aid := String(entry["id"])
		grid.add_child(_avatar_cell(aid, String(entry["name"]), aid == current, layer))
	vb.add_child(UIKit.button("Cancel", func() -> void: layer.queue_free()))
	UIKit.focus_first_button(grid)


func _avatar_cell(aid: String, cname: String, selected: bool, layer: CanvasLayer) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 64)
	btn.icon = PartyState.avatar_preview(aid)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# cap the sprite size (a 2x preview) instead of letting it fill the button,
	# so all twelve rows fit inside one screen
	btn.add_theme_constant_override("icon_max_width", 60)
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep pixel art crisp
	btn.tooltip_text = cname
	if selected:
		btn.add_theme_color_override("icon_normal_color", Color.WHITE)
		btn.modulate = Color(1.0, 0.95, 0.6)  # highlight the current pick
	btn.pressed.connect(func() -> void:
		Net.request("lobby.set_avatar", {"avatar": aid})
		layer.queue_free())
	cell.add_child(btn)
	var name_lbl := UIKit.label(cname, 9, PartyState.color(1) if selected else UIKit.COL_INK)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(name_lbl)
	return cell


func _on_start_new() -> void:
	if not _all_ready():
		return
	var parts := UIKit.modal(self, "New game — choose a slot")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	for slot in range(1, 4):
		var summary := SaveManager.slot_summary(slot)
		var text := "Slot %d — empty" % slot
		if not summary.is_empty():
			text = "Slot %d — Day %d, %d (will be overwritten)" % [
				slot, int(summary["day"]), int(summary["gold"])]
		vb.add_child(UIKit.button(text, func() -> void:
			SceneRouter.start_new_campaign(slot)))
	vb.add_child(UIKit.button("Cancel", func() -> void: layer.queue_free()))


func _on_continue() -> void:
	if not _all_ready():
		return
	var parts := UIKit.modal(self, "Continue — host's saves")
	var layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	var any := false
	var auto := SaveManager.autosave_summary()
	if not auto.is_empty():
		any = true
		vb.add_child(UIKit.button("Autosave — Day %d %s, Ch.%d, %d" % [
			int(auto["day"]), String(auto["period_name"]), int(auto["chapter"]),
			int(auto["gold"])],
			func() -> void: SceneRouter.continue_autosave()))
	for slot in range(1, 4):
		var summary := SaveManager.slot_summary(slot)
		if summary.is_empty():
			continue
		any = true
		vb.add_child(UIKit.button("Slot %d — Day %d %s, Ch.%d, %d" % [
			slot, int(summary["day"]), String(summary["period_name"]),
			int(summary["chapter"]), int(summary["gold"])],
			func() -> void: SceneRouter.continue_campaign(slot)))
	if not any:
		vb.add_child(UIKit.label("No saved games on this machine yet.", 10, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Cancel", func() -> void: layer.queue_free()))


func _on_leave() -> void:
	Net.leave()
	_found.clear()
	_refresh_lan_list()
	_show_choose()


func _on_back() -> void:
	if Net.is_online():
		Net.leave()
	SceneRouter.go("main_menu")


## ---- shared ----------------------------------------------------------------

func _set_status(text: String) -> void:
	_status.text = text


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else _default_name()


func _default_name() -> String:
	return OS.get_environment("USERNAME") if OS.get_environment("USERNAME") != "" else "Player"


func _load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		return {}
	var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_profile() -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"name": _player_name(),
			"last_ip": _ip_edit.text.strip_edges(),
		}))
