extends Node
## Force-loads every .gd script in the project so parser errors surface, then
## instantiates each main scene once.

var failures: Array[String] = []


func _ready() -> void:
	_scan("res://autoload")
	_scan("res://scripts")
	_scan("res://tools/sprite_importer")
	for scene_path in ["res://scenes/ui/main_menu.tscn", "res://scenes/town/town.tscn",
			"res://scenes/shop/shop.tscn", "res://scenes/dungeon/dungeon.tscn",
			"res://scenes/story/story_player.tscn", "res://tools/sprite_importer/sprite_importer.tscn"]:
		var packed: Variant = load(scene_path)
		if packed == null or not (packed is PackedScene):
			failures.append("cannot load scene %s" % scene_path)
			continue
		if not (packed as PackedScene).can_instantiate():
			failures.append("cannot instantiate %s" % scene_path)
	if failures.is_empty():
		print("PARSE_TEST_PASS")
	else:
		for f_msg in failures:
			printerr("PARSE_TEST_FAIL: " + f_msg)
	get_tree().quit(0 if failures.is_empty() else 1)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir() and not entry.begins_with("."):
			_scan(full)
		elif entry.ends_with(".gd"):
			var script: Variant = load(full)
			if script == null:
				failures.append("parse error in %s" % full)
			elif script is GDScript and not (script as GDScript).can_instantiate():
				# tool/abstract scripts may not instantiate; reload to check compile
				var err := (script as GDScript).reload()
				if err != OK:
					failures.append("compile error in %s" % full)
		entry = dir.get_next()
