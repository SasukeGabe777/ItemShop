class_name Scenery
## Helpers for building environments from the supplied location art, with the
## original flat-color polygons as automatic fallback when a texture is absent.

const PROPS_DIR := "res://assets/locations/processed/"


static func texture_or_null(name: String) -> Texture2D:
	var path := PROPS_DIR + name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


## A floor rectangle tiled with the named texture; falls back to a flat polygon.
static func tiled_floor(parent: Node, rect: Rect2, texture_name: String, fallback: Color, z: int = -10, tint: Color = Color.WHITE) -> void:
	var tex := texture_or_null(texture_name)
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_enabled = true
		spr.region_rect = Rect2(Vector2.ZERO, rect.size)
		spr.centered = false
		spr.position = rect.position
		spr.z_index = z
		spr.modulate = tint
		parent.add_child(spr)
		return
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	poly.color = fallback
	poly.z_index = z
	parent.add_child(poly)


## A decorative prop sprite anchored at its base. Returns null if missing.
static func prop(parent: Node, at: Vector2, texture_name: String, z: int = 0) -> Sprite2D:
	var tex := texture_or_null(texture_name)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = at - Vector2(0, tex.get_height() / 2.0)
	spr.z_index = z
	parent.add_child(spr)
	return spr
