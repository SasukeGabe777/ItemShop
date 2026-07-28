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
var door_blocker: StaticBody2D = null
var room_clear_banner: Control = null
var finished: bool = false
## Authority countdown after a non-boss room opens. Walking through the door
## still advances immediately; this fallback prevents a party from becoming
## trapped by collision, replication, or an unreachable doorway.
var _room_clear_auto_advance_left: float = -1.0
var _room_transition_pending: bool = false
## Authority-side: this combat room spawned enemies and hasn't cleared yet.
## Room-clear is polled from live Enemy children tagged for the current room,
## so stale/group-external nodes cannot hold a door shut and spawn-on-death
## enemies (splitters) still count.
var _room_needs_clear: bool = false
var _room_epoch: int = 0
var shake_amount: float = 0.0
var _net_hero_puppets: Dictionary = {}  # online: player_index -> CombatHero puppet

const CELL := 32
const HUD_SAFE_TOP := 72.0
const ROOM_CLEAR_AUTO_ADVANCE_SECONDS := 10.0
## The top perimeter pieces occupy y=-16..16. All actors stay on the room
## side of that inner edge; only heroes inside the open 2-cell north doorway
## may enter the gap far enough to trigger the next room.
const TOP_WALL_INNER_Y := 16.0
const HERO_BOUND_RADIUS := 7.0
## Below the wall's inner edge, so standing against a closed door cannot
## auto-advance the instant it opens; the hero must enter the doorway gap.
const EXIT_TRIGGER_Y := 16.0


func _ready() -> void:
	add_to_group("dungeon_runtime")
	# Run containment after default-priority actor physics and puppet smoothing.
	# This is a hard simulation boundary behind the regular wall collisions:
	# dash/knockback/teleport overshoot and bad replicated positions cannot
	# leave an actor outside the authored room.
	process_priority = 100
	world_id = String(DungeonManager.pending.get("world_id", "kingdom_hearts"))
	var w := ContentDatabase.get_world(world_id)
	AudioManager.play_track("final_dungeon" if bool(w.get("final", false)) else "dungeon_%s" % world_id)
	# online: the host rolled layout_seed at depart so every machine builds
	# identical rooms; offline keeps the free -1 roll
	layout = DungeonManager.generate_layout(world_id,
		int(DungeonManager.pending.get("layout_seed", -1)),
		bool(DungeonManager.pending.get("vertical_slice", false)))
	if bool(w.get("final", false)):
		for wid in ContentDatabase.world_order:
			var ww := ContentDatabase.get_world(wid)
			if not bool(ww.get("final", false)) and BridgeManager.is_repaired(wid):
				switch_available.append(String(ww.get("hero", "")))
	room_root = Node2D.new()
	add_child(room_root)
	room_root.child_entered_tree.connect(_on_room_child_entered)
	var start_hero := String(DungeonManager.pending.get("hero_id", "sora"))
	if Net.is_online():
		var mine := _party_entry(PartyState.local_index())
		if not mine.is_empty():
			start_hero = String(mine.get("hero_id", start_hero))
			DungeonManager.pending["consumables"] = \
				(mine.get("consumables", []) as Array).duplicate()
	_spawn_hero(start_hero)
	var hero2_id := String(DungeonManager.pending.get("hero2_id", ""))
	if MultiplayerState.enabled and hero2_id != "" and not ContentDatabase.get_hero(hero2_id).is_empty():
		hero2 = CombatHero.new()
		add_child(hero2)
		hero2.input_prefix = "p2_"
		hero2.setup(hero2_id, DungeonManager.pending.get("consumables2", []))
		hero2.modulate = Color(1.0, 0.9, 0.85)
		var p2_label := UIKit.floating_name(hero2, hero2.visual, "P2", 4.0, 12, Color("#8fd8ff"))
		p2_label.name = "PlayerIdentityLabel"
		var p2_sidekick := PatchFollower.attach_p2(self, hero2)
		p2_sidekick.name = "P2Sidekick"
		hero2.defeated.connect(_on_hero_defeated)
	camera = Camera2D.new()
	camera.set_script(preload("res://scripts/dungeon/room_camera.gd"))
	camera.set("safe_top", HUD_SAFE_TOP)
	add_child(camera)
	camera.make_current()
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
	# Online wiring must run BEFORE the first room builds: it connects the
	# scene-event handler and entity factories. Room 0 (an empty start room)
	# "clears" during _enter_room and broadcasts room_cleared — if the handler
	# weren't connected yet the host would miss its own event and the door
	# would never open (the party stuck on room 1). Puppets are positioned by
	# _enter_room right after.
	if Net.is_online():
		_setup_net_dungeon()
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
		if camera != null and camera.get_parent() == hero:
			hero.remove_child(camera)
		hero.queue_free()
	hero = CombatHero.new()
	add_child(hero)
	hero.setup(hero_id, consumables)
	if MultiplayerState.enabled:
		var p1_label := UIKit.floating_name(hero, hero.visual, "P1", 4.0, 12, Color("#ff9999"))
		p1_label.name = "PlayerIdentityLabel"
	if get_node_or_null("PatchSidekick") == null:
		var patch := PatchFollower.attach(self, hero)
		patch.name = "PatchSidekick"
	else:
		(get_node("PatchSidekick") as PatchFollower).target = hero
	hero.meter = old_meter
	if old_pos != Vector2.ZERO:
		hero.global_position = old_pos
	if camera != null and camera.get_parent() == null:
		add_child(camera)
	hero.defeated.connect(_on_hero_defeated)
	if Net.is_online():
		var idx := PartyState.local_index()
		hero.player_index = idx
		hero.modulate = PartyState.tint(idx)
		var name_label := UIKit.floating_name(hero, hero.visual, PartyState.pname(idx),
			4.0, 12, PartyState.color(idx))
		name_label.name = "PlayerIdentityLabel"
		Replica.register_local_player(idx, _local_hero_state, hero)
		hero.hp_changed.connect(func(hp: int, _max_hp: int) -> void:
			Replica.send_player_event("hp", {"hp": hp}))
	if hp_bar != null:
		hero.hp_changed.connect(_on_hp_changed)
		hero.meter_changed.connect(_set_meter_display)
		hero.consumables_changed.connect(_on_consumables_changed)
		_on_hp_changed(hero.health.hp, hero.health.max_hp)
		_on_consumables_changed(hero.consumables)


## ---- online party ------------------------------------------------------------

func _party_entry(idx: int) -> Dictionary:
	for entry in DungeonManager.pending.get("party", []):
		if int((entry as Dictionary).get("player_index", 0)) == idx:
			return entry
	return {}


func _local_hero_state() -> Array:
	if hero == null or not is_instance_valid(hero):
		return []
	# Replica runs independently of this scene's process order. Constrain at
	# the serialization boundary too, so no overshoot coordinate is ever put
	# on the wire between movement and the room's end-of-frame safety pass.
	_constrain_hero(hero)
	return [hero.global_position.x, hero.global_position.y,
		hero.velocity.x, hero.velocity.y, 0]


func _setup_net_dungeon() -> void:
	PartyState.player_left.connect(_on_net_player_left)
	Replica.register_factory("enemy", _net_spawn_enemy)
	Replica.register_factory("boss", _net_spawn_boss)
	Replica.register_factory("chest", _net_spawn_chest)
	Replica.register_factory("loot", _net_spawn_loot)
	Replica.register_factory("eproj", _net_spawn_eproj)
	Replica.entity_event.connect(_on_net_entity_event)
	Replica.entity_despawned.connect(_on_net_entity_despawned)
	Replica.remote_player_event.connect(_on_net_player_event)
	Net.scene_event.connect(_on_net_scene_event)
	var local_idx := PartyState.local_index()
	for idx in PartyState.connected_indexes():
		if idx == local_idx:
			continue
		var entry := _party_entry(idx)
		var hid := String(entry.get("hero_id",
			DungeonManager.pending.get("hero_id", "sora")))
		_make_hero_puppet(idx, hid, hero.global_position + Vector2(16 * idx, 0))


## A player dropped mid-run: despawn their hero everywhere, and let their
## leaving end a run where they were the last one standing.
func _on_net_player_left(idx: int) -> void:
	var pup: Variant = _net_hero_puppets.get(idx)
	if pup != null and is_instance_valid(pup):
		(pup as Node).queue_free()
	_net_hero_puppets.erase(idx)
	if Net.is_host() and not finished and not _someone_up():
		AudioManager.play_stinger("failure_stinger")
		_finish(false, false)


func _make_hero_puppet(idx: int, hid: String, at: Vector2) -> void:
	var old: Variant = _net_hero_puppets.get(idx)
	var pup := CombatHero.new()
	add_child(pup)
	pup.setup(hid, [])
	pup.make_puppet(idx)
	pup.modulate = PartyState.tint(idx)
	var pup_label := UIKit.floating_name(pup, pup.visual, PartyState.pname(idx),
		4.0, 12, PartyState.color(idx))
	pup_label.name = "PlayerIdentityLabel"
	pup.global_position = at
	Replica.register_player_puppet(idx, pup)
	_net_hero_puppets[idx] = pup
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()


func _net_spawn_enemy(args: Dictionary) -> Node:
	var e := Enemy.new()
	room_root.add_child(e)
	e.setup(String(args.get("id", "")), hero)
	if args.has("hp"):
		e.health.setup(int(args.get("hp", 20)))
	e.global_position = _args_pos(args)
	e.make_puppet()
	return e


func _net_spawn_boss(args: Dictionary) -> Node:
	var b := Boss.new()
	room_root.add_child(b)
	b.setup(String(args.get("id", "")), hero)
	b.global_position = _args_pos(args)
	b.make_puppet()
	boss_bar.visible = true
	boss_bar.max_value = int(args.get("max_hp", b.health.max_hp))
	boss_bar.value = boss_bar.max_value
	return b


func _net_spawn_chest(args: Dictionary) -> Node:
	var chest := Node2D.new()
	var spr := Sprite2D.new()
	var chest_tex := Scenery.texture_or_null("chest")
	spr.texture = chest_tex if chest_tex != null else PlaceholderFactory.furniture_texture("case", 18, 14)
	chest.add_child(spr)
	room_root.add_child(chest)
	chest.global_position = _args_pos(args)
	return chest


func _net_spawn_loot(args: Dictionary) -> Node:
	var pickup := LootPickup.new()
	if args.has("gold"):
		pickup.setup_gold(int(args.get("gold", 0)))
	else:
		pickup.setup_item(String(args.get("item", "")))
	pickup.set_physics_process(false)  # cosmetic: the host banks the loot
	pickup.monitoring = false
	room_root.add_child(pickup)
	pickup.global_position = _args_pos(args)
	return pickup


## Cosmetic enemy bullet: the real one flies on the host; this copy hits
## nothing (its damage is forwarded through the hero puppet path instead).
func _net_spawn_eproj(args: Dictionary) -> Node:
	var p := Projectile.new()
	var dir := _args_pos(args, "dir")
	p.setup({"damage": 0}, dir, 150.0, Color(String(args.get("color", "ffffff"))), 0)
	p.set_physics_process(false)  # the state stream drives it
	room_root.add_child(p)
	p.global_position = _args_pos(args)
	var sheet := String(args.get("sheet", ""))
	if sheet != "":
		p.set_art(sheet, int(args.get("h", 1)), int(args.get("v", 1)),
			int(args.get("row", 0)), float(args.get("fps", 12)))
	return p


static func _args_pos(args: Dictionary, key: String = "pos") -> Vector2:
	var p: Array = args.get(key, [0, 0])
	return Vector2(float(p[0]), float(p[1]))


func _on_net_entity_event(eid: int, event_name: String, args: Dictionary) -> void:
	match event_name:
		"hurt":
			var node := Replica.entity(eid)
			if node is Enemy:
				(node as Enemy).play_hurt_fx(int(args.get("dmg", 0)),
					_args_pos(args, "from"), int(args.get("hp", 0)))
		"boss_hp":
			boss_bar.value = int(args.get("hp", 0))


func _on_net_entity_despawned(_eid: int, reason: String, args: Dictionary) -> void:
	match reason:
		"death":
			var at := _args_pos(args, "at")
			FX.enemy_death(room_root, at, 1.6 if bool(args.get("boss", false)) else 1.0)
			if bool(args.get("boss", false)):
				boss_bar.visible = false
			if int(args.get("killer", 0)) == PartyState.local_index() \
					and hero != null and is_instance_valid(hero):
				hero.on_enemy_killed()
		"consumed":
			FX.burst(room_root, _args_pos(args, "at"), Color(1, 1, 0.8), 5)


func _on_net_player_event(idx: int, event_name: String, args: Dictionary) -> void:
	var pup: Variant = _net_hero_puppets.get(idx)
	var puppet: CombatHero = pup if pup != null and is_instance_valid(pup) else null
	match event_name:
		"hp":
			if puppet != null:
				puppet.mirror_health(int(args.get("hp", 0)))
			if int(args.get("hp", 0)) <= 0:
				_on_hero_defeated()
		"action":
			if puppet != null:
				puppet.puppet_replay(args)
		"hero_change":
			# setup() only works on a fresh node — rebuild the puppet
			var at := puppet.global_position if puppet != null else hero.global_position
			_make_hero_puppet(idx, String(args.get("hero_id", "")), at)


func _on_net_scene_event(event_name: String, args: Dictionary) -> void:
	match event_name:
		"enter_room":
			_enter_room(int(args.get("idx", 0)))
		"room_cleared":
			_apply_room_cleared(int(args.get("idx", room_index)))
		"expedition_finished":
			finished = true
			_show_finish_modal(bool(args.get("success", false)),
				bool(args.get("boss", false)), args.get("result", {}))


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


## Per-world boss bar: worlds.json "hud" {"boss_fill", "boss_under"} themes it
## to the source game (e.g. the DBZ black-framed red bar); else the shared bar.
func _boss_bar_display(min_size: Vector2, fallback_tint: Color) -> Range:
	var hud_cfg: Dictionary = ContentDatabase.get_world(world_id).get("hud", {})
	var fill := _tex_if_exists(String(hud_cfg.get("boss_fill", "")))
	var under := _tex_if_exists(String(hud_cfg.get("boss_under", "")))
	if fill != null and under != null:
		var tb := TextureProgressBar.new()
		tb.texture_under = under
		tb.texture_progress = fill
		tb.nine_patch_stretch = true
		var m: Array = hud_cfg.get("boss_margins", [4, 2, 4, 2])
		tb.stretch_margin_left = int(m[0])
		tb.stretch_margin_top = int(m[1])
		tb.stretch_margin_right = int(m[2])
		tb.stretch_margin_bottom = int(m[3])
		tb.custom_minimum_size = min_size
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return tb
	return _hud_bar("boss", min_size, fallback_tint)


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
	var boom_label := DungeonManager.pending_expedition_boom_label()
	if boom_label != "":
		var boom_banner := UIKit.label(boom_label, 10, UIKit.COL_GOOD)
		boom_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(boom_banner)
	boss_bar = _boss_bar_display(Vector2(0, 16), Color(0.8, 0.3, 0.5))
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


func _process(delta: float) -> void:
	_enforce_room_bounds()
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
	# authority clears a combat room the moment its enemies are all gone — this
	# catches the last kill however it happened (incl. splitter children)
	if _room_needs_clear and not door_open and not finished and Net.is_authority() \
			and _live_room_enemies().is_empty():
		_room_needs_clear = false
		_on_room_cleared(false)
	if door_open and Net.is_authority() and not _room_transition_pending:
		_room_clear_auto_advance_left = maxf(
			0.0, _room_clear_auto_advance_left - delta)
		if _any_hero_past_exit() or _room_clear_auto_advance_left <= 0.0:
			_next_room()


func _physics_process(_delta: float) -> void:
	_enforce_room_bounds()


## Belt-and-suspenders containment behind the collision walls. CharacterBody
## movement normally stops at the walls, but direct teleports, large dashes,
## knockback and network smoothing can all place a body beyond a collider.
func _enforce_room_bounds() -> void:
	if room_root == null or not is_instance_valid(room_root):
		return
	_constrain_hero(hero)
	_constrain_hero(hero2)
	for pup: Variant in _net_hero_puppets.values():
		if pup is CombatHero and is_instance_valid(pup):
			_constrain_hero(pup as CombatHero)
	for node: Node in room_root.get_children():
		if node is Enemy and is_instance_valid(node):
			_constrain_enemy(node as Enemy)


func _constrain_hero(body: CombatHero) -> void:
	if body == null or not is_instance_valid(body):
		return
	var smoother := body.get_node_or_null("PuppetSmoother") as PuppetSmoother
	var extents := _actor_room_extents(body.visual, HERO_BOUND_RADIUS)
	if smoother != null:
		smoother.constrain_target(_bounded_room_position(
			smoother.target_pos, extents, true))
	_apply_constrained_position(body, _bounded_room_position(
		body.global_position, extents, true))


func _constrain_enemy(body: Enemy) -> void:
	if body == null or not is_instance_valid(body):
		return
	# hit_radius tracks the rendered body (including large bosses), so enemies
	# cannot hide their visible/hittable body beyond a room edge.
	var radius := maxf(4.0, body.hit_radius)
	var extents := _actor_room_extents(body.visual, radius)
	var smoother := body.get_node_or_null("PuppetSmoother") as PuppetSmoother
	if smoother != null:
		smoother.constrain_target(_bounded_room_position(
			smoother.target_pos, extents, false))
	_apply_constrained_position(body, _bounded_room_position(
		body.global_position, extents, false))


func _apply_constrained_position(body: Node2D, bounded: Vector2) -> void:
	var before := body.global_position
	if before.is_equal_approx(bounded):
		return
	body.global_position = bounded
	if body is CharacterBody2D:
		var moving_body := body as CharacterBody2D
		# Do not preserve velocity into an edge: that causes repeated overshoot
		# and visible jitter while a dash or knockback is still active.
		if not is_equal_approx(before.x, bounded.x):
			moving_body.velocity.x = 0.0
		if not is_equal_approx(before.y, bounded.y):
			moving_body.velocity.y = 0.0


## left/top/right/bottom drawn extents around the feet-position origin.
func _actor_room_extents(visual: CharacterVisual, physical_radius: float) -> Vector4:
	var extents := Vector4(physical_radius, physical_radius,
		physical_radius, physical_radius)
	if visual == null or not is_instance_valid(visual):
		return extents
	var drawn := visual.drawn_bounds()
	var scale := visual.scale.abs()
	extents.x = maxf(extents.x, maxf(0.0, -drawn.position.x * scale.x))
	extents.y = maxf(extents.y, maxf(0.0, -drawn.position.y * scale.y))
	extents.z = maxf(extents.z, maxf(0.0, drawn.end.x * scale.x))
	extents.w = maxf(extents.w, maxf(0.0, drawn.end.y * scale.y))
	return extents


func _bounded_room_position(global_pos: Vector2, extents: Vector4,
		allow_open_exit: bool) -> Vector2:
	var room_size := Vector2(ContentDatabase.room_grid) * float(CELL)
	var local := room_root.to_local(global_pos)
	var max_extent := minf(room_size.x, room_size.y) * 0.25
	var left := clampf(extents.x, 1.0, max_extent)
	var top := clampf(extents.y, 1.0, max_extent)
	var right := clampf(extents.z, 1.0, max_extent)
	var bottom := clampf(extents.w, 1.0, max_extent)
	local.x = clampf(local.x, left, room_size.x - right)
	local.y = minf(local.y, room_size.y - bottom)
	var top_limit := TOP_WALL_INNER_Y + top
	if allow_open_exit and door_open \
			and _inside_exit_corridor(local.x, HERO_BOUND_RADIUS):
		# The hero's body remains inside the room rectangle while reaching the
		# y<16 transition strip; no outside-the-map travel is ever necessary.
		local.y = maxf(local.y, HERO_BOUND_RADIUS)
	else:
		local.y = maxf(local.y, top_limit)
	return room_root.to_global(local)


func _inside_exit_corridor(local_x: float, radius: float) -> bool:
	var center_x := float(ContentDatabase.room_grid.x * CELL) * 0.5
	return local_x >= center_x - CELL + radius \
		and local_x <= center_x + CELL - radius


func _hero_past_exit(body: CombatHero) -> bool:
	if body == null or not is_instance_valid(body) or not door_open:
		return false
	var local := room_root.to_local(body.global_position)
	return local.y < EXIT_TRIGGER_Y \
		and _inside_exit_corridor(local.x, HERO_BOUND_RADIUS)


## Any party hero (local, couch partner or online puppet) through the open,
## bounded top-door corridor. A stray or malformed y coordinate elsewhere can
## no longer advance the room.
func _any_hero_past_exit() -> bool:
	if _hero_past_exit(hero):
		return true
	if _hero_past_exit(hero2):
		return true
	for pup: Variant in _net_hero_puppets.values():
		if pup is CombatHero and is_instance_valid(pup) \
				and _hero_past_exit(pup as CombatHero):
			return true
	return false


func _enter_room(idx: int) -> void:
	_room_epoch += 1
	room_index = idx
	door_open = false
	door_blocker = null
	_room_clear_auto_advance_left = -1.0
	_room_transition_pending = false
	_room_needs_clear = false
	if room_clear_banner != null and is_instance_valid(room_clear_banner):
		room_clear_banner.queue_free()
	room_clear_banner = null
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
	var brect := RectangleShape2D.new()
	brect.size = Vector2(CELL * 2, 32)
	blocker.position = Vector2(grid.x * CELL / 2.0, 0)
	var blocker_stamped := _stamp_props(
		blocker, brect.size, w, Vector2.ZERO, true)
	# Barrier art adds one alpha-bounds collider per rendered block. Worlds
	# without barrier strips keep the broad fallback blocker.
	if not _has_collision_shape(blocker):
		var bshape := CollisionShape2D.new()
		bshape.shape = brect
		blocker.add_child(bshape)
	if not blocker_stamped:
		var bpoly := Polygon2D.new()
		bpoly.polygon = PackedVector2Array([Vector2(-CELL, -16), Vector2(CELL, -16), Vector2(CELL, 16), Vector2(-CELL, 16)])
		bpoly.color = Color(String(w.get("accent_color", "#888888"))).darkened(0.3)
		blocker.add_child(bpoly)
	room_root.add_child(blocker)
	door_blocker = blocker
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
	var slot := 1
	for pup: Variant in _net_hero_puppets.values():
		if pup != null and is_instance_valid(pup):
			(pup as Node2D).global_position = _cell_center(
				_free_cell(pcell + Vector2i(slot, 0), template))
			slot += 1
	# hero switch pads are local interactions — every machine builds its own
	var kind := String(entry["kind"])
	if not switch_available.is_empty() and kind != "boss":
		_spawn_switch_pad(_cell_center(_free_cell(Vector2i(1, 1), template)))
	# Rooms with nothing to fight (start / empty treasure) open their door
	# immediately, on EVERY machine — the layout is identical everywhere, so
	# clients don't have to wait on a host event they may have missed while
	# still loading into the scene.
	if kind != "boss" and (entry.get("enemies", []) as Array).is_empty():
		_apply_room_cleared()
	# chests / enemies / bosses: the host simulates them; clients receive
	# replicated puppets through their Replica factories instead
	if not Net.is_authority():
		return
	for chest_cell in _expanded_chest_cells(template):
		_spawn_chest(_cell_center(chest_cell))
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
		if Net.is_host():
			Replica.host_register(boss, "boss", {"id": String(enemies[0]),
				"pos": [boss.global_position.x, boss.global_position.y],
				"max_hp": boss.health.max_hp})
			boss.boss_hp_changed.connect(func(hp: int, _mx: int) -> void:
				Replica.host_event(boss, "boss_hp", {"hp": hp}))
	else:
		for i in range(enemies.size()):
			var e := Enemy.new()
			room_root.add_child(e)
			e.setup(String(enemies[i]), hero)
			var sc: Array = spawn_cells[i % maxi(1, spawn_cells.size())] if not spawn_cells.is_empty() else [10, 3]
			e.global_position = _cell_center(_free_cell(Vector2i(int(sc[0]), int(sc[1])), template))
			e.killed.connect(_on_enemy_killed.bind(e))
			if Net.is_host():
				Replica.host_register(e, "enemy", {"id": String(enemies[i]),
					"pos": [e.global_position.x, e.global_position.y]})
		# poll for clear off the group emptying (see _process) — robust against
		# splitters whose spawned children aren't individually wired up
		_room_needs_clear = not enemies.is_empty()
		# empty non-boss rooms already opened their door above (all machines)


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


## Treasure Surge duplicates every authored chest into a nearby free cell.
## The host alone spawns and rewards them; clients receive the normal replicas.
func _expanded_chest_cells(template: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var multiplier := maxi(1, int(round(
		DungeonManager.pending_expedition_multiplier("chest_spawn"))))
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for authored in template.get("chests", []):
		var base := _free_cell(
			Vector2i(int(authored[0]), int(authored[1])), template)
		if base not in out:
			out.append(base)
		for copy_index in range(1, multiplier):
			for offset_index in range(offsets.size()):
				var offset := offsets[(copy_index - 1 + offset_index) % offsets.size()]
				var candidate := _free_cell(base + offset, template)
				if candidate not in out:
					out.append(candidate)
					break
	return out


func _wall(r: Rect2, w: Dictionary, obstacle: bool = false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = r.position + r.size / 2.0
	# interior obstacles in worlds with prop art get one UNSCALED keyed object
	# per 32px cell (variant + jitter from a stable cell hash) so they read as
	# placed objects on the painted rooms; stretching a map-crop tile over the
	# rect smeared it and dragged its baked-in ground along ("messy walls"
	# feedback). Perimeter walls are never textured — flat wall_color only.
	var stamped := obstacle and _stamp_props(
		body, r.size, w, r.position, true)
	# Barrier strips create precise per-sprite colliders. Scattered prop and
	# flat-fill fallbacks retain the inset/full aggregate rectangle.
	if not _has_collision_shape(body):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size * (0.8 if obstacle else 1.0)
		shape.shape = rect
		body.add_child(shape)
	if not stamped:
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
func _stamp_props(parent: Node2D, size: Vector2, w: Dictionary,
		hash_seed: Vector2 = Vector2.ZERO,
		add_barrier_collision: bool = false) -> bool:
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
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			# place DISCRETE whole tiles (no region/repeat) so a run can never
			# show a spliced partial on any edge. Each tile is uniformly scaled
			# to its slot, so continuous art (hedge/fence) still abuts seamlessly
			# while spaced art (rocks) keeps its gaps.
			if vertical:
				var n := maxi(1, int(roundf(size.y / th)))
				var slot := size.y / n
				var sc := slot / th
				for i in n:
					var s := Sprite2D.new()
					s.texture = tex
					s.scale = Vector2(sc, sc)
					s.position = Vector2(0.0, -size.y / 2.0 + (i + 0.5) * slot)
					parent.add_child(s)
					if add_barrier_collision and parent is CollisionObject2D:
						_add_barrier_collision(parent as CollisionObject2D, s)
			else:
				var n := maxi(1, int(roundf(size.x / tw)))
				var slot := size.x / n
				var sc := slot / tw
				for i in n:
					var s := Sprite2D.new()
					s.texture = tex
					s.scale = Vector2(sc, sc)
					# bottom-align (tall wall crowns overhang up); square rocks read centered
					s.position = Vector2(-size.x / 2.0 + (i + 0.5) * slot, size.y / 2.0 - th * sc / 2.0)
					parent.add_child(s)
					if add_barrier_collision and parent is CollisionObject2D:
						_add_barrier_collision(parent as CollisionObject2D, s)
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


## Add a rectangle matching the sprite's non-transparent pixel bounds. Barrier
## textures are clean keyed cutouts, so this removes the invisible collision
## radius caused by using the full authored obstacle-grid rectangle.
func _add_barrier_collision(parent: CollisionObject2D, sprite: Sprite2D) -> void:
	var texture := sprite.texture
	if texture == null:
		return
	var used := Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	var image := texture.get_image()
	if image != null:
		var alpha_bounds := image.get_used_rect()
		if alpha_bounds.size != Vector2i.ZERO:
			used = alpha_bounds
	var sprite_scale := sprite.scale.abs()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(used.size) * sprite_scale
	var shape := CollisionShape2D.new()
	shape.name = "BarrierCollision"
	shape.shape = rect
	var texture_center := texture.get_size() * 0.5
	var used_center := Vector2(used.position) + Vector2(used.size) * 0.5
	shape.position = sprite.position + (used_center - texture_center) * sprite.scale
	parent.add_child(shape)


func _has_collision_shape(parent: Node) -> bool:
	for child: Node in parent.get_children():
		if child is CollisionShape2D:
			return true
	return false


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
		if Net.is_host():
			Replica.host_despawn(chest, "consumed",
				{"at": [chest.global_position.x, chest.global_position.y]})
			Net.sync_managers(["dungeon"])
		chest.queue_free())
	room_root.add_child(chest)
	if Net.is_host():
		Replica.host_register(chest, "chest", {"pos": [at.x, at.y]})


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
	Net.request_tree_pause(true)
	var parts := UIKit.modal(self, "Paused")
	var pause_layer: CanvasLayer = parts[0]
	pause_layer.process_mode = Net.pause_layer_mode()
	var vb: VBoxContainer = parts[1]
	vb.add_child(UIKit.label("Retreating keeps your loot; the shard stays unreached.", 9, UIKit.COL_DIM))
	if Net.is_online():
		vb.add_child(UIKit.label("Retreating pulls the WHOLE party out.", 9, UIKit.COL_DIM))
	vb.add_child(UIKit.button("Retreat to the Crossroads", func() -> void:
		Net.request_tree_pause(false)
		pause_layer.queue_free()
		if Net.is_client():
			Net.request("dungeon.retreat")
		else:
			_finish(false, false)))
	vb.add_child(UIKit.button("Keep exploring", func() -> void:
		Net.request_tree_pause(false)
		pause_layer.queue_free()))


func _open_switch_menu() -> void:
	Net.request_tree_pause(true)
	var parts := UIKit.modal(self, "Switch hero")
	var switch_layer: CanvasLayer = parts[0]
	switch_layer.process_mode = Net.pause_layer_mode()
	var vb: VBoxContainer = parts[1]
	for hid in switch_available:
		if hid == hero.hero_id:
			continue
		var stats := InventoryManager.hero_stats(hid)
		vb.add_child(UIKit.button("%s (HP %d ATK %d)" % [String(ContentDatabase.get_hero(hid).get("name", hid)), int(stats["hp"]), int(stats["atk"])], func() -> void:
			Net.request_tree_pause(false)
			switch_layer.queue_free()
			DungeonManager.pending["hero_id"] = hid
			_spawn_hero(hid)
			Replica.send_player_event("hero_change", {"hero_id": hid})))
	vb.add_child(UIKit.button("Cancel", func() -> void:
		Net.request_tree_pause(false)
		switch_layer.queue_free()))


func _check_room_clear() -> void:
	await get_tree().process_frame
	if _live_room_enemies().is_empty():
		_on_room_cleared(false)


func _on_enemy_killed(_enemy_id: String, _at: Vector2,
		mob: Enemy = null) -> void:
	DungeonManager.run_kills += 1
	if Net.is_online():
		# kill credit goes to whoever landed the last hit; other machines get
		# theirs from the death despawn event
		if mob != null and mob.last_attacker == PartyState.local_index():
			hero.on_enemy_killed()
		Net.sync_managers(["dungeon"])
	else:
		hero.on_enemy_killed()
	_check_room_clear()


func _on_room_cleared(was_boss: bool) -> void:
	if finished:
		return
	if was_boss:
		AudioManager.play_stinger("victory_stinger")
		FX.shake(8.0)
		_finish(true, true)
		return
	if door_open:
		return  # already cleared (poll + a kill signal can both fire)
	if Net.is_online() and Net.is_authority():
		Net.broadcast_scene_event("room_cleared", {"idx": room_index})  # applies locally too
		return
	_apply_room_cleared()


func _apply_room_cleared(expected_room: int = -1) -> void:
	if expected_room >= 0 and expected_room != room_index:
		return
	if door_open or finished:
		return
	door_open = true
	_room_clear_auto_advance_left = ROOM_CLEAR_AUTO_ADVANCE_SECONDS
	if door_blocker != null and is_instance_valid(door_blocker):
		# queue_free alone leaves physics active through the current frame,
		# which can make an open door feel solid.
		door_blocker.collision_layer = 0
		for child: Node in door_blocker.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", true)
		door_blocker.queue_free()
	door_blocker = null
	_show_room_clear_banner()


func _show_room_clear_banner() -> void:
	if room_clear_banner != null and is_instance_valid(room_clear_banner):
		room_clear_banner.queue_free()
	var center := CenterContainer.new()
	center.name = "RoomClearBanner"
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 32.0
	center.offset_bottom = HUD_SAFE_TOP - 3.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := UIKit.nameplate("ROOM CLEARED  -  TOP DOOR OPEN", 15)
	plate.custom_minimum_size = Vector2(390, 32)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(plate)
	hud_layer.add_child(center)
	room_clear_banner = center


func _on_room_child_entered(node: Node) -> void:
	if node is Enemy:
		node.set_meta("dungeon_room_epoch", _room_epoch)


func _live_room_enemies() -> Array[Enemy]:
	var live: Array[Enemy] = []
	if room_root == null:
		return live
	for node: Node in room_root.get_children():
		if not (node is Enemy) or int(node.get_meta("dungeon_room_epoch", -1)) != _room_epoch:
			continue
		var enemy := node as Enemy
		if enemy.health != null and not enemy.health.dead:
			live.append(enemy)
	return live


func _next_room() -> void:
	if _room_transition_pending:
		return
	_room_transition_pending = true
	if room_index + 1 < layout.size():
		if Net.is_online() and Net.is_host():
			Net.broadcast_scene_event("enter_room", {"idx": room_index + 1})
		else:
			_enter_room(room_index + 1)
	else:
		_finish(true, false)


func _on_hero_defeated() -> void:
	if finished:
		return
	# co-op: the run only ends when EVERY hero is down
	if _someone_up():
		var note := UIKit.label("A hero is down! Finish the fight!", 10, UIKit.COL_BAD)
		note.position = Vector2(ContentDatabase.room_grid.x * CELL / 2.0 - 80, 56)
		note.z_index = 70
		room_root.add_child(note)
		var tw := note.create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(note, "modulate:a", 0.0, 0.5)
		tw.tween_callback(note.queue_free)
		return
	if Net.is_online() and not Net.is_authority():
		return  # the host calls the wipe from its mirrored view
	AudioManager.play_stinger("failure_stinger")
	_finish(false, false)


func _someone_up() -> bool:
	if hero != null and is_instance_valid(hero) and not hero.health.dead:
		return true
	if hero2 != null and is_instance_valid(hero2) and not hero2.health.dead:
		return true
	for pup: Variant in _net_hero_puppets.values():
		if pup != null and is_instance_valid(pup) and not (pup as CombatHero).health.dead:
			return true
	return false


func _best_hp_left() -> int:
	var hp_left := hero.health.hp if hero != null else 0
	if hero2 != null and is_instance_valid(hero2):
		hp_left = maxi(hp_left, hero2.health.hp)
	for pup: Variant in _net_hero_puppets.values():
		if pup != null and is_instance_valid(pup):
			hp_left = maxi(hp_left, (pup as CombatHero).health.hp)
	return hp_left


func _finish(success: bool, boss_defeated: bool) -> void:
	if finished:
		return
	if Net.is_online():
		if not Net.is_authority():
			return  # host computes the result and broadcasts it
		finished = true
		var net_result := DungeonManager.finish_expedition(success, boss_defeated, _best_hp_left())
		Net.sync_all()
		Net.broadcast_scene_event("expedition_finished",
			{"success": success, "boss": boss_defeated, "result": net_result})
		return
	finished = true
	var hp_left := _best_hp_left()
	var result := DungeonManager.finish_expedition(success, boss_defeated, hp_left)
	_show_finish_modal(success, boss_defeated, result)


func _show_finish_modal(success: bool, boss_defeated: bool, result: Dictionary) -> void:
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
	if Net.is_client():
		vb.add_child(UIKit.label("Waiting for %s to lead the party home..."
			% PartyState.pname(1), 10, UIKit.COL_DIM))
	else:
		vb.add_child(UIKit.button("Return to the Crossroads", func() -> void:
			end_layer.queue_free()
			if StoryEventManager.has_pending():
				SceneRouter.go("story", {"return_to": "town"})
			else:
				SceneRouter.go("town")))
