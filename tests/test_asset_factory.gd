extends Node
## Headless proof of the Asset Factory runtime layer: the shop's furniture
## system (layout, slots, movement, save roundtrip, customer adapter) and the
## factory's write-side IO (id sanitizing, JSON upserts, icon slicing,
## manifest building) — everything writable is exercised against user://
## scratch files, never the real data/.

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_campaign()
	InventoryManager.reset()
	ShopFurnitureManager.reset()

	_test_furniture_layout()
	_test_furniture_move_and_save()
	_test_customer_adapter()
	_test_shop_scene_builds()
	_test_factory_io()
	_test_manifest_rects_build()
	_test_background_removal()

	if failures.is_empty():
		print("ASSET_FACTORY_TEST_PASS")
	else:
		for f_msg in failures:
			printerr("ASSET_FACTORY_TEST_FAIL: " + f_msg)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _test_furniture_layout() -> void:
	ShopFurnitureManager.ensure_layout()
	var needed := InventoryManager.display_slot_count()
	_check(ShopFurnitureManager.total_slot_count() == needed,
		"default layout offers %d slots, expected %d" % [ShopFurnitureManager.total_slot_count(), needed])
	var slots := ShopFurnitureManager.get_all_available_display_slots()
	_check(slots.size() == needed, "slot list size mismatch")
	for i in slots.size():
		_check(int(slots[i]["index"]) == i, "slot indices not sequential")
	# classic window bonus must survive the furniture refactor unchanged
	var bonus := ShopFurnitureManager.slot_attention_bonus(0)
	var expected := float(ContentDatabase.bal("shop", {}).get("window_attention_bonus", 0.25)) \
		+ float(ContentDatabase.get_furniture("window_counter").get("customer_attention_modifier", 0.0))
	_check(absf(bonus - expected) < 0.001, "window slot bonus %f != %f" % [bonus, expected])
	_check(ShopFurnitureManager.slot_attention_bonus(5) < 0.001, "middle slot should have no bonus in default layout")


func _test_furniture_move_and_save() -> void:
	var inst: Dictionary = ShopFurnitureManager.layout[0]
	var uid := int(inst["uid"])
	var room := Rect2(150, 132, 340, 258)
	_check(ShopFurnitureManager.placement_valid(uid, Vector2(200, 200), room), "open spot should be valid")
	_check(not ShopFurnitureManager.placement_valid(uid, Vector2(0, 0), room), "outside room should be invalid")
	var other: Dictionary = ShopFurnitureManager.layout[1]
	var other_pos: Array = other["pos"]
	_check(not ShopFurnitureManager.placement_valid(uid, Vector2(float(other_pos[0]), float(other_pos[1])), room),
		"overlapping another piece should be invalid")
	_check(ShopFurnitureManager.move_instance(uid, Vector2(200, 200)), "move_instance failed")
	var saved := ShopFurnitureManager.to_save()
	ShopFurnitureManager.reset()
	ShopFurnitureManager.from_save(saved)
	var pos: Array = ShopFurnitureManager.instance_by_uid(uid).get("pos", [0, 0])
	_check(Vector2(float(pos[0]), float(pos[1])) == Vector2(200, 200), "furniture position lost in save roundtrip")


func _test_customer_adapter() -> void:
	# put something on display so a rich customer will want it
	var item_id := ""
	for id: String in InventoryManager.storage:
		item_id = id
		break
	_check(item_id != "", "starting inventory is empty")
	InventoryManager.place_display(0, item_id)
	var cust := {"id": "test", "archetype": "adventurer", "budget": 999999, "world": ""}
	var choice := ShopFurnitureManager.choose_display_slot_for_customer(cust)
	_check(not choice.is_empty(), "customer found nothing on a stocked display")
	if not choice.is_empty():
		_check(int(choice["slot"]) == 0, "customer chose slot %d, expected 0" % int(choice["slot"]))
	InventoryManager.take_display(0)


func _test_shop_scene_builds() -> void:
	var packed: PackedScene = load("res://scenes/shop/shop.tscn")
	var shop: Node2D = packed.instantiate()
	add_child(shop)
	var pieces: Array = shop.furniture_nodes
	_check(pieces.size() == ShopFurnitureManager.layout.size(),
		"shop built %d furniture nodes for %d layout instances" % [pieces.size(), ShopFurnitureManager.layout.size()])
	var points: Array = shop.browse_points
	_check(points.size() == ShopFurnitureManager.total_slot_count(), "browse points don't match slot count")
	shop.queue_free()


func _test_factory_io() -> void:
	_check(CCSFactoryIO.sanitize_id("Sea-Salt Ice Cream!") == "sea_salt_ice_cream", "sanitize_id mangled name")
	_check(CCSFactoryIO.unique_id("potion", {"potion": true, "potion_2": true}) == "potion_3", "unique_id collision handling")
	var path := "user://test_factory_items.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var err := CCSFactoryIO.upsert_entry(path, "items", "crossroads.items.v1",
		{"id": "test_apple", "name": "Test Apple", "world": "crossroads", "category": "food", "price": 5})
	_check(err == "", "upsert (create) failed: %s" % err)
	err = CCSFactoryIO.upsert_entry(path, "items", "crossroads.items.v1",
		{"id": "test_apple", "name": "Renamed Apple", "world": "crossroads", "category": "food", "price": 8})
	_check(err == "", "upsert (replace) failed: %s" % err)
	var doc := CCSFactoryIO.load_doc(path)
	_check(String(doc.get("schema", "")) == "crossroads.items.v1", "schema tag lost")
	var arr: Array = doc.get("items", [])
	_check(arr.size() == 1, "replace duplicated the entry (%d rows)" % arr.size())
	if arr.size() == 1:
		_check(String((arr[0] as Dictionary)["name"]) == "Renamed Apple", "replace didn't update fields")
	var found := CCSFactoryIO.find_entry(path, "items", "test_apple")
	_check(int(found.get("price", 0)) == 8, "find_entry returned stale data")
	# icon slicing from a synthetic sheet
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(16, 0, 16, 16), Color.RED)
	var icon_path := "user://test_factory_icon.png"
	err = CCSSpriteSheetPreview.save_region_png(img, Rect2i(16, 0, 16, 16), icon_path)
	_check(err == "", "save_region_png failed: %s" % err)
	var sliced := Image.load_from_file(ProjectSettings.globalize_path(icon_path))
	_check(sliced != null and sliced.get_width() == 16 and sliced.get_height() == 16, "sliced icon has wrong size")
	if sliced != null:
		_check(sliced.get_pixel(8, 8).is_equal_approx(Color.RED), "sliced icon has wrong content")
	var strip_path := "user://test_factory_strip.png"
	var rects: Array[Rect2i] = [Rect2i(0, 0, 16, 16), Rect2i(16, 0, 16, 16), Rect2i(32, 0, 16, 16)]
	err = CCSSpriteSheetPreview.save_strip_png(img, rects, strip_path)
	_check(err == "", "save_strip_png failed: %s" % err)
	var strip := Image.load_from_file(ProjectSettings.globalize_path(strip_path))
	_check(strip != null and strip.get_width() == 48, "strip has wrong width")


## Sheets on an opaque canvas color must lose that background: auto-detected
## on load, applied to the preview and to every exported frame.
func _test_background_removal() -> void:
	var bg := Color(0.573, 0.573, 0.573)  # flat gray canvas like spriters-resource rips
	var img := Image.create(32, 16, false, Image.FORMAT_RGB8)
	img.fill(bg)
	img.fill_rect(Rect2i(4, 4, 8, 8), Color.RED)  # the actual sprite
	var sheet_path := "user://test_factory_bg_sheet.png"
	img.save_png(ProjectSettings.globalize_path(sheet_path))

	var keyed := CCSSpriteSheetPreview.chroma_keyed(_rgba(img), bg, 0.02)
	_check(keyed.get_pixel(0, 0).a == 0.0, "background pixel not keyed out")
	_check(keyed.get_pixel(8, 8).is_equal_approx(Color.RED), "sprite pixel damaged by keying")

	var preview := CCSSpriteSheetPreview.new()
	add_child(preview)
	var err := preview.load_sheet(sheet_path)
	_check(err == "", "preview failed to load sheet: %s" % err)
	_check(preview.chroma_enabled, "opaque sheet did not auto-enable background removal")
	# the sheet round-trips through an 8-bit PNG, so quantize the expected
	# color the same way before comparing — raw is_equal_approx against the
	# float constant fails on precision alone (0.573 vs 146/255)
	var bg8 := Color(roundf(bg.r * 255.0) / 255.0, roundf(bg.g * 255.0) / 255.0, roundf(bg.b * 255.0) / 255.0)
	_check(preview.chroma_color.is_equal_approx(bg8), "auto-detected wrong background color")
	var out_path := "user://test_factory_bg_frame.png"
	err = preview.export_region_png(Rect2i(0, 0, 16, 16), out_path)
	_check(err == "", "export_region_png failed: %s" % err)
	var frame := Image.load_from_file(ProjectSettings.globalize_path(out_path))
	_check(frame != null and frame.get_pixel(0, 0).a == 0.0, "exported frame kept the background")
	_check(frame != null and frame.get_pixel(8, 8).is_equal_approx(Color.RED), "exported frame lost sprite pixels")

	# a sheet that already has transparency must NOT auto-key
	var alpha_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	alpha_img.fill(Color(0, 0, 0, 0))
	alpha_img.fill_rect(Rect2i(2, 2, 4, 4), Color.GREEN)
	var alpha_path := "user://test_factory_alpha_sheet.png"
	alpha_img.save_png(ProjectSettings.globalize_path(alpha_path))
	err = preview.load_sheet(alpha_path)
	_check(err == "", "preview failed to load alpha sheet: %s" % err)
	_check(not preview.chroma_enabled, "transparent sheet wrongly auto-enabled background removal")
	preview.queue_free()


func _rgba(img: Image) -> Image:
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	return out


## Manifests with per-animation pixel rects must build real SpriteFrames.
func _test_manifest_rects_build() -> void:
	var img := Image.create(96, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLUE)
	var tex := ImageTexture.create_from_image(img)
	var manifest := {
		"asset_id": "test_walker",
		"grid": {"frame_width": 32, "frame_height": 48, "columns": 3, "rows": 1},
		"animations": {
			"walk_down": {"rects": [[0, 0, 32, 48], [32, 0, 32, 48], [64, 0, 32, 48]], "fps": 8, "loop": true},
			"idle_down": {"frames": [0], "fps": 3, "loop": true},
		},
	}
	var frames := SpriteFramesBuilder.build(tex, manifest)
	_check(frames != null, "rects manifest produced no SpriteFrames")
	if frames != null:
		_check(frames.get_frame_count("walk_down") == 3, "rects animation has %d frames, expected 3" % frames.get_frame_count("walk_down"))
		_check(frames.get_frame_count("idle_down") == 1, "grid-index animation broken alongside rects")
		var at := frames.get_frame_texture("walk_down", 1) as AtlasTexture
		_check(at != null and at.region == Rect2(32, 0, 32, 48), "rect frame region wrong")
