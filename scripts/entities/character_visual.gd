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
	animated.animation = "idle_down" if frames.has_animation("idle_down") else frames.get_animation_names()[0]
	animated.play()
	add_child(animated)
	_add_shadow(10)
	use_frames = true
	return true


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
