extends Node
## Windowed proof of clear workshop economics and the expanded customer pool.

class Probe:
	extends Node

	const SHOT_DIR := "user://screenshots/workshop_customer_overhaul/"
	const EXPANDED_WORLDS := [
		"dragon_ball", "kingdom_hearts", "mario", "naruto", "pokemon", "zelda",
	]

	func _ready() -> void:
		await get_tree().create_timer(0.7).timeout
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		GameState.reset_campaign()
		InventoryManager.reset()
		EconomyManager.reset()
		EconomyManager.gold = 99999
		for recipe: Dictionary in ContentDatabase.recipes.values():
			for item_id: String in recipe.get("inputs", {}):
				InventoryManager.add_item(item_id, 20)
		TimeManager.reset(2)
		var workshop := WorkshopPanel.new()
		get_tree().current_scene.add_child(workshop)
		await get_tree().create_timer(0.35).timeout
		_snap("01_workshop_chapter_2_clear_costs.png")
		var scrolls := workshop.find_children("*", "ScrollContainer", true, false)
		if not scrolls.is_empty():
			(scrolls[0] as ScrollContainer).scroll_vertical = 100000
		await get_tree().create_timer(0.25).timeout
		_snap("02_workshop_later_recipe_variety.png")
		workshop.queue_free()
		await get_tree().process_frame

		var overview := _build_overview()
		get_tree().current_scene.add_child(overview)
		await get_tree().create_timer(0.25).timeout
		_snap("03_expanded_world_customer_counts.png")
		overview.queue_free()
		await get_tree().process_frame

		var pokemon := _build_pokemon_page()
		get_tree().current_scene.add_child(pokemon)
		await get_tree().create_timer(0.25).timeout
		_snap("04_updated_pokemon_customer_samples.png")
		pokemon.queue_free()
		await get_tree().process_frame

		var directions := _build_pokemon_directions()
		get_tree().current_scene.add_child(directions)
		await get_tree().create_timer(0.25).timeout
		_snap("05_pokemon_four_direction_animations.png")
		print("WORKSHOP_CUSTOMER_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
		get_tree().quit()


	func _snap(filename: String) -> void:
		get_viewport().get_texture().get_image().save_png(SHOT_DIR + filename)


	func _base_panel(title: String) -> Array:
		var layer := CanvasLayer.new()
		layer.layer = 80
		var backdrop := ColorRect.new()
		backdrop.color = Color("#111625")
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(backdrop)
		var panel := PanelContainer.new()
		panel.position = Vector2(12, 10)
		panel.size = Vector2(616, 340)
		backdrop.add_child(panel)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		panel.add_child(vb)
		var heading := UIKit.label(title, 14, Color.WHITE)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(heading)
		return [layer, vb]


	func _entries_for(world: String) -> Array:
		return ContentDatabase.customer_visual_pool.filter(func(entry: Dictionary) -> bool:
			return String(entry.get("world", "")) == world)


	func _portrait(entry: Dictionary, show_name: bool = false) -> Control:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(54, 36 if not show_name else 52)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var texture := TextureRect.new()
		texture.custom_minimum_size = Vector2(32, 30)
		texture.texture = load(String(entry.get("static", "")))
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(texture)
		if show_name:
			var label := UIKit.label(String(entry.get("name", "")), 6, Color("#dfe8ff"))
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(label)
		return box


	func _build_overview() -> CanvasLayer:
		var parts := _base_panel("Expanded customer pool — one visual identity per customer")
		var layer: CanvasLayer = parts[0]
		var vb: VBoxContainer = parts[1]
		for world: String in EXPANDED_WORLDS:
			var entries := _entries_for(world)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			var world_label := UIKit.label("%s\n%d customers" % [world.replace("_", " ").capitalize(), entries.size()], 8, UIKit.COL_ACCENT)
			world_label.custom_minimum_size = Vector2(110, 38)
			row.add_child(world_label)
			for i in range(8):
				var index := int(floor(float(i) * float(entries.size()) / 8.0))
				row.add_child(_portrait(entries[mini(index, entries.size() - 1)]))
			vb.add_child(row)
		return layer


	func _build_pokemon_page() -> CanvasLayer:
		var entries := _entries_for("pokemon")
		var parts := _base_panel("Kanto Pokémon — National Pokédex names corrected")
		var layer: CanvasLayer = parts[0]
		var vb: VBoxContainer = parts[1]
		var grid := GridContainer.new()
		grid.columns = 10
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 3)
		for i in range(mini(50, entries.size())):
			grid.add_child(_portrait(entries[i], true))
		vb.add_child(grid)
		return layer


	func _build_pokemon_directions() -> CanvasLayer:
		var entries := _entries_for("pokemon")
		var by_slug: Dictionary = {}
		for entry: Dictionary in entries:
			by_slug[String(entry.get("slug", ""))] = entry
		var parts := _base_panel("Every Pokémon uses both walk frames in all four directions")
		var layer: CanvasLayer = parts[0]
		var vb: VBoxContainer = parts[1]
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 2)
		for heading in ["Pokémon", "Up", "Down", "Left", "Right"]:
			var label := UIKit.label(heading, 8, UIKit.COL_ACCENT)
			label.custom_minimum_size = Vector2(88, 18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(label)
		for slug in ["bulbasaur", "charmander", "pikachu", "abra", "gengar", "dragonite", "mewtwo", "mew"]:
			var entry: Dictionary = by_slug[slug]
			var name_label := UIKit.label(String(entry.get("name", slug)), 8, Color.WHITE)
			name_label.custom_minimum_size = Vector2(88, 34)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(name_label)
			var frames := SpriteFramesBuilder.from_manifest_path(String(entry.get("manifest", "")))
			for animation in ["walk_up", "walk_down", "walk_left", "walk_right"]:
				var texture := TextureRect.new()
				texture.custom_minimum_size = Vector2(88, 34)
				texture.texture = frames.get_frame_texture(animation, 0)
				texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				grid.add_child(texture)
		vb.add_child(grid)
		return layer


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Probe.new())
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
