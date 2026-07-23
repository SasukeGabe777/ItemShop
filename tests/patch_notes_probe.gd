extends Node
## Logic + windowed visual proof for the dated title-screen patch notes.

const SHOT_DIR := "user://screenshots/patch_notes/"


class Probe:
	extends Node

	func _ready() -> void:
		MultiplayerState.set_enabled(false)
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		await get_tree().create_timer(1.2).timeout
		var menu := get_tree().current_scene
		var notes_button := _find_button(menu, "PATCH NOTES")
		var failures: Array[String] = []
		if notes_button == null:
			failures.append("PATCH NOTES button missing from title screen")
		var releases: Array = menu.call("_load_patch_notes")
		if releases.size() != 8:
			failures.append("expected 8 dated releases, got %d" % releases.size())
		elif String(releases[0].get("date", "")) != "July 22, 2026" \
				or String(releases[-1].get("date", "")) != "July 15, 2026":
			failures.append("release dates are missing or not newest-first")
		var windowed := DisplayServer.get_name() != "headless"
		if windowed:
			DirAccess.make_dir_recursive_absolute(SHOT_DIR)
			get_viewport().get_texture().get_image().save_png(
				SHOT_DIR + "01_title_button.png")
		if notes_button != null:
			notes_button.pressed.emit()
		await get_tree().create_timer(0.6).timeout
		var scrolls := menu.find_children("*", "ScrollContainer", true, false)
		if scrolls.size() != 1:
			failures.append("expected one patch-notes scroll view, got %d" % scrolls.size())
		var all_text := _collect_label_text(menu)
		for expected in ["July 22, 2026", "Pokemon world", "July 15, 2026", "project foundation"]:
			if expected.to_lower() not in all_text.to_lower():
				failures.append("missing visible patch-note text: %s" % expected)
		if windowed:
			get_viewport().get_texture().get_image().save_png(
				SHOT_DIR + "02_newest_notes.png")
		if not scrolls.is_empty():
			var scroll := scrolls[0] as ScrollContainer
			scroll.scroll_vertical = 100000
			await get_tree().create_timer(0.4).timeout
			if scroll.scroll_vertical <= 0:
				failures.append("patch notes did not scroll")
			if windowed:
				get_viewport().get_texture().get_image().save_png(
					SHOT_DIR + "03_oldest_notes.png")
		if failures.is_empty():
			print("PATCH_NOTES_PROBE PASS releases=", releases.size(),
				" folder=", ProjectSettings.globalize_path(SHOT_DIR))
		else:
			for failure in failures:
				print("PATCH_NOTES_PROBE FAIL: ", failure)
		get_tree().quit(0 if failures.is_empty() else 1)

	func _find_button(root: Node, text: String) -> Button:
		for node in root.find_children("*", "Button", true, false):
			if (node as Button).text == text:
				return node as Button
		return null

	func _collect_label_text(root: Node) -> String:
		var lines: Array[String] = []
		for node in root.find_children("*", "Label", true, false):
			lines.append((node as Label).text)
		return "\n".join(lines)


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
