extends Node
## Headless logic probe: Piccolo hero def, manifest/SpriteFrames completeness,
## and Beam special construction.

# melee = the mad/mar kick since 95162fd (up/attack_2 use play_action
# fallbacks); fly gained an up variant from the overworld flight capture
const REQUIRED_ANIMS := [
	"idle_down", "idle_up", "idle_side",
	"walk_down", "walk_up", "walk_side",
	"attack_1_down", "attack_1_side",
	"special_down", "special_side", "special_up",
	"fly_down", "fly_side", "fly_up",
]


func _ready() -> void:
	var fails := 0

	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var piccolo: Dictionary = {}
	for h: Dictionary in data.get("heroes", []):
		if String(h.get("id", "")) == "piccolo":
			piccolo = h
	fails += _check(not piccolo.is_empty(), "piccolo in heroes.json")
	var combat: Dictionary = piccolo.get("combat", {})
	fails += _check(String(combat.get("special", {}).get("kind", "")) == "beam", "special kind = beam")
	fails += _check(String(combat.get("dodge", {}).get("kind", "")) == "fly", "dodge kind = fly")
	for part in ["muzzle", "shaft", "tip"]:
		var p := String(combat.get("special", {}).get(part, ""))
		fails += _check(ResourceLoader.exists(p), "beam %s texture exists (%s)" % [part, p])

	var frames := SpriteFramesBuilder.from_manifest_path(
		"res://assets/franchises/dragon_ball/manifests/piccolo.json")
	fails += _check(frames != null, "piccolo manifest builds SpriteFrames")
	if frames != null:
		for anim in REQUIRED_ANIMS:
			fails += _check(frames.has_animation(anim), "anim %s" % anim)

	var beam := Beam.new()
	beam.setup({"damage": 30, "knockback": 0.0, "source": null}, Vector2.RIGHT,
		combat.get("special", {}), 0)
	add_child(beam)
	fails += _check(beam.beam_range > 0.0, "beam setup (range %s)" % beam.beam_range)
	fails += _check(beam.get_child_count() == 3, "beam has muzzle+shaft+tip sprites")

	print("PICCOLO_PROBE_%s (%d failures)" % ["FAIL" if fails else "OK", fails])
	get_tree().quit(1 if fails else 0)


func _check(ok: bool, what: String) -> int:
	print(("  ok  " if ok else "  FAIL") + " - " + what)
	return 0 if ok else 1
