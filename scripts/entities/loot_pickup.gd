class_name LootPickup
extends Area2D
## Dropped item or gold; magnetizes to the player and banks into the run loot.

signal collected(item_id: String, gold_amount: int)

var item_id: String = ""
var gold_amount: int = 0
var _magnet_target: Node2D


func setup_item(id: String) -> void:
	item_id = id
	_common(ContentDatabase.item_texture(id))


func setup_gold(amount: int) -> void:
	gold_amount = amount
	_common(PlaceholderFactory.flat_texture(Color(1.0, 0.85, 0.2), 7, 7))


func _common(tex: Texture2D) -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	add_child(sprite)
	body_entered.connect(_on_body)
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "position:y", -3.0, 0.4)
	tw.tween_property(sprite, "position:y", 0.0, 0.4)


func _physics_process(delta: float) -> void:
	if _magnet_target != null and is_instance_valid(_magnet_target):
		global_position = global_position.move_toward(_magnet_target.global_position, 260.0 * delta)
		if global_position.distance_to(_magnet_target.global_position) < 8.0:
			_collect()


func _on_body(body: Node) -> void:
	if body is CombatHero:
		_magnet_target = body


func _collect() -> void:
	if item_id != "":
		DungeonManager.add_run_loot(item_id)
	if gold_amount > 0:
		DungeonManager.run_gold += gold_amount
	collected.emit(item_id, gold_amount)
	FX.burst(get_parent(), global_position, Color(1, 1, 0.8), 5)
	queue_free()
