extends Node2D
## Live dungeon runner: builds rooms from handcrafted templates, spawns the
## hired hero and enemies, handles doors, boss fights, hero switching (final
## dungeon) and returning loot to the shop.

var world_id: String
var hero: CombatHero
var layout: Array[Dictionary] = []
var room_index: int = 0
var room_root: Node2D
var camera: Camera2D
var hud_layer: CanvasLayer
var hp_bar: Range
var meter_cards: Array = []  # 3 reload-card TextureProgressBars (or 1 fallback bar)
var boss_bar: Range
var loot_label: Label
var consum_label: Label
var switch_available: Array[String] = []
var door_open: bool = false
var finished: bool = false
var shake_amount: float = 0.0
var vertical_slice_reward_spawned: bool = false
var vertical_slice_reward_collected: bool = false

const CELL := 32


func _ready() -> void:
	add_to_group("dungeon_runtime")
	world_id = String(DungeonManager.pending.get("world_id", "kingdom_hearts"))
	var w := ContentDatabase.get_world(world_id)
	AudioManager.play_track("final_dungeon" if bool(w.get("final", false)) else "dungeon_%s" % world_id)
	layout = DungeonManager.generate_layout(world_id, -1, bool(DungeonManager.pending.get("vertical_slice", false)))
	if bool(w.get("final", false)):
		for wid in ContentDatabase.world_order:
			var ww := ContentDatabase.get_world(wid)
			if not bool(ww.get("final", false)) and BridgeManager.is_repaired(wid):
				switch_available.append(String(ww.get("hero", "")))
	room_root = Node2D.new()
	add_child(room_root)
	_spawn_hero(String(DungeonManager.pending.get("hero_id", "sora")))
	camera = Camera2D.new()
	camera.add_to_group("shake_camera")
	camera.set_script(preload("res://scripts/dungeon/shake_camera.gd"))
	hero.add_child(camera)
	_build_hud()
	_enter_room(0)


func dev_select_hero(hero_id: String) -> bool:
	if ContentDatabase.get_hero(hero_id).is_empty():
		return false
	_spawn_hero(hero_id)
	return true


func dev_spawn_enemy(enemy_id: String, at: Vector2) -> Enemy:
	if ContentDatabase.get_enemy(enemy_id).is_empty() or hero == null:
		return null
	var mob := Enemy.new()
	room_root.add_child(mob)
	mob.setup(enemy_id, hero)
	mob.global_position = at
	mob.add_to_group("dev_editable")
	mob.set_meta("dev_object_type", "enemy")
	mob.set_meta("dev_content_id", enemy_id)
	return mob


func _spawn_hero(hero_id: String) -> void:
	var consumables: Array = DungeonManager.pending.get("consumables", [])
	var old_pos := Vector2.ZERO
	var old_meter := 0.0
	if hero != null:
		old_pos = hero.global_position
		old_meter = hero.meter
		consumables = hero.consumables
		if camera != null:
			hero.remove_child(camera)
		hero.queue_free()
	hero = CombatHero.new()
	add_child(hero)
	hero.setup(hero_id, consumables)
	if get_node_or_null("PatchSidekick") == null:
		var patch := PatchFollower.attach(self, hero)
		patch.name = "PatchSidekick"
	else:
		(get_node("PatchSidekick") as PatchFollower).target = hero
	hero.meter = old_meter
	if old_pos != Vector2.ZERO:
		hero.global_position = old_pos
	if camera != null and camera.get_parent() == null:
		hero.add_child(camera)
	hero.defeated.connect(_on_hero_defeated)
	if hp_bar != null:
		hero.hp_changed.connect(_on_hp_changed)
		hero.meter_changed.connect(_set_meter_display)
		hero.consumables_changed.connect(_on_consumables_changed)
		_on_hp_changed(hero.health.hp, hero.health.max_hp)
		_on_consumables_changed(hero.consumables)


## Chain-of-Memories labeled HP bar (green fill / red boss over the dark
## empty bar) when the ripped art is present, plain ProgressBar otherwise.
static func _hud_bar(kind: String, min_size: Vector2, fallback_tint: Color) -> Range:
	var fill := "res://assets/shared/ui/hud/bar_%s.png" % kind
	const UNDER := "res://assets/shared/ui/hud/bar_under.png"
	if ResourceLoader.exists(fill) and ResourceLoader.exists(UNDER):
		var tb := TextureProgressBar.new()
		tb.texture_under = load(UNDER)
		tb.texture_progress = load(fill)
		tb.nine_patch_stretch = true
		tb.stretch_margin_left = 4
		# the HP tag cap lives in the right margin so it never stretches
		tb.stretch_margin_right = 26
		tb.stretch_margin_top = 3
		tb.stretch_margin_bottom = 3
		tb.custom_minimum_size = min_size
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return tb
	var pb := ProgressBar.new()
	pb.custom_minimum_size = min_size
	pb.show_percentage = false
	pb.modulate = fallback_tint
	return pb


## The power-up meter: three CoM reload cards that fill pink one by one.
func _build_meter_cards(row: HBoxContainer) -> void:
	const FULL := "res://assets/shared/ui/hud/card_full.png"
	const EMPTY := "res://assets/shared/ui/hud/card_empty.png"
	meter_cards.clear()
	if ResourceLoader.exists(FULL) and ResourceLoader.exists(EMPTY):
		for i in 3:
			var card := TextureProgressBar.new()
			card.texture_under = load(EMPTY)
			card.texture_progress = load(FULL)
			card.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
			card.max_value = 100
			card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(card)
			meter_cards.append(card)
	else:
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(70, 12)
		pb.show_percentage = false
		pb.modulate = Color(0.5, 0.7, 1.0)
		pb.max_value = _meter_max()
		row.add_child(pb)
		meter_cards.append(pb)


func _meter_max() -> float:
	return float(ContentDatabase.bal("dungeon", {}).get("meter_max", 100))


func _set_meter_display(v: float) -> void:
	if meter_cards.size() == 1 and meter_cards[0] is ProgressBar:
		(meter_cards[0] as ProgressBar).value = v
		return
	var per := _meter_max() / maxf(1.0, float(meter_cards.size()))
	for i in meter_cards.size():
		(meter_cards[i] as TextureProgressBar).value = clampf((v - i * per) / per * 100.0, 0.0, 100.0)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	# the same white ornate panel as the rest of the menus, slimmed down to
	# a single row
	var panel := UIKit.ornate_panel()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var slim: StyleBox = panel.get_theme_stylebox("panel").duplicate()
	slim.content_margin_top = 4
	slim.content_margin_bottom = 4
	slim.content_margin_left = 48
	slim.content_margin_right = 48
	panel.add_theme_stylebox_override("panel", slim)
	hud_layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	panel.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var hero_def := ContentDatabase.get_hero(String(DungeonManager.pending.get("hero_id", "")))
	row.add_child(UIKit.label("%s @ %s" % [String(hero_def.get("name", "?")), String(ContentDatabase.get_world(world_id).get("location", world_id))], 9, UIKit.COL_ACCENT))
	hp_bar = _hud_bar("hp", Vector2(130, 16), Color(0.9, 0.4, 0.4))
	row.add_child(hp_bar)
	_build_meter_cards(row)
	loot_label = UIKit.label("", 8, UIKit.COL_DIM)
	row.add_child(loot_label)
	consum_label = UIKit.label("", 8, UIKit.COL_DIM)
	consum_label.clip_text = true
	consum_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(consum_label)
	var hints := "A attack  X special  B dodge  Y item  RB finisher" if UIKit.pad_connected() \
		else "J attack K special L dodge I item U finisher"
	row.add_child(UIKit.label(hints, 8, UIKit.COL_DIM))
	boss_bar = _hud_bar("boss", Vector2(0, 16), Color(0.8, 0.3, 0.5))
	boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_bar.visible = false
	vb.add_child(boss_bar)
	hero.hp_changed.connect(_on_hp_changed)
	hero.meter_changed.connect(_set_meter_display)
	hero.consumables_changed.connect(_on_consumables_changed)
	_on_hp_changed(hero.health.hp, hero.health.max_hp)
	_on_consumables_changed(hero.consumables)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp


func _on_consumables_changed(items: Array) -> void:
	var names: Array[String] = []
	for id in items:
		names.append(ContentDatabase.item_name(String(id)))
	consum_label.text = "Items: " + (", ".join(names) if not names.is_empty() else "none")


func _process(_delta: float) -> void:
	var total := 0
	for id: String in DungeonManager.run_loot:
		total += int(DungeonManager.run_loot[id])
	loot_label.text = "Loot: %d items, %dg | Room %d/%d" % [total, DungeonManager.run_gold, room_index + 1, layout.size()]
	if door_open and hero != null and hero.global_position.y < 30.0:
		_next_room()


func _enter_room(idx: int) -> void:
	room_index = idx
	door_open = false
	vertical_slice_reward_spawned = false
	vertical_slice_reward_collected = false
	for child in room_root.get_children():
		child.queue_free()
	var entry: Dictionary = layout[idx]
	var template: Dictionary = entry["template"]
	var w := ContentDatabase.get_world(world_id)
	var grid := ContentDatabase.room_grid
	# floor: worlds with supplied tile art get it (tinted to their palette);
	# everything else keeps the flat data-driven color
	var floor_rect := Rect2(0, 0, grid.x * CELL, grid.y * CELL)
	# worlds with painted room art (map crops sized to the room grid) use it;
	# KH gets its tiled cobble; everything else keeps the flat color
	var bg_cfg: Dictionary = w.get("room_backgrounds", {})
	var bg_list: Array = bg_cfg.get(String(entry.get("kind", "combat")), bg_cfg.get("combat", []))
	var bg_done := false
	if not bg_list.is_empty():
		var bg_path := String(bg_list[idx % bg_list.size()])
		if ResourceLoader.exists(bg_path):
			var bg := Sprite2D.new()
			bg.texture = load(bg_path)
			bg.position = floor_rect.get_center()
			bg.z_index = -10
			room_root.add_child(bg)
			bg_done = true
	if not bg_done and world_id == "kingdom_hearts":
		Scenery.tiled_floor(room_root, floor_rect, "floor_cobble", Color(String(w.get("floor_color", "#333344"))), -10, Color(0.62, 0.62, 0.85))
	elif not bg_done:
		Scenery.tiled_floor(room_root, floor_rect, "", Color(String(w.get("floor_color", "#333344"))), -10)
	# perimeter walls (gap at top center = exit door)
	_wall(Rect2(-16, -16, grid.x * CELL / 2.0 - CELL, grid.y * 0 + 16 + 16), w)   # top-left
	_wall(Rect2(grid.x * CELL / 2.0 + CELL, -16, grid.x * CELL / 2.0 - CELL + 16, 32), w)  # top-right
	_wall(Rect2(-16, -16, 16, grid.y * CELL + 32), w)
	_wall(Rect2(grid.x * CELL, -16, 16, grid.y * CELL + 32), w)
	_wall(Rect2(-16, grid.y * CELL, grid.x * CELL + 32, 16), w)
	# door blocker until room cleared
	var blocker := StaticBody2D.new()
	blocker.name = "DoorBlocker"
	blocker.collision_layer = 1
	var bshape := CollisionShape2D.new()
	var brect := RectangleShape2D.new()
	brect.size = Vector2(CELL * 2, 32)
	bshape.shape = brect
	blocker.add_child(bshape)
	blocker.position = Vector2(grid.x * CELL / 2.0, 0)
	var bpoly := Polygon2D.new()
	bpoly.polygon = PackedVector2Array([Vector2(-CELL, -16), Vector2(CELL, -16), Vector2(CELL, 16), Vector2(-CELL, 16)])
	bpoly.color = Color(String(w.get("accent_color", "#888888"))).darkened(0.3)
	blocker.add_child(bpoly)
	room_root.add_child(blocker)
	# obstacles
	for ob in template.get("obstacles", []):
		var r := Rect2(float(ob[0]) * CELL, float(ob[1]) * CELL, float(ob[2]) * CELL, float(ob[3]) * CELL)
		_wall(r, w, true)
	# cosmetic props (lamps, barrels...) dress the room corners in worlds
	# that define them
	var props: Array = w.get("room_props", [])
	if not props.is_empty():
		var prop_n := 0
		for s: Vector2i in [Vector2i(2, 2), Vector2i(17, 2), Vector2i(2, 9), Vector2i(17, 9)]:
			var blocked := false
			for ob in template.get("obstacles", []):
				if s.x >= int(ob[0]) - 1 and s.x <= int(ob[0]) + int(ob[2]) \
						and s.y >= int(ob[1]) - 1 and s.y <= int(ob[1]) + int(ob[3]):
					blocked = true
					break
			if blocked:
				continue
			var prop_tex := Scenery.texture_or_null(String(props[(idx + prop_n) % props.size()]))
			prop_n += 1
			if prop_tex == null:
				continue
			var prop := Sprite2D.new()
			prop.texture = prop_tex
			var pk := minf(1.0, 44.0 / prop_tex.get_height())
			prop.scale = Vector2(pk, pk)
			prop.position = Vector2(s.x * CELL + CELL / 2.0,
				(s.y + 1) * CELL - prop_tex.get_height() * pk / 2.0)
			prop.z_index = -1
			room_root.add_child(prop)
	# player spawn
	var ps: Array = template.get("player_spawn", [10, 6])
	hero.global_position = Vector2(float(ps[0]) * CELL + CELL / 2.0, float(ps[1]) * CELL + CELL / 2.0)
	# chests
	for ch in template.get("chests", []):
		_spawn_chest(Vector2(float(ch[0]) * CELL + CELL / 2.0, float(ch[1]) * CELL + CELL / 2.0))
	# enemies
	var kind := String(entry["kind"])
	var spawn_cells: Array = template.get("spawns", [])
	var enemies: Array = entry["enemies"]
	if kind == "boss":
		# boss rooms keep the dungeon's own track — the sudden music switch
		# felt jarring mid-delve
		var boss := Boss.new()
		room_root.add_child(boss)
		boss.setup(String(enemies[0]), hero)
		var bs: Array = spawn_cells[0] if not spawn_cells.is_empty() else [10, 3]
		boss.global_position = Vector2(float(bs[0]) * CELL + CELL / 2.0, float(bs[1]) * CELL + CELL / 2.0)
		boss_bar.visible = true
		boss_bar.max_value = boss.health.max_hp
		boss_bar.value = boss.health.max_hp
		boss.boss_hp_changed.connect(func(hp: int, _mx: int) -> void: boss_bar.value = hp)
		boss.killed.connect(func(_id: String, _at: Vector2) -> void:
			AudioManager.play_sfx("boss_Defeated", 2.0)
			_on_room_cleared(true))
	else:
		for i in range(enemies.size()):
			var e := Enemy.new()
			room_root.add_child(e)
			e.setup(String(enemies[i]), hero)
			var sc: Array = spawn_cells[i % maxi(1, spawn_cells.size())] if not spawn_cells.is_empty() else [10, 3]
			e.global_position = Vector2(float(sc[0]) * CELL + CELL / 2.0, float(sc[1]) * CELL + CELL / 2.0)
			e.killed.connect(_on_enemy_killed)
		if enemies.is_empty():
			_on_room_cleared(false)
	# hero switch pads in final dungeon rooms
	if not switch_available.is_empty() and kind != "boss":
		_spawn_switch_pad(Vector2(CELL * 1.5, CELL * 1.5))


func _wall(r: Rect2, w: Dictionary, obstacle: bool = false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	var poly := Polygon2D.new()
	var h := r.size / 2.0
	poly.polygon = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
	poly.color = Color(String(w.get("wall_color", "#222233"))) if not obstacle else Color(String(w.get("wall_color", "#222233"))).lightened(0.15)
	# worlds with a supplied blocker texture (map-cut hedge) draw solid
	# nine-patched blocks instead of flat polygons — much clearer walls
	var ob_tex_path := String(w.get("obstacle_texture", ""))
	if ob_tex_path != "" and ResourceLoader.exists(ob_tex_path):
		var ob_tex: Texture2D = load(ob_tex_path)
		if String(w.get("obstacle_style", "ninepatch")) == "grid":
			# fill the rect with whole copies of the texture (crate piles) —
			# nine-patching a cluster leaves broken slivers at the seams
			var cols := maxi(1, int(round(r.size.x / 32.0)))
			var rows := maxi(1, int(round(r.size.y / 32.0)))
			var cw := r.size.x / cols
			var chh := r.size.y / rows
			for gy in rows:
				for gx in cols:
					var spr := Sprite2D.new()
					spr.texture = ob_tex
					spr.scale = Vector2(cw / ob_tex.get_width(), chh / ob_tex.get_height())
					spr.position = Vector2(-r.size.x / 2.0 + (gx + 0.5) * cw,
						-r.size.y / 2.0 + (gy + 0.5) * chh)
					body.add_child(spr)
		else:
			var patch := NinePatchRect.new()
			patch.texture = ob_tex
			var m := mini(10, int(minf(r.size.x, r.size.y) / 3.0))
			patch.patch_margin_left = m
			patch.patch_margin_right = m
			patch.patch_margin_top = m
			patch.patch_margin_bottom = m
			# tile the interior — stretching smears the hedge into streaks
			# on long thin wall rects
			patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
			patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
			patch.size = r.size
			patch.position = -r.size / 2.0
			body.add_child(patch)
	else:
		body.add_child(poly)
	room_root.add_child(body)


func _spawn_chest(at: Vector2) -> void:
	var chest := Area2D.new()
	chest.position = at
	chest.collision_layer = 0
	chest.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 16)
	shape.shape = rect
	chest.add_child(shape)
	var spr := Sprite2D.new()
	var chest_tex := Scenery.texture_or_null("chest")
	spr.texture = chest_tex if chest_tex != null else PlaceholderFactory.furniture_texture("case", 18, 14)
	chest.add_child(spr)
	chest.body_entered.connect(func(body: Node) -> void:
		if not (body is CombatHero):
			return
		var goods: Array = ContentDatabase.get_world(world_id).get("market_goods", [])
		var pool: Array = goods if not goods.is_empty() else ContentDatabase.live_items
		var prize := ContentDatabase.live_substitute(String(pool[randi() % pool.size()]))
		AudioManager.play_sfx("chest_unlock")
		DungeonManager.add_run_loot(prize)
		DungeonManager.run_gold += 20 + randi() % 60
		FX.burst(room_root, chest.position, Color(1, 0.9, 0.4), 16)
		chest.queue_free())
	room_root.add_child(chest)


func _spawn_switch_pad(at: Vector2) -> void:
	var pad := Area2D.new()
	pad.position = at
	pad.collision_layer = 0
	pad.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	pad.add_child(shape)
	var spr := Sprite2D.new()
	var pad_tex := Scenery.texture_or_null("save_point")
	spr.texture = pad_tex if pad_tex != null else PlaceholderFactory.flat_texture(Color(0.4, 0.9, 1.0, 0.7), 24, 24)
	pad.add_child(spr)
	var lbl := UIKit.label("SAVE POINT: switch hero [%s]" % UIKit.interact_key(), 8, UIKit.COL_ACCENT)
	lbl.position = Vector2(-46, -34)
	pad.add_child(lbl)
	var inside := {"v": false}
	pad.body_entered.connect(func(b: Node) -> void:
		if b is CombatHero:
			inside["v"] = true)
	pad.body_exited.connect(func(b: Node) -> void:
		if b is CombatHero:
			inside["v"] = false)
	pad.set_process(true)
	var checker := Timer.new()
	checker.wait_time = 0.1
	checker.autostart = true
	checker.timeout.connect(func() -> void:
		if inside["v"] and Input.is_action_just_pressed("interact"):
			_open_switch_menu())
	pad.add_child(checker)
	room_root.add_child(pad)


func _open_switch_menu() -> void:
	get_tree().paused = true
	var parts := UIKit.modal(self, "Switch hero")
	var switch_layer: CanvasLayer = parts[0]
	switch_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var vb: VBoxContainer = parts[1]
	for hid in switch_available:
		if hid == hero.hero_id:
			continue
		var stats := InventoryManager.hero_stats(hid)
		vb.add_child(UIKit.button("%s (HP %d ATK %d)" % [String(ContentDatabase.get_hero(hid).get("name", hid)), int(stats["hp"]), int(stats["atk"])], func() -> void:
			get_tree().paused = false
			switch_layer.queue_free()
			DungeonManager.pending["hero_id"] = hid
			_spawn_hero(hid)))
	vb.add_child(UIKit.button("Cancel", func() -> void:
		get_tree().paused = false
		switch_layer.queue_free()))


func _check_room_clear() -> void:
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("enemies").is_empty():
		if vertical_slice_reward_spawned and not vertical_slice_reward_collected:
			return
		_on_room_cleared(false)


func _on_enemy_killed(enemy_id: String, at: Vector2) -> void:
	hero.on_enemy_killed()
	var cfg: Dictionary = ContentDatabase.bal("kingdom_hearts_vertical_slice", {})
	if (
		bool(DungeonManager.pending.get("vertical_slice", false))
		and enemy_id == String(cfg.get("enemy_id", ""))
		and not vertical_slice_reward_spawned
	):
		_spawn_vertical_slice_reward(String(cfg.get("reward_item_id", "")), at)
	_check_room_clear()


func _spawn_vertical_slice_reward(item_id: String, at: Vector2) -> void:
	if ContentDatabase.get_item(item_id).is_empty():
		push_warning("[Dungeon] vertical-slice reward item is missing")
		return
	vertical_slice_reward_spawned = true
	call_deferred("_add_vertical_slice_reward", item_id, at)


func _add_vertical_slice_reward(item_id: String, at: Vector2) -> void:
	if finished or room_root == null:
		return
	var pickup := LootPickup.new()
	room_root.add_child(pickup)
	pickup.setup_item(item_id)
	pickup.global_position = at
	pickup.collected.connect(_on_vertical_slice_reward_collected, CONNECT_ONE_SHOT)
	var hint := UIKit.label("%s - walk over it to collect" % ContentDatabase.item_name(item_id).to_upper(), 9, UIKit.COL_GOOD)
	hint.position = Vector2(-76, -38)
	pickup.add_child(hint)


func _on_vertical_slice_reward_collected(_item_id: String, _gold_amount: int) -> void:
	vertical_slice_reward_collected = true
	_check_room_clear()


func _on_room_cleared(was_boss: bool) -> void:
	if finished:
		return
	if was_boss:
		AudioManager.play_stinger("victory_stinger")
		FX.shake(8.0)
		_finish(true, true)
		return
	door_open = true
	var blocker := room_root.get_node_or_null("DoorBlocker")
	if blocker != null:
		blocker.queue_free()
	var hint := UIKit.label("Room clear! Head through the top door.", 9, UIKit.COL_GOOD)
	hint.position = Vector2(ContentDatabase.room_grid.x * CELL / 2.0 - 80, 40)
	room_root.add_child(hint)


func _next_room() -> void:
	if room_index + 1 < layout.size():
		_enter_room(room_index + 1)
	else:
		_finish(true, false)


func _on_hero_defeated() -> void:
	if finished:
		return
	AudioManager.play_stinger("failure_stinger")
	_finish(false, false)


func _finish(success: bool, boss_defeated: bool) -> void:
	finished = true
	var result := DungeonManager.finish_expedition(success, boss_defeated, hero.health.hp if hero != null else 0)
	var parts := UIKit.modal(self, "Expedition %s" % ("complete!" if success else "failed..."))
	var end_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	if boss_defeated and world_id != "null_archive":
		vb.add_child(UIKit.label("WORLD SHARD RECOVERED!", 12, UIKit.COL_GOOD))
	if boss_defeated and world_id == "null_archive":
		vb.add_child(UIKit.label("The Fade has stopped fighting...", 12, UIKit.COL_ACCENT))
	var loot: Dictionary = result["loot"]
	var lines: Array[String] = []
	for id: String in loot:
		lines.append("%s x%d" % [ContentDatabase.item_name(id), int(loot[id])])
	vb.add_child(UIKit.label("Loot: " + (", ".join(lines) if not lines.is_empty() else "nothing"), 9))
	vb.add_child(UIKit.label("Gold found: %dg" % int(result["gold"]), 9, UIKit.COL_ACCENT))
	if not success:
		vb.add_child(UIKit.label("The hero retreated. Loot was kept; the shard was not reached.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Return to the Crossroads", func() -> void:
		end_layer.queue_free()
		if StoryEventManager.has_pending():
			SceneRouter.go("story", {"return_to": "town"})
		else:
			SceneRouter.go("town")))
