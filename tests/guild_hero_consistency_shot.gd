extends Node
## Windowed lineup using the exact texture path and square presentation rule
## used by Adventurers' Guild profiles.

const SHOT_DIR := "user://screenshots/guild_hero_consistency/"


func _ready() -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var guild := GuildPanel.new()
	var parts := UIKit.modal(self, "Adventurers' Guild — Default Idle Lineup")
	var root: VBoxContainer = parts[1]
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	root.add_child(grid)
	var hero_ids: Array = ContentDatabase.heroes.keys()
	hero_ids.sort()
	for raw_id in hero_ids:
		var hero_id := String(raw_id)
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 100
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		var art := TextureRect.new()
		art.texture = guild._hero_texture(hero_id)
		art.custom_minimum_size = Vector2(96, 96)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		card.add_child(art)
		var name := UIKit.label(String(ContentDatabase.get_hero(hero_id).get("name", hero_id)), 8)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name)
		grid.add_child(card)
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + "01_all_guild_default_idles.png")
	var lineup_layer: CanvasLayer = parts[0]
	lineup_layer.queue_free()
	await get_tree().process_frame
	var actual_guild := GuildPanel.new()
	add_child(actual_guild)
	await get_tree().process_frame
	actual_guild._show_hero("sora")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + "02_actual_guild_sora.png")
	actual_guild._show_hero("charmander")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + "03_actual_guild_charmander.png")
	print("GUILD_HERO_CONSISTENCY_SHOT_DONE folder=", ProjectSettings.globalize_path(SHOT_DIR))
	guild.free()
	get_tree().quit()
