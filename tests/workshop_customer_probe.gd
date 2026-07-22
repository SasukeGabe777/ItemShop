extends Node
## Headless proof for the expanded, economically viable workshop and the
## one-visual/one-customer franchise pool.

var failures: Array[String] = []


func _ready() -> void:
	_check_workshop_economy()
	await _check_workshop_transaction()
	_check_customer_pool()
	if failures.is_empty():
		print("WORKSHOP_CUSTOMER_PROBE_PASS")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_workshop_economy() -> void:
	check(ContentDatabase.recipes.size() >= 95,
		"workshop has too few recipes: %d" % ContentDatabase.recipes.size())
	var used_inputs: Dictionary = {}
	var used_by_world: Dictionary = {}
	for recipe: Dictionary in ContentDatabase.recipes.values():
		var output_id := String(recipe.get("output", ""))
		var output := ContentDatabase.get_item(output_id)
		check(not output.is_empty(), "recipe output is missing: %s" % output_id)
		var materials_value := 0
		for item_id: String in recipe.get("inputs", {}):
			var item := ContentDatabase.get_item(item_id)
			check(not item.is_empty(), "recipe input is missing: %s" % item_id)
			var quantity := int(recipe["inputs"][item_id])
			check(quantity > 0, "recipe has a non-positive input count: %s" % recipe.get("id", ""))
			materials_value += int(item.get("price", 0)) * quantity
			used_inputs[item_id] = true
			var world := String(item.get("world", ""))
			if not used_by_world.has(world):
				used_by_world[world] = {}
			used_by_world[world][item_id] = true
		var fee := int(recipe.get("fee", 0))
		var output_value := int(output.get("price", 0)) * int(recipe.get("count", 1))
		var return_ratio := float(output_value) / float(materials_value + fee)
		check(fee >= 0, "recipe fee is negative: %s" % recipe.get("id", ""))
		check(return_ratio >= 1.03 and return_ratio <= 1.35,
			"recipe value is not viable: %s ratio %.2f" % [recipe.get("id", ""), return_ratio])
	check(used_inputs.size() >= 95, "too few distinct workshop materials: %d" % used_inputs.size())
	var minimums := {
		"kingdom_hearts": 12, "mario": 18, "final_fantasy": 9, "zelda": 8,
		"naruto": 8, "dragon_ball": 10, "pokemon": 20,
	}
	for world: String in minimums:
		var used: Dictionary = used_by_world.get(world, {})
		check(used.size() >= int(minimums[world]),
			"%s workshop variety is too low: %d" % [world, used.size()])
	var one_up := ContentDatabase.get_recipe("r_one_up")
	check(int(one_up.get("fee", 0)) > 100, "1-Up still uses the placeholder 100g fee")
	check(int(one_up.get("inputs", {}).get("super_mushroom", 0)) == 3,
		"1-Up recipe no longer communicates its three-mushroom upgrade")


func _check_workshop_transaction() -> void:
	InventoryManager.reset()
	EconomyManager.reset()
	EconomyManager.gold = 9999
	TimeManager.reset(2)
	var recipe := ContentDatabase.get_recipe("r_one_up")
	InventoryManager.add_item("super_mushroom", 3)
	var before_gold := EconomyManager.gold
	var panel := WorkshopPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var all_text := ""
	for label in panel.find_children("*", "Label", true, false):
		all_text += (label as Label).text + "\n"
	check("Workshop fee" in all_text and "craft gain" in all_text and "owned" in all_text,
		"workshop rows do not clearly explain ingredients, fee, and value")
	panel._craft("r_one_up")
	check(InventoryManager.count("super_mushroom") == 0, "craft did not consume all three mushrooms")
	check(InventoryManager.count(String(recipe["output"])) == int(recipe.get("count", 1)),
		"craft did not award the declared output")
	check(EconomyManager.gold == before_gold - int(recipe["fee"]), "craft did not charge its shown fee")
	panel.queue_free()
	await get_tree().process_frame


func _check_customer_pool() -> void:
	var counts: Dictionary = {}
	var slugs: Dictionary = {}
	var names: Dictionary = {}
	var static_paths: Dictionary = {}
	var pokemon_entries: Dictionary = {}
	for entry: Dictionary in ContentDatabase.customer_visual_pool:
		var world := String(entry.get("world", ""))
		var slug := String(entry.get("slug", ""))
		var display_name := String(entry.get("name", ""))
		var static_path := String(entry.get("static", ""))
		var scoped_slug := "%s:%s" % [world, slug]
		counts[world] = int(counts.get(world, 0)) + 1
		check(slug != "" and not slugs.has(scoped_slug), "customer identity is missing or repeated: %s" % scoped_slug)
		check(display_name != "" and not names.has(display_name),
			"customer name is missing or assigned to multiple identities: %s" % display_name)
		check(static_path != "" and not static_paths.has(static_path),
			"customer sprite is missing or reused: %s" % static_path)
		slugs[scoped_slug] = true
		names[display_name] = true
		static_paths[static_path] = true
		check(ResourceLoader.exists(static_path), "customer sprite was not imported: %s" % static_path)
		check(load(static_path) is Texture2D, "customer sprite is not a texture: %s" % static_path)
		if world == "pokemon":
			pokemon_entries[slug] = entry
			var manifest_path := String(entry.get("manifest", ""))
			check(manifest_path != "" and FileAccess.file_exists(manifest_path),
				"Pokémon has no animation manifest: %s" % slug)
			var frames := SpriteFramesBuilder.from_manifest_path(manifest_path)
			check(frames != null, "Pokémon animation manifest did not build: %s" % slug)
			if frames != null:
				for animation in ["walk_up", "walk_down", "walk_left", "walk_right"]:
					check(frames.has_animation(animation), "%s is missing %s" % [slug, animation])
					if frames.has_animation(animation):
						check(frames.get_frame_count(animation) == 2,
							"%s %s does not use both supplied walk frames" % [slug, animation])
	var targets := {
		"dragon_ball": 50, "kingdom_hearts": 50, "mario": 50,
		"naruto": 50, "pokemon": 151, "zelda": 50,
	}
	for world: String in targets:
		check(int(counts.get(world, 0)) >= int(targets[world]),
			"%s customer pool is too small: %d" % [world, counts.get(world, 0)])
	check(int(counts.get("final_fantasy", 0)) == 33,
		"Final Fantasy Record Keeper archive was expanded instead of remaining curated")
	check(int(counts.get("pokemon", 0)) == 151,
		"Kanto pool should contain each named species exactly once")
	var expected_names := {
		"bulbasaur": "Bulbasaur", "charmander": "Charmander", "abra": "Abra",
		"kabuto": "Kabuto", "dragonite": "Dragonite", "mewtwo": "Mewtwo", "mew": "Mew",
	}
	for slug: String in expected_names:
		check(pokemon_entries.has(slug), "corrected Pokédex entry is missing: %s" % slug)
		if pokemon_entries.has(slug):
			check(String(pokemon_entries[slug].get("name", "")) == String(expected_names[slug]),
				"Pokédex name mismatch for %s" % slug)
	check(not pokemon_entries.has("aipom"), "legacy non-Kanto static sprite leaked into the Kanto pool")
	_check_pokemon_runtime_directions(pokemon_entries)


func _check_pokemon_runtime_directions(pokemon_entries: Dictionary) -> void:
	var sample: Dictionary = pokemon_entries.get("bulbasaur", {})
	check(not sample.is_empty(), "Bulbasaur is unavailable for the runtime animation check")
	if sample.is_empty():
		return
	var visual := CharacterVisual.new()
	add_child(visual)
	var manifest_path := String(sample.get("manifest", ""))
	check(visual.setup_from_manifest(manifest_path), "runtime visual could not load a Pokémon manifest")
	if visual.use_frames:
		var directions := {
			Vector2.UP: "walk_up",
			Vector2.DOWN: "walk_down",
			Vector2.LEFT: "walk_left",
			Vector2.RIGHT: "walk_right",
		}
		for direction: Vector2 in directions:
			visual.face(direction, true)
			check(String(visual.animated.animation) == String(directions[direction]),
				"runtime visual did not select %s" % directions[direction])
	visual.free()


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("WORKSHOP_CUSTOMER_PROBE_FAIL: " + message)
