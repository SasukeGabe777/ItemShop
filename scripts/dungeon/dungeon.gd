extends Node2D
## Live dungeon runner: builds rooms from handcrafted templates, spawns the
## hired hero and enemies, handles doors, boss fights, hero switching (final
## dungeon) and returning loot to the shop.

var world_id: String
var hero: CombatHero
var hero2: CombatHero = null  # split-screen partner (shared camera, pad 2)
var hp_bar2: Range = null
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
var consum_label2: Label = null
var hud_vb: VBoxContainer = null
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
	var hero2_id := String(DungeonManager.pending.get("hero2_id", ""))
	if MultiplayerState.enabled and hero2_id != "" and not ContentDatabase.get_hero(hero2_id).is_empty():
		hero2 = CombatHero.new()
		add_child(hero2)
		hero2.input_prefix = "p2_"
		hero2.setup(hero2_id, DungeonManager.pending.get("consumables2", []))
		hero2.modulate = Color(1.0, 0.9, 0.85)
		hero2.defeated.connect(_on_hero_defeated)
	camera = Camera2D.new()
	if hero2 != null:
		# co-op: a free-standing midpoint camera showing the whole room,
		# zoom-adjustable by Player 1 only
		camera.set_script(preload("res://scripts/dungeon/coop_camera.gd"))
		camera.set("hero_a", hero)
		camera.set("hero_b", hero2)
		add_child(camera)
		camera.make_current()
	else:
		camera.add_to_group("shake_camera")
		camera.set_script(preload("res://scripts/dungeon/shake_camera.gd"))
		# clamp to the room rect: following the hero to a wall used to pan half
		# the screen into the void beyond the painted background
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = ContentDatabase.room_grid.x * CELL
		camera.limit_bottom = ContentDatabase.room_grid.y * CELL
		hero.add_child(camera)
	_build_hud()
	if hero2 != null and hp_bar != null:
		hp_bar2 = _hp_display(Vector2(110, 16), Color("#4a9a55"))
		hp_bar2.max_value = hero2.health.max_hp
		hp_bar2.value = hero2.health.hp
		var bar_row := hp_bar.get_parent()
		bar_row.add_child(hp_bar2)
		bar_row.move_child(hp_bar2, hp_bar.get_index() + 1)
		hero2.hp_changed.connect(func(hp: int, max_hp: int) -> void:
			hp_bar2.max_value = max_hp
			hp_bar2.value = hp)
		# P2 gets their own special-attack reload cards next to their HP
		var m2 := HBoxContainer.new()
		m2.add_theme_constant_override("separation", 2)
		bar_row.add_child(m2)
		bar_row.move_child(m2, hp_bar2.get_index() + 1)
		var meter_cards2: Array = []
		_build_meter_cards_into(m2, meter_cards2)
		_set_meter_cards(meter_cards2, hero2.meter)
		hero2.meter_changed.connect(func(v: float) -> void: _set_meter_cards(meter_cards2, v))
		# P2 packs their own items, so they get their own readout
		consum_label2 = UIKit.label("", 8, UIKit.COL_DIM)
		consum_label2.clip_text = true
		consum_label2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 14)
		hud_vb.add_child(item_row)
		hud_vb.move_child(item_row, boss_bar.get_index())
		consum_label.get_parent().remove_child(consum_label)
		item_row.add_child(consum_label)
		item_row.add_child(consum_label2)
		hero2.consumables_changed.connect(_on_consumables2_changed)
		_on_consumables2_changed(hero2.consumables)
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


## Per-world HP display: worlds.json "hud" can theme it to the source game —
## {"hp_style": "hearts", "heart_full/half/empty": paths} draws a HeartBar
## (Minish Cap hearts in Hyrule); {"hp_style": "bar", "bar_fill/under": paths}
## uses that game's bar art (CoM battle bar in Traverse Town). Anything else
## falls back to the shared ornate bar.
func _hp_display(min_size: Vector2, fallback_tint: Color) -> Range:
	var hud_cfg: Dictionary = ContentDatabase.get_world(world_id).get("hud", {})
	var style := String(hud_cfg.get("hp_style", ""))
	if style == "hearts":
		var full := _tex_if_exists(String(hud_cfg.get("heart_full", "")))
		if full != null:
			var hb := HeartBar.new()
			hb.setup(full,
				_tex_if_exists(String(hud_cfg.get("heart_half", ""))),
				_tex_if_exists(String(hud_cfg.get("heart_empty", ""))))
			hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			return hb
	elif style == "bar":
		var fill := _tex_if_exists(String(hud_cfg.get("bar_fill", "")))
		var under := _tex_if_exists(String(hud_cfg.get("bar_under", "")))
		if fill != null and under != null:
			var tb := TextureProgressBar.new()
			tb.texture_under = under
			tb.texture_progress = fill
			tb.nine_patch_stretch = true
			var m: Array = hud_cfg.get("bar_margins", [4, 3, 4, 3])
			tb.stretch_margin_left = int(m[0])
			tb.stretch_margin_top = int(m[1])
			tb.stretch_margin_right = int(m[2])
			tb.stretch_margin_bottom = int(m[3])
			tb.custom_minimum_size = min_size
			tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			return tb
	return _hud_bar("hp", min_size, fallback_tint)


static func _tex_if_exists(path: String) -> Texture2D:
	return load(path) if path != "" and ResourceLoader.exists(path) else null


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
	_build_meter_cards_into(row, meter_cards)


func _build_meter_cards_into(row: HBoxContainer, cards: Array) -> void:
	const FULL := "res://assets/shared/ui/hud/card_full.png"
	const EMPTY := "res://assets/shared/ui/hud/card_empty.png"
	cards.clear()
	if ResourceLoader.exists(FULL) and ResourceLoader.exists(EMPTY):
		for i in 3:
			var card := TextureProgressBar.new()
			card.texture_under = load(EMPTY)
			card.texture_progress = load(FULL)
			card.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
			card.max_value = 100
			card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(card)
			cards.append(card)
	else:
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(70, 12)
		pb.show_percentage = false
		pb.modulate = Color(0.5, 0.7, 1.0)
		pb.max_value = _meter_max()
		row.add_child(pb)
		cards.append(pb)


func _meter_max() -> float:
	return float(ContentDatabase.bal("dungeon", {}).get("meter_max", 100))


func _set_meter_display(v: float) -> void:
	_set_meter_cards(meter_cards, v)


func _set_meter_cards(cards: Array, v: float) -> void:
	if cards.size() == 1 and cards[0] is ProgressBar:
		(cards[0] as ProgressBar).value = v
		return
	var per := _meter_max() / maxf(1.0, float(cards.size()))
	for i in cards.size():
		(cards[i] as TextureProgressBar).value = clampf((v - i * per) / per * 100.0, 0.0, 100.0)


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
	hud_vb = vb
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var hero_def := ContentDatabase.get_hero(String(DungeonManager.pending.get("hero_id", "")))
	row.add_child(UIKit.label("%s @ %s" % [String(hero_def.get("name", "?")), String(ContentDatabase.get_world(world_id).get("location", world_id))], 9, UIKit.COL_ACCENT))
	hp_bar = _hp_display(Vector2(130, 16), Color(0.9, 0.4, 0.4))
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


## "Items: Hi-Potion (heals 100), Ether (+30 meter)" — the next item to be used
## is first, so a player can see what Y will actually do before pressing it.
static func _consumable_text(items: Array, prefix: String) -> String:
	var names: Array[String] = []
	for id in items:
		var nm := ContentDatabase.item_name(String(id))
		var fx := ContentDatabase.item_effect_summary(String(id))
		names.append("%s (%s)" % [nm, fx] if fx != "" else nm)
	return prefix + (", ".join(names) if not names.is_empty() else "none")


func _on_consumables_changed(items: Array) -> void:
	consum_label.text = _consumable_text(items, "Items: ")


func _on_consumables2_changed(items: Array) -> void:
	if consum_label2 != null:
		consum_label2.text = _consumable_text(items, "P2: ")


var _pause_was_down := false


func _process(_delta: float) -> void:
	# own edge detection: is_action_just_pressed's frame stamp misses
	# presses injected by probes via Input.action_press
	var pause_down := Input.is_action_pressed("pause_menu")
	if pause_down and not _pause_was_down and not finished and not UIKit.modal_open():
		_open_pause_menu()
	_pause_was_down = pause_down
	var total := 0
	for id: String in DungeonManager.run_loot:
		total += int(DungeonManager.run_loot[id])
	loot_label.text = "Loot: %d items, %dg | Room %d/%d" % [total, DungeonManager.run_gold, room_index + 1, layout.size()]
	if door_open and hero != null and (hero.global_position.y < 30.0
			or (hero2 != null and is_instance_valid(hero2) and hero2.global_position.y < 30.0)):
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
	# door blocker until room cleared: a barricade of the world's props where
	# prop art exists (flat accent rect only as fallback)
	var blocker := StaticBody2D.new()
	blocker.name = "DoorBlocker"
	blocker.collision_layer = 1
	var bshape := CollisionShape2D.new()
	var brect := RectangleShape2D.new()
	brect.size = Vector2(CELL * 2, 32)
	bshape.shape = brect
	blocker.add_child(bshape)
	blocker.position = Vector2(grid.x * CELL / 2.0, 0)
	if not _stamp_props(blocker, brect.size, w):
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
	# player spawn (nudged off obstacle cells — templates and defaults could
	# drop heroes on top of a hedge/crate, standing "in" the collider)
	var ps: Array = template.get("player_spawn", [10, 6])
	var pcell := _free_cell(Vector2i(int(ps[0]), int(ps[1])), template)
	hero.global_position = _cell_center(pcell)
	if hero2 != null and is_instance_valid(hero2):
		hero2.global_position = _cell_center(_free_cell(pcell + Vector2i(1, 0), template)) + Vector2(-10, 0)
	# chests
	for ch in template.get("chests", []):
		_spawn_chest(_cell_center(_free_cell(Vector2i(int(ch[0]), int(ch[1])), template)))
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
		boss.global_position = _cell_center(_free_cell(Vector2i(int(bs[0]), int(bs[1])), template))
		boss_bar.visible = true
		boss_bar.max_value = boss.health.max_hp
		boss_bar.value = boss.health.max_hp
		boss.boss_hp_changed.connect(func(hp: int, _mx: int) -> void: boss_bar.value = hp)
		boss.killed.connect(func(_id: String, _at: Vector2) -> void:
			DungeonManager.run_kills += 1
			AudioManager.play_sfx("boss_Defeated", 2.0)
			_on_room_cleared(true))
	else:
		for i in range(enemies.size()):
			var e := Enemy.new()
			room_root.add_child(e)
			e.setup(String(enemies[i]), hero)
			var sc: Array = spawn_cells[i % maxi(1, spawn_cells.size())] if not spawn_cells.is_empty() else [10, 3]
			e.global_position = _cell_center(_free_cell(Vector2i(int(sc[0]), int(sc[1])), template))
			e.killed.connect(_on_enemy_killed)
		if enemies.is_empty():
			_on_room_cleared(false)
	# hero switch pads in final dungeon rooms
	if not switch_available.is_empty() and kind != "boss":
		_spawn_switch_pad(_cell_center(_free_cell(Vector2i(1, 1), template)))


func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)


## Nearest cell to `pref` that is inside the walkable interior and not covered
## by an obstacle rect. Templates (and the [10, 6] default) can put spawns on
## top of obstacles, which visually strands heroes/chests "in" the collider.
func _free_cell(pref: Vector2i, template: Dictionary) -> Vector2i:
	var grid := ContentDatabase.room_grid
	var obs: Array = template.get("obstacles", [])
	var blocked := func(c: Vector2i) -> bool:
		if c.x < 1 or c.y < 1 or c.x > grid.x - 2 or c.y > grid.y - 2:
			return true
		for ob in obs:
			if c.x >= int(ob[0]) and c.x < int(ob[0]) + int(ob[2]) \
					and c.y >= int(ob[1]) and c.y < int(ob[1]) + int(ob[3]):
				return true
		return false
	if not blocked.call(pref):
		return pref
	for radius in range(1, 10):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := pref + Vector2i(dx, dy)
				if not blocked.call(c):
					return c
	return pref


func _wall(r: Rect2, w: Dictionary, obstacle: bool = false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# interior obstacles draw as spaced rocks/props with transparent gaps; inset
	# their collision so you collide with the visible cores, not the empty air
	# between them. Perimeter walls stay full-size.
	rect.size = r.size * (0.8 if obstacle else 1.0)
	shape.shape = rect
	body.add_child(shape)
	# interior obstacles in worlds with prop art get one UNSCALED keyed object
	# per 32px cell (variant + jitter from a stable cell hash) so they read as
	# placed objects on the painted rooms; stretching a map-crop tile over the
	# rect smeared it and dragged its baked-in ground along ("messy walls"
	# feedback). Perimeter walls are never textured — flat wall_color only.
	if not (obstacle and _stamp_props(body, r.size, w, r.position)):
		var poly := Polygon2D.new()
		var h := r.size / 2.0
		poly.polygon = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
		poly.color = Color(String(w.get("wall_color", "#222233"))) if not obstacle else Color(String(w.get("wall_color", "#222233"))).lightened(0.15)
		body.add_child(poly)
	room_root.add_child(body)


## Stamp real-game art across a rect centered on `parent`'s origin. Two modes:
## - `barriers` (worlds.json: {"h": [paths], "v": [paths]}): continuous wall
##   RUNS — the strip texture repeats along the rect at native scale, the way
##   the source games draw impassable borders (fences, hedges, cliffs,
##   palisades). Repeating clean keyed strips is safe; the old "messy walls"
##   smear came from STRETCHING map crops with baked-in ground. Tall wall
##   textures keep their decorative top edge and may overhang the rect top by
##   up to 16px, like real wall art does.
## - `obstacle_props` fallback: scattered objects (variant + jitter from a
##   stable cell hash, bottom-aligned).
## Returns false when the world has neither so callers fall back to flat fill.
func _stamp_props(parent: Node2D, size: Vector2, w: Dictionary, hash_seed: Vector2 = Vector2.ZERO) -> bool:
	var barriers: Dictionary = w.get("barriers", {})
	if not barriers.is_empty():
		var vertical := size.y > size.x and not (barriers.get("v", []) as Array).is_empty()
		var variants: Array = barriers.get("v", []) if vertical else barriers.get("h", [])
		var strips: Array[Texture2D] = []
		for p in variants:
			var sp := String(p)
			if ResourceLoader.exists(sp):
				strips.append(load(sp))
		if not strips.is_empty():
			# one variant per rect (a run is one kind of wall, not a medley)
			var tex := strips[hash(hash_seed) % strips.size()]
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			spr.region_enabled = true
			if vertical:
				var draw_w := maxf(size.x, minf(tex.get_width(), size.x + 16.0))
				spr.region_rect = Rect2(0, 0, draw_w, size.y)
				spr.position = Vector2(0, 0)
			else:
				# cover the whole rect: shorter textures 2D-tile (hedge/fence
				# blocks); taller ones keep their crown and overhang above the
				# rect by up to 32px, bottom-aligned, like real wall art
				var draw_h := maxf(size.y, minf(tex.get_height(), size.y + 32.0))
				spr.region_rect = Rect2(0, 0, size.x, draw_h)
				spr.position = Vector2(0, size.y / 2.0 - draw_h / 2.0)
			parent.add_child(spr)
			return true
	var textures: Array[Texture2D] = []
	for p in w.get("obstacle_props", []):
		var pp := String(p)
		if ResourceLoader.exists(pp):
			textures.append(load(pp))
	if textures.is_empty():
		return false
	var cols := maxi(1, int(round(size.x / 32.0)))
	var rows := maxi(1, int(round(size.y / 32.0)))
	var cw := size.x / cols
	var chh := size.y / rows
	for gy in rows:
		for gx in cols:
			# stable per-cell hash: same room layout -> same props, but
			# neighboring cells vary
			var hv := hash(Vector2(hash_seed.x + gx * 31.0, hash_seed.y + gy * 37.0))
			var tex := textures[hv % textures.size()]
			var spr := Sprite2D.new()
			spr.texture = tex
			# bottom-aligned in its cell, tiny jitter so rows don't stamp
			spr.position = Vector2(
				-size.x / 2.0 + (gx + 0.5) * cw + float((hv >> 3) % 5) - 2.0,
				-size.y / 2.0 + (gy + 1) * chh - tex.get_height() / 2.0)
			parent.add_child(spr)
	return true


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
		if inside["v"] and Input.is_action_just_pressed("interact") and not UIKit.modal_open():
			_open_switch_menu())
	pad.add_child(checker)
	room_root.add_child(pad)


# Escape (or pad Start) pauses the run with a retreat option (polled in
# _process — synthetic probe input and the rest of the codebase use the
# Input singleton, which never reaches _unhandled_input). The day cost was
# already paid at expedition launch (gates panel), so leaving early keeps
# the loot and the spent time — same as a defeat retreat, minus the stinger.
func _open_pause_menu() -> void:
	get_tree().paused = true
	var parts := UIKit.modal(self, "Paused")
	var pause_layer: CanvasLayer = parts[0]
	pause_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var vb: VBoxContainer = parts[1]
	vb.add_child(UIKit.label("Retreating keeps your loot; the shard stays unreached.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Retreat to the Crossroads", func() -> void:
		get_tree().paused = false
		pause_layer.queue_free()
		_finish(false, false)))
	vb.add_child(UIKit.button("Keep exploring", func() -> void:
		get_tree().paused = false
		pause_layer.queue_free()))


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
	DungeonManager.run_kills += 1
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
	# co-op: the run only ends when BOTH heroes are down
	var someone_up := (hero != null and is_instance_valid(hero) and not hero.health.dead) \
		or (hero2 != null and is_instance_valid(hero2) and not hero2.health.dead)
	if someone_up:
		var note := UIKit.label("A hero is down! Finish the fight!", 10, UIKit.COL_BAD)
		note.position = Vector2(ContentDatabase.room_grid.x * CELL / 2.0 - 80, 56)
		note.z_index = 70
		room_root.add_child(note)
		var tw := note.create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(note, "modulate:a", 0.0, 0.5)
		tw.tween_callback(note.queue_free)
		return
	AudioManager.play_stinger("failure_stinger")
	_finish(false, false)


func _finish(success: bool, boss_defeated: bool) -> void:
	finished = true
	var hp_left := hero.health.hp if hero != null else 0
	if hero2 != null and is_instance_valid(hero2):
		hp_left = maxi(hp_left, hero2.health.hp)
	var result := DungeonManager.finish_expedition(success, boss_defeated, hp_left)
	var parts := UIKit.modal(self, "Expedition %s" % ("complete!" if success else "failed..."))
	var end_layer: CanvasLayer = parts[0]
	var vb: VBoxContainer = parts[1]
	(vb.get_parent() as PanelContainer).custom_minimum_size = Vector2(430, 0)
	if boss_defeated and world_id != "null_archive":
		vb.add_child(UIKit.label("WORLD SHARD RECOVERED!", 14, UIKit.COL_GOOD))
	if boss_defeated and world_id == "null_archive":
		vb.add_child(UIKit.label("The Fade has stopped fighting...", 14, UIKit.COL_ACCENT))
	# expedition ledger, mirroring the shop's end-of-day summary
	vb.add_child(UIKit.label("Gold found: %dg   Enemies defeated: %d" % [
		int(result["gold"]), int(result.get("kills", 0))], 11, UIKit.COL_ACCENT))
	var loot: Dictionary = result["loot"]
	if loot.is_empty():
		vb.add_child(UIKit.label("Loot: nothing this time", 9, UIKit.COL_DIM))
	else:
		vb.add_child(UIKit.label("Loot brought home:", 9))
		for id: String in loot:
			vb.add_child(UIKit.label("  x%d %s — worth ~%dg" % [
				int(loot[id]), ContentDatabase.item_name(id), MarketManager.market_value(id) * int(loot[id])], 9))
	if hero != null:
		vb.add_child(UIKit.label("Hero HP left: %d" % int(result.get("hp_left", 0)), 9, UIKit.COL_DIM))
	if not success:
		vb.add_child(UIKit.label("The hero retreated. Loot was kept; the shard was not reached.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.hsep())
	var status := DayTransition.fade_status()
	if status != null:
		vb.add_child(status)
	vb.add_child(UIKit.button("Return to the Crossroads", func() -> void:
		end_layer.queue_free()
		if StoryEventManager.has_pending():
			SceneRouter.go("story", {"return_to": "town"})
		else:
			SceneRouter.go("town")))
