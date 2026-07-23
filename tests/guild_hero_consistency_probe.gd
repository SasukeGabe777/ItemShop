extends Node
## Headless proof that every guild portrait has a forward idle source and is
## cropped to visible bounds for equal square-box presentation.

var failures: Array[String] = []


func _ready() -> void:
	var guild := GuildPanel.new()
	_check(GuildPanel.GUILD_IDLE_FRAME_OVERRIDES.get("charmander", -1) == 3,
		"Charmander Guild portrait is not using its forward default pose")
	_check(GuildPanel.GUILD_IDLE_FRAME_OVERRIDES.get("sora", -1) == 56,
		"Sora Guild portrait is not using its neutral default pose")
	var checked := 0
	var smallest_edge := INF
	var largest_edge := 0.0
	for hero_id: String in ContentDatabase.heroes:
		var hero: Dictionary = ContentDatabase.get_hero(hero_id)
		var world := String(hero.get("world", "crossroads"))
		var frames := SpriteFramesBuilder.from_manifest_path(
			"res://assets/franchises/%s/manifests/%s.json" % [world, hero_id])
		_check(frames != null, "%s has no guild-readable hero manifest" % hero_id)
		if frames == null:
			continue
		_check(frames.has_animation("idle_down"), "%s lacks the canonical idle_down pose" % hero_id)
		_check(frames.get_frame_count("idle_down") > 0, "%s idle_down pose has no frames" % hero_id)
		var texture := guild._hero_texture(hero_id)
		_check(texture != null, "%s guild portrait has no texture" % hero_id)
		if texture == null:
			continue
		var image := texture.get_image()
		var used := image.get_used_rect()
		_check(used.position == Vector2i.ZERO and used.size == image.get_size(),
			"%s guild portrait still includes transparent frame padding" % hero_id)
		var source_edge := maxf(float(texture.get_width()), float(texture.get_height()))
		smallest_edge = minf(smallest_edge, source_edge)
		largest_edge = maxf(largest_edge, source_edge)
		# KEEP_ASPECT_CENTERED inside the square portrait makes the longest visible
		# edge exactly 110px for every non-empty cropped idle pose.
		var rendered_edge := source_edge * minf(110.0 / texture.get_width(), 110.0 / texture.get_height())
		_check(is_equal_approx(rendered_edge, 110.0),
			"%s guild portrait does not normalize to the 110px box" % hero_id)
		checked += 1
	guild.free()
	_check(checked == ContentDatabase.heroes.size(),
		"checked %d guild heroes, expected %d" % [checked, ContentDatabase.heroes.size()])
	print("GUILD_HERO_IDLE_SOURCE_RANGE min=", smallest_edge, " max=", largest_edge,
		" rendered=110 heroes=", checked)
	if failures.is_empty():
		print("GUILD_HERO_CONSISTENCY_PROBE_PASS")
	else:
		for message in failures:
			printerr("GUILD_HERO_CONSISTENCY_PROBE_FAIL: " + message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
