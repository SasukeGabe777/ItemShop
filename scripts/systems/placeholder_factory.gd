class_name PlaceholderFactory
## Generates safe placeholder textures at runtime for any entity or item whose
## real sprite has not been supplied yet. Pixel-art style, deterministic per id.

static var _cache: Dictionary = {}


static func character_texture(id: String, tint: Color, size: int = 16) -> Texture2D:
	var key := "chr:%s:%d" % [id, size]
	if _cache.has(key):
		return _cache[key]
	var px := maxi(12, size)
	var img := Image.create(px, px + px / 2, false, Image.FORMAT_RGBA8)
	var outline := tint.darkened(0.55)
	var body := tint
	var head := tint.lightened(0.35)
	var h := img.get_height()
	var w := img.get_width()
	var head_r := w / 3
	var cx := w / 2
	# head
	for y in range(0, head_r * 2):
		for x in range(cx - head_r, cx + head_r):
			var dx := float(x - cx) + 0.5
			var dy := float(y - head_r) + 0.5
			if dx * dx + dy * dy <= head_r * head_r:
				img.set_pixel(x, y, head)
	# body
	var bw := w / 3
	for y in range(head_r * 2 - 1, h - 1):
		for x in range(cx - bw, cx + bw):
			img.set_pixel(x, y, body)
	# eyes (seeded horizontal offset for variety)
	var seed_val := absi(id.hash())
	var eo := 1 + seed_val % 2
	var ey := head_r - 1
	img.set_pixel(cx - eo, ey, Color(0.08, 0.08, 0.12))
	img.set_pixel(cx + eo, ey, Color(0.08, 0.08, 0.12))
	_apply_outline(img, outline)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func item_texture(id: String, category: String) -> Texture2D:
	var key := "itm:%s" % id
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	var seed_val := absi(id.hash())
	var hue := float(seed_val % 360) / 360.0
	var col := Color.from_hsv(hue, 0.55, 0.9)
	var c := 7
	match category:
		"weapon":
			for y in range(2, 12):
				img.set_pixel(c - (y % 2), y, col.lightened(0.3))
				img.set_pixel(c + 1 - (y % 2), y, col)
			for x in range(4, 10):
				img.set_pixel(x, 10, col.darkened(0.3))
		"armor":
			for y in range(3, 11):
				var half := 5 - absi(y - 6)
				for x in range(c - half, c + half + 1):
					img.set_pixel(x, y, col)
		"consumable", "food":
			for y in range(3, 12):
				for x in range(4, 10):
					var dx := float(x - c) + 0.5
					var dy := float(y - 7) + 0.5
					if dx * dx / 9.0 + dy * dy / 16.0 <= 1.0:
						img.set_pixel(x, y, col)
			img.set_pixel(6, 2, col.darkened(0.4))
			img.set_pixel(7, 2, col.darkened(0.4))
		"accessory", "charm":
			for i in range(5):
				var ang := TAU * float(i) / 5.0 - PI / 2.0
				var x := c + int(round(cos(ang) * 4.0))
				var y := 7 + int(round(sin(ang) * 4.0))
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						img.set_pixel(clampi(x + ox, 0, 13), clampi(y + oy, 0, 13), col)
		"treasure", "key":
			for y in range(3, 11):
				var half := 4 - absi(y - 7) / 2
				for x in range(c - half, c + half + 1):
					img.set_pixel(x, y, col.lightened(0.2) if y < 7 else col)
		_:
			for y in range(4, 11):
				for x in range(4, 11):
					img.set_pixel(x, y, col)
	_apply_outline(img, col.darkened(0.6))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func furniture_texture(kind: String, w: int, h: int) -> Texture2D:
	var key := "fur:%s:%dx%d" % [kind, w, h]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color(0.45, 0.32, 0.2)
	if kind == "counter":
		base = Color(0.5, 0.38, 0.24)
	elif kind == "pedestal":
		base = Color(0.55, 0.55, 0.6)
	elif kind == "case":
		base = Color(0.35, 0.5, 0.6)
	img.fill(base)
	for x in range(w):
		img.set_pixel(x, 0, base.lightened(0.3))
		img.set_pixel(x, h - 1, base.darkened(0.4))
	for y in range(h):
		img.set_pixel(0, y, base.darkened(0.25))
		img.set_pixel(w - 1, y, base.darkened(0.25))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func flat_texture(col: Color, w: int = 8, h: int = 8) -> Texture2D:
	var key := "flat:%s:%dx%d" % [col.to_html(), w, h]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _apply_outline(img: Image, outline: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var mark: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.1:
				continue
			var touches := false
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + off.x
				var ny := y + off.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.1:
					touches = true
					break
			if touches:
				mark.append(Vector2i(x, y))
	for p in mark:
		img.set_pixel(p.x, p.y, outline)
