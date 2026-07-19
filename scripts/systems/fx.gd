class_name FX
## Shared juice helpers: hit pause, screen shake, flashes, particles, popups.

static var _pause_until_ms: int = 0


static func hit_pause(tree: SceneTree, ms: int = -1) -> void:
	if ms < 0:
		ms = int(ContentDatabase.bal("dungeon", {}).get("hit_pause_ms", 60))
	var now := Time.get_ticks_msec()
	if now < _pause_until_ms:
		return
	_pause_until_ms = now + ms
	Engine.time_scale = 0.05
	tree.create_timer(float(ms) / 1000.0, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)


static func shake(intensity: float = 4.0) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	for cam in (loop as SceneTree).get_nodes_in_group("shake_camera"):
		if cam.has_method("add_shake"):
			cam.add_shake(intensity)


static func flash(node: CanvasItem, color: Color = Color(1, 1, 1), duration: float = 0.12) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = color * 2.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, duration)


const DEATH_SHEET := "res://assets/shared/fx/enemy_death.png"
const DEATH_FRAMES := 7


## The heart-and-darkness poof every defeated enemy releases (KH style).
static func enemy_death(parent: Node2D, at: Vector2, effect_scale: float = 1.0) -> void:
	if not ResourceLoader.exists(DEATH_SHEET):
		return
	var spr := Sprite2D.new()
	spr.texture = load(DEATH_SHEET)
	spr.hframes = DEATH_FRAMES
	spr.frame = 0
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = at + Vector2(0, -14.0 * effect_scale)
	spr.scale = Vector2(effect_scale, effect_scale)
	spr.z_index = 40
	parent.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "frame", DEATH_FRAMES - 1, 0.55)
	tw.tween_callback(spr.queue_free)


static func burst(parent: Node2D, at: Vector2, color: Color, amount: int = 10) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = amount
	p.one_shot = true
	p.emitting = true
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = color
	parent.add_child(p)
	p.finished.connect(p.queue_free)


static func damage_number(parent: Node2D, at: Vector2, amount: int, color: Color = Color(1, 0.9, 0.4)) -> void:
	var lbl := Label.new()
	lbl.text = str(amount)
	lbl.position = at + Vector2(-8, -20)
	lbl.z_index = 50
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	parent.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -14), 0.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


static func attack_trail(parent: Node2D, from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = [from, to]
	line.width = 3.0
	line.default_color = color
	line.z_index = 30
	parent.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.15)
	tw.tween_callback(line.queue_free)
