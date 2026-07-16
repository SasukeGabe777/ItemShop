@tool
class_name LocationWorkshopBridge
extends RefCounted
## Tiny editor-to-runtime handoff for PLAY THIS LOCATION. The editor writes a
## development-only request under user://; the dev location scene consumes it.
## Normal saves and project settings are never touched.

const LAUNCH_REQUEST_PATH := "user://crossroads_dev/location_workshop_launch.json"


static func prepare_launch(location_id: String) -> bool:
	var id := location_id.strip_edges()
	if id == "":
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LAUNCH_REQUEST_PATH.get_base_dir()))
	var file := FileAccess.open(LAUNCH_REQUEST_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"schema": "crossroads.location_workshop_launch.v1",
		"location_id": id,
		"created_at": Time.get_datetime_string_from_system(),
	}, "  ") + "\n")
	return true


static func consume_launch() -> String:
	if not FileAccess.file_exists(LAUNCH_REQUEST_PATH):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.open(LAUNCH_REQUEST_PATH, FileAccess.READ).get_as_text())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LAUNCH_REQUEST_PATH))
	if not (parsed is Dictionary):
		return ""
	return String((parsed as Dictionary).get("location_id", ""))


static func clear_launch() -> void:
	if FileAccess.file_exists(LAUNCH_REQUEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LAUNCH_REQUEST_PATH))
