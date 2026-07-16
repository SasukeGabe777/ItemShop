@tool
extends VBoxContainer
## Dashboard tab: content counts, missing-asset / broken-reference summary,
## and quick actions. Read-only except for the OS "open folder" shortcuts.

signal validate_requested
signal reload_requested

const STAT_LABELS := [
	["items", "Items"], ["enemies", "Enemies"], ["bosses", "Bosses"],
	["heroes", "Heroes"], ["npcs", "NPCs"], ["worlds", "Worlds"],
	["recipes", "Recipes"], ["customers", "Customers"],
	["story_scenes", "Story Scenes"], ["rooms", "Room Templates"],
	["music", "Music Entries"],
]

var _stat_value_labels: Dictionary = {}
var _missing_value_label: Label
var _broken_value_label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Crossroads Content Studio — Dashboard"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 4
	for pair in STAT_LABELS:
		var key: String = pair[0]
		var label_text: String = pair[1]
		var name_label := Label.new()
		name_label.text = label_text + ":"
		grid.add_child(name_label)
		var value_label := Label.new()
		value_label.text = "—"
		value_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		grid.add_child(value_label)
		_stat_value_labels[key] = value_label
	add_child(grid)
	add_child(HSeparator.new())

	var summary := GridContainer.new()
	summary.columns = 2
	var missing_name := Label.new()
	missing_name.text = "Missing assets (using generated placeholders):"
	summary.add_child(missing_name)
	_missing_value_label = Label.new()
	_missing_value_label.text = "—"
	_missing_value_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	summary.add_child(_missing_value_label)
	var broken_name := Label.new()
	broken_name.text = "Broken references:"
	summary.add_child(broken_name)
	_broken_value_label = Label.new()
	_broken_value_label.text = "—"
	_broken_value_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	summary.add_child(_broken_value_label)
	add_child(summary)
	add_child(HSeparator.new())

	var buttons := HFlowContainer.new()
	buttons.add_child(_make_button("Reload ContentDatabase", reload_requested.emit))
	buttons.add_child(_make_button("Validate All Content", validate_requested.emit))
	buttons.add_child(_make_button("Open Data Folder", func(): _open_folder("res://data")))
	buttons.add_child(_make_button("Open Assets Folder", func(): _open_folder("res://assets")))
	buttons.add_child(_make_button("Open Credits Folder", func(): _open_folder("res://credits")))
	add_child(buttons)

	var note := Label.new()
	note.text = "Note: this dock re-parses res://data itself — Godot only runs autoload singletons like ContentDatabase while the game is playing, not while you're editing."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(note)


func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


func _open_folder(res_path: String) -> void:
	OS.shell_open(ProjectSettings.globalize_path(res_path))


func refresh(scan: CCSContentScan, results: Array[Dictionary]) -> void:
	_stat_value_labels["items"].text = str(scan.items.size())
	_stat_value_labels["enemies"].text = str(scan.enemies.size())
	_stat_value_labels["bosses"].text = str(scan.bosses.size())
	_stat_value_labels["heroes"].text = str(scan.heroes.size())
	_stat_value_labels["npcs"].text = str(scan.npcs.size())
	_stat_value_labels["worlds"].text = str(scan.worlds.size())
	_stat_value_labels["recipes"].text = str(scan.recipes.size())
	_stat_value_labels["customers"].text = str(scan.customer_count())
	_stat_value_labels["story_scenes"].text = str(scan.story_scenes.size())
	_stat_value_labels["rooms"].text = str(scan.rooms.size())
	_stat_value_labels["music"].text = str(scan.music_track_count())

	var missing := 0
	var broken := 0
	for row in results:
		if row.get("category", "") == "asset":
			missing += 1
		elif row.get("category", "") == "reference":
			broken += 1
	_missing_value_label.text = str(missing)
	_broken_value_label.text = str(broken)
