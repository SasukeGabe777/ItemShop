@tool
extends EditorPlugin
## Docks the Crossroads Asset Factory (formerly Content Studio) into the
## editor's bottom panel. Enabling it never touches autoloads or scenes; the
## factory tabs write to data/*.json and processed asset folders only when
## you explicitly save something.

const MainPanelScript := preload("res://addons/crossroads_content_studio/ui/main_panel.gd")

var panel: Control


func _enter_tree() -> void:
	panel = MainPanelScript.new()
	panel.name = "CrossroadsAssetFactory"
	add_control_to_bottom_panel(panel, "Crossroads Asset Factory")


func _exit_tree() -> void:
	if panel != null:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null
