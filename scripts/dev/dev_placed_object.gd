class_name DevPlacedObject
extends Node2D
## Curated runtime object used by the Live Developer Hub for content that does
## not already have a dedicated live entity scene (items, markers, doors,
## chests, triggers, and static NPC/hero previews). It deliberately exposes a
## small game-development surface instead of arbitrary Godot properties.

var object_type: String = "object"
var content_id: String = ""
var properties: Dictionary = {}
var collision_enabled: bool = false
var selected: bool = false
var preview_only: bool = false
var visual: Node2D
var title_label: Label


func setup(p_type: String, p_content_id: String, p_properties: Dictionary = {}, p_preview: bool = false) -> void:
	object_type = p_type
	content_id = p_content_id
	properties = p_properties.duplicate(true)
	preview_only = p_preview
	set_meta("dev_object_type", object_type)
	set_meta("dev_content_id", content_id)
	set_meta("dev_instance_id", get_instance_id())
	if not preview_only:
		add_to_group("dev_editable")
	_build_visual()
	modulate.a = 0.65 if preview_only else 1.0
	queue_redraw()


func _build_visual() -> void:
	for child in get_children():
		child.queue_free()
	var sprite := Sprite2D.new()
	var texture: Texture2D = null
	match object_type:
		"item":
			texture = ContentDatabase.item_texture(content_id)
		"customer":
			var c := ContentDatabase.get_named_customer(content_id)
			var world := String(c.get("world", "crossroads"))
			var sprite_id := String(c.get("hero_ref", content_id))
			texture = ContentDatabase.entity_texture(sprite_id, world, String(c.get("color", "#c0c0c0")), 16)
		"hero":
			var h := ContentDatabase.get_hero(content_id)
			texture = ContentDatabase.entity_texture(content_id, String(h.get("world", "crossroads")), String(h.get("color", "#c0c0c0")), 18)
		"npc":
			var n: Dictionary = ContentDatabase.npcs.get(content_id, {})
			texture = ContentDatabase.entity_texture(content_id, String(n.get("world", "crossroads")), String(n.get("color", "#c0c0c0")), 18)
		"furniture":
			var f := ContentDatabase.get_furniture(content_id)
			var size_arr: Array = f.get("size", [40, 24])
			texture = PlaceholderFactory.furniture_texture(String(f.get("furniture_type", "shelf")), int(size_arr[0]) - 6, int(size_arr[1]) - 4)
		"chest":
			texture = Scenery.texture_or_null("chest")
			if texture == null:
				texture = PlaceholderFactory.furniture_texture("chest", 28, 20)
		_:
			pass
	if texture != null:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		visual = sprite
	else:
		var poly := Polygon2D.new()
		var color := Color("#66d9ef")
		var points := PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
		if object_type == "door":
			color = Color("#c88752")
			points = PackedVector2Array([Vector2(-10, -16), Vector2(10, -16), Vector2(10, 16), Vector2(-10, 16)])
		elif object_type == "trigger":
			color = Color(0.9, 0.4, 0.9, 0.6)
		elif object_type == "marker":
			color = Color(0.3, 0.9, 0.5, 0.8)
		poly.polygon = points
		poly.color = color
		add_child(poly)
		visual = poly
	title_label = UIKit.label(content_id if content_id != "" else object_type, 7, UIKit.COL_ACCENT)
	title_label.position = Vector2(-18, -26)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)


func set_dev_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_collision_enabled(value: bool) -> void:
	collision_enabled = value
	properties["collision_enabled"] = value


func set_dev_property(key: String, value: Variant) -> void:
	properties[key] = value
	queue_redraw()


func _draw() -> void:
	if selected or preview_only:
		var color := Color("#7ad07a") if not preview_only or bool(properties.get("placement_valid", true)) else Color("#e07070")
		draw_rect(Rect2(-16, -20, 32, 40), color, false, 2.0)
		draw_line(Vector2(-5, 0), Vector2(5, 0), color, 1.0)
		draw_line(Vector2(0, -5), Vector2(0, 5), color, 1.0)


func serialize_dev_object() -> Dictionary:
	return {
		"type": object_type,
		"content_id": content_id,
		"position": [position.x, position.y],
		"rotation": rotation,
		"collision_enabled": collision_enabled,
		"properties": properties.duplicate(true),
	}


func useful_properties() -> Dictionary:
	var out := properties.duplicate(true)
	out["collision_enabled"] = collision_enabled
	match object_type:
		"item": out.merge(ContentDatabase.get_item(content_id), false)
		"customer": out.merge(ContentDatabase.get_named_customer(content_id), false)
		"hero": out.merge(ContentDatabase.get_hero(content_id), false)
		"npc": out.merge(ContentDatabase.npcs.get(content_id, {}), false)
		"furniture": out.merge(ContentDatabase.get_furniture(content_id), false)
	return out
