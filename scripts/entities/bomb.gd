class_name Bomb
extends Area2D
## Link's placed bomb: sits where it was dropped, blinks faster as the fuse
## runs down, and explodes after the fuse — or immediately when an enemy
## walks into it. Damage is a radius burst so it also catches groups.

const EXPLOSION_MANIFEST := "res://assets/franchises/zelda/manifests/bomb_explosion.json"

var packet: Dictionary = {}
var radius: float = 60.0
var fuse: float = 2.0
var _armed := true
var _sprite: Sprite2D


func setup(damage_packet: Dictionary, blast_radius: float, fuse_time: float, target_layer: int) -> void:
	packet = damage_packet
	radius = blast_radius
	fuse = fuse_time
	collision_layer = 0
	collision_mask = target_layer
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	var tex_path := "res://assets/franchises/zelda/processed/bomb.png"
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	else:
		_sprite.texture = PlaceholderFactory.flat_texture(Color(0.25, 0.25, 0.3), 10, 12)
	_sprite.offset = Vector2(0, -6)
	add_child(_sprite)
	area_entered.connect(_on_area)
	# fuse blink: pulse red, faster near the end
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(_sprite, "modulate", Color(1.0, 0.45, 0.45), 0.18)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)


func _physics_process(delta: float) -> void:
	if not _armed:
		return
	fuse -= delta
	if fuse <= 0.0:
		explode()


func is_armed() -> bool:
	return _armed


func _on_area(area: Area2D) -> void:
	if _armed and area is HurtboxComponent:
		explode()


func explode() -> void:
	if not _armed:
		return
	_armed = false
	_sprite.visible = false
	set_deferred("monitoring", false)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy != null and is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= radius:
			if enemy.has_method("take_packet"):
				enemy.take_packet(packet, global_position)
	AudioManager.play_sfx("attack_enemy_2", -2.0)
	FX.shake(5.0)
	var frames := SpriteFramesBuilder.from_manifest_path(EXPLOSION_MANIFEST)
	if frames != null and frames.has_animation("explode"):
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.position = Vector2(0, -8)
		add_child(anim)
		anim.play("explode")
		anim.animation_finished.connect(queue_free)
	else:
		FX.burst(get_parent(), global_position, Color(1.0, 0.6, 0.2), 20)
		queue_free()
