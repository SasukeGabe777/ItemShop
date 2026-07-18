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


func face(direction: Vector2, moving: bool) -> void:
	_moving = moving
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
				anim = "walk_side" if moving else "idle_side"
				animated.flip_h = direction.x < 0.0
		elif direction.y < 0.0:
			anim = "walk_up" if moving else "idle_up"
		elif direction != Vector2.ZERO:
			anim = "walk_down" if moving else "idle_down"
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


func _process(delta: float) -> void:
	if use_frames or static_sprite == null:
		return
	if _moving:
		_bob_time += delta * 10.0
		static_sprite.offset = Vector2(0, -absf(sin(_bob_time)) * 2.0)
	else:
		static_sprite.offset = Vector2.ZERO


func body_node() -> CanvasItem:
	return animated if use_frames else static_sprite
