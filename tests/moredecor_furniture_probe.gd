extends Node
## Headless proof that the selected moredecor sprites are complete, loadable,
## data-driven decor definitions and instantiate without display slots.

const EXPECTED_IDS: Array[String] = [
	"omori_arched_window",
	"omori_brick_hearth",
	"omori_ceiling_fan",
	"omori_haunted_portrait",
	"omori_party_balloons",
	"omori_photo_garland",
	"omori_rose_sofa",
	"omori_round_cafe_table",
	"omori_stage_curtain",
	"omori_tall_houseplant",
]

var failures: Array[String] = []


func _ready() -> void:
	var prices: Dictionary = ContentDatabase.bal("furniture_prices", {})
	for id: String in EXPECTED_IDS:
		var def := ContentDatabase.get_furniture(id)
		_check(not def.is_empty(), "%s is missing from the furniture registry" % id)
		if def.is_empty():
			continue
		_check(bool(def.get("decor", false)), "%s is not marked as decor" % id)
		_check((def.get("display_slots", []) as Array).is_empty(),
			"%s unexpectedly owns item display slots" % id)
		_check(prices.has(id) and int(prices[id]) > 0, "%s has no explicit purchase price" % id)
		var sprite_path := String(def.get("sprite", ""))
		_check(sprite_path != "" and ResourceLoader.exists(sprite_path),
			"%s sprite does not load: %s" % [id, sprite_path])
		var piece := DisplayFurniture.new()
		add_child(piece)
		piece.setup({"uid": 9000, "type": id, "pos": [320, 240]}, def, 0, [])
		_check(piece.slot_count == 0, "%s instantiated as functional furniture" % id)
		var body := piece.get_child(0) as Sprite2D
		_check(body != null and body.texture != null, "%s instantiated without visible art" % id)
		if body != null and body.texture != null:
			var drawn := body.texture.get_size() * body.scale
			_check(drawn.x <= 96.0 and drawn.y <= 132.0,
				"%s renders implausibly large at %s" % [id, drawn])
		piece.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("MOREDECOR_FURNITURE_PROBE_PASS count=", EXPECTED_IDS.size())
	else:
		for message in failures:
			printerr("MOREDECOR_FURNITURE_PROBE_FAIL: ", message)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
