class_name CharacterVisual
extends Node2D
## Unified character rendering: real SpriteFrames when available, generated
## placeholder otherwise. Adds the shared shadow, supports flip and bob.

var animated: AnimatedSprite2D
var static_sprite: Sprite2D
var shadow: Sprite2D
var _bob_time: float = 0.0
var _moving: bool = false
var use_frames: bool = false
var _action_playing: bool = false
var _action_seq: int = 0
var _base_offset: Vector2 = Vector2.ZERO


func setup_from_manifest(manifest_path: String) -> bool:
	var frames := SpriteFramesBuilder.from_manifest_path(manifest_path)
	if frames == null:
		return false
	animated = AnimatedSprite2D.new()
	animated.sprite_frames = frames
	if frames.has_animation("idle_down"):
		animated.animation = "idle_down"
	elif frames.has_animation("idle"):
		animated.animation = "idle"
	else:
		animated.animation = frames.get_animation_names()[0]
	animated.play()
	add_child(animated)
	# align the manifest pivot (usually the feet) with this node's origin
	var cell := Vector2(32, 32)
	var pivot := Vector2(16, 28)
	var shadow_w := 10
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.open(manifest_path, FileAccess.READ).get_as_text())
		if parsed is Dictionary:
			var m: Dictionary = parsed
			var grid: Dictionary = m.get("grid", {})
			cell = Vector2(float(grid.get("frame_width", 32)), float(grid.get("frame_height", 32)))
			var pv: Array = m.get("pivot", [cell.x / 2.0, cell.y - 4.0])
			pivot = Vector2(float(pv[0]), float(pv[1]))
			shadow_w = int(cell.x * 0.45)
	animated.offset = Vector2(cell.x / 2.0 - pivot.x, cell.y / 2.0 - pivot.y)
	_base_offset = animated.offset
	_add_shadow(maxi(10, shadow_w))
	use_frames = true
	return true


## Real character art as a single static frame (bobs while walking, flips
## for direction) — used for the shop-customer pool sprites.
func setup_static(tex: Texture2D) -> void:
	static_sprite = Sprite2D.new()
	static_sprite.texture = tex
	static_sprite.position = Vector2(0, -tex.get_height() / 2.0 + 2.0)
	add_child(static_sprite)
	_add_shadow(maxi(10, tex.get_width() - 4))
	use_frames = false


func setup_placeholder(entity_id: String, world_id: String, color_hex: String, size: int = 16) -> void:
	static_sprite = Sprite2D.new()
	static_sprite.texture = ContentDatabase.entity_texture(entity_id, world_id, color_hex, size)
	static_sprite.position = Vector2(0, -size * 0.75)
	add_child(static_sprite)
	_add_shadow(size)
	use_frames = false


func _add_shadow(size: int) -> void:
	shadow = Sprite2D.new()
	var img := Image.create(size + 6, (size + 6) / 2, false, Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var dx := (float(x) - w / 2.0 + 0.5) / (w / 2.0)
			var dy := (float(y) - h / 2.0 + 0.5) / (h / 2.0)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.3))
	shadow.texture = ImageTexture.create_from_image(img)
	shadow.z_index = -1
	add_child(shadow)
	move_child(shadow, 0)


## Direction suffix for anim lookup: up/down/side, with diagonal
## up_side/down_side variants when the sheet provides them.
func _dir_suffix(direction: Vector2) -> String:
	var ax := absf(direction.x)
	var ay := absf(direction.y)
	if ax > 0.01 and ay > 0.01 and minf(ax, ay) / maxf(ax, ay) > 0.45:
		var diag := "up_side" if direction.y < 0.0 else "down_side"
		if animated != null and animated.sprite_frames.has_animation("walk_%s" % diag):
			return diag
	if ax >= ay and direction != Vector2.ZERO:
		return "side"
	return "up" if direction.y < 0.0 else "down"


func face(direction: Vector2, moving: bool) -> void:
	_moving = moving
	if _action_playing:
		return
	if use_frames and animated != null:
		var anim := ""
		if absf(direction.x) >= absf(direction.y) and direction != Vector2.ZERO:
			# dedicated left/right animations win over the mirrored _side pair
			var lr := "left" if direction.x < 0.0 else "right"
			var prefix := "walk" if moving else "idle"
			if animated.sprite_frames.has_animation("%s_%s" % [prefix, lr]):
				anim = "%s_%s" % [prefix, lr]
				animated.flip_h = false
			else:
				var sfx := _dir_suffix(direction)
				anim = "%s_%s" % ["walk" if moving else "idle", sfx]
				animated.flip_h = direction.x < 0.0
		elif direction != Vector2.ZERO:
			var sfx2 := _dir_suffix(direction)
			anim = "%s_%s" % ["walk" if moving else "idle", sfx2]
			if sfx2.ends_with("side"):
				animated.flip_h = direction.x < 0.0
		else:
			anim = animated.animation
			if moving == false and String(anim).begins_with("walk"):
				anim = "idle" + String(anim).trim_prefix("walk")
		if animated.sprite_frames.has_animation(anim) and animated.animation != StringName(anim):
			animated.animation = StringName(anim)
			animated.play()
	elif static_sprite != null:
		if direction.x != 0.0:
			static_sprite.flip_h = direction.x < 0.0


func is_action_playing() -> bool:
	return _action_playing


## One-shot action animation resolved against the facing: prefers a
## direction-specific variant (attack_1_down / attack_1_side / attack_1_up),
## falls back through the plain name and finally the first-swing variants so
## every combo hit animates even on sheets with fewer attack rows.
func play_action(action: String, direction: Vector2) -> void:
	if not use_frames or animated == null:
		return
	var sfx := "side"
	if absf(direction.y) > absf(direction.x):
		sfx = "up" if direction.y < 0.0 else "down"
	var candidates: Array[String] = ["%s_%s" % [action, sfx]]
	if sfx != "side":
		candidates.append("%s_side" % action)
	candidates.append(action)
	if action.begins_with("attack"):
		candidates.append_array(["attack_1_%s" % sfx, "attack_1_side", "attack_1"])
	var chosen := ""
	for c in candidates:
		if animated.sprite_frames.has_animation(c):
			chosen = c
			break
	if chosen == "":
		return
	_action_playing = true
	_action_seq += 1
	var my_seq := _action_seq
	animated.flip_h = direction.x < 0.0
	# stop() first: replaying the SAME animation would otherwise resume on
	# its last frame and finish instantly (the "one-frame attack" bug)
	animated.stop()
	animated.play(StringName(chosen))
	if not animated.animation_finished.is_connected(_on_action_finished):
		animated.animation_finished.connect(_on_action_finished)
	# safety: never stay locked if the animation loops or stalls — but only
	# for THIS action; stale timers must not cut a newer swing short
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if _action_seq == my_seq:
			_action_playing = false)


func _on_action_finished() -> void:
	_action_playing = false


func _process(delta: float) -> void:
	if use_frames:
		# Sheets that only offer a single pose per creature have no motion of
		# their own; without this a moving enemy slides across the floor
		# perfectly frozen and reads as a broken sprite. Multi-frame walks
		# animate themselves and are left alone.
		if animated == null or _action_playing:
			return
		if _moving and animated.sprite_frames.get_frame_count(animated.animation) <= 1:
			_bob_time += delta * 10.0
			animated.offset = _base_offset + Vector2(0, -absf(sin(_bob_time)) * 2.0)
		elif animated.offset != _base_offset:
			animated.offset = _base_offset
		return
	if static_sprite == null:
		return
	if _moving:
		_bob_time += delta * 10.0
		static_sprite.offset = Vector2(0, -absf(sin(_bob_time)) * 2.0)
	else:
		static_sprite.offset = Vector2.ZERO


func body_node() -> CanvasItem:
	return animated if use_frames else static_sprite


## Approximate top edge of the drawn sprite in this node's local space. It is
## negative because sprites extend upward from the feet-aligned origin. Used to
## anchor floating labels (name tags, speech) just above the character's head,
## whatever art path (animated / static / placeholder) they ended up on.
func top_y() -> float:
	if use_frames and animated != null and animated.sprite_frames != null:
		var tex := animated.sprite_frames.get_frame_texture(animated.animation, 0)
		var h := float(tex.get_height()) if tex != null else 32.0
		return animated.offset.y - h / 2.0
	if static_sprite != null and static_sprite.texture != null:
		return static_sprite.position.y - static_sprite.texture.get_height() / 2.0
	return -32.0


## Rendered pixel height of the current frame, before this node's own scale.
## Lets callers keep wildly-sized art (giant bosses, tiny critters) within a
## sane on-screen footprint.
func sprite_height() -> float:
	if use_frames and animated != null and animated.sprite_frames != null:
		var tex := animated.sprite_frames.get_frame_texture(animated.animation, 0)
		return float(tex.get_height()) if tex != null else 32.0
	if static_sprite != null and static_sprite.texture != null:
		return float(static_sprite.texture.get_height())
	return 32.0
