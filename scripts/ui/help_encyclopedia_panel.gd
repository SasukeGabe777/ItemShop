class_name HelpEncyclopediaPanel
extends Node
## Two-page help book, order ledger, and illustrated content encyclopedia.

signal closed()

var left: VBoxContainer
var right: VBoxContainer
var _modal_layer: CanvasLayer

const ADMIN_EXPORT_PATH := "user://exports/sprite_review.md"

const HELP_TOPICS := {
	"Bond": "Bond is your long-term relationship with a customer. Fair sales and completed orders raise it; broken promises and insulting deals lower it. Every 10 points raises Bond by one level, up to level 5. A completed order is worth a major +8 points; failing one costs 6 points.",
	"Customer mood": "The icon above a customer shows today's mood. A heart means good mood, the pale face is neutral, and the angry cloud means bad mood. Mood changes how generous and patient they are during a deal.",
	"Purse": "Purse is a hint, not an exact wallet total. It compares the customer's spending power with the item being negotiated. A light purse means they may genuinely be unable to reach market price.",
	"Orders": "At most one customer can request an order each day. Your order capacity grows with shop level: 4, 6, 8, 10, then 12 orders. When the ledger is full, no new requests appear. Accept a rare item or plentiful batch request, note the return day, and keep the full amount in storage. Deliver it when that customer returns for a large bond gain; admitting it is missing causes a large loss.",
	"Haggling": "Market value is your anchor. A perfect first offer earns the best relationship reward and merchant experience. Push too far and a customer may leave immediately; different customers tolerate one, two, or three rejected offers.",
	"Displays & appeal": "Customers browse items placed on display furniture. Matching a customer's interests makes a sale more likely. Better stands add attraction, and the shop's cozy, intense, retro, or modern appeal changes who visits.",
	"Time & saving": "Opening the shop, traveling, resting, and story activities spend periods. Four periods make a day. The game autosaves as time advances; the Menu also provides three manual save slots.",
	"Market & workshop": "Buy wholesale stock at the Market and watch daily trends before pricing it. The Workshop turns ingredients plus a fee into a more valuable item; its rows show the ingredients, fee, and expected craft gain.",
}


func _ready() -> void:
	var parts := UIKit.modal(self, "Help & Encyclopedia")
	_modal_layer = parts[0]
	var root: VBoxContainer = parts[1]
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 8)
	root.add_child(pages)
	var left_page := UIKit.ornate_panel(Vector2(236, 242))
	var right_page := UIKit.ornate_panel(Vector2(278, 242))
	pages.add_child(left_page)
	pages.add_child(right_page)
	left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left_page.add_child(left)
	right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right_page.add_child(right)
	root.add_child(UIKit.button("Close book", _close))
	GameState.admin_mode_changed.connect(func(_enabled: bool) -> void: show_encyclopedia())
	show_home()


func _close() -> void:
	closed.emit()
	queue_free()


func _clear(page: VBoxContainer) -> void:
	for child in page.get_children():
		child.queue_free()


func show_home() -> void:
	_clear(left)
	_clear(right)
	left.add_child(UIKit.header("Contents"))
	left.add_child(UIKit.button("How to play", show_help))
	var due := InventoryManager.due_orders().size()
	left.add_child(UIKit.button("Order ledger (%d/%d active, %d due)" % [InventoryManager.orders.size(),
		InventoryManager.order_capacity(), due], show_orders))
	left.add_child(UIKit.button("Sprite Review" if GameState.admin_mode else "Encyclopedia", show_encyclopedia))
	right.add_child(UIKit.header("The Shopkeeper's Handbook"))
	var intro := UIKit.label("Use the left page to review game systems, check accepted commissions, or browse everything recorded in your encyclopedia.", 10)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 205
	right.add_child(intro)
	right.add_child(UIKit.hsep())
	right.add_child(UIKit.label("Merchant Lv.%d   XP %d/%d" % [GameState.merchant_level,
		GameState.merchant_xp, GameState.xp_for_next_level()], 10, UIKit.COL_ACCENT))
	right.add_child(UIKit.label("Perfect deals: %d\nOrders completed: %d\nOrders failed: %d" % [
		int(GameState.stats.get("perfect_deals", 0)), int(GameState.stats.get("orders_done", 0)),
		int(GameState.stats.get("orders_failed", 0))], 9, UIKit.COL_DIM))


func show_help() -> void:
	_clear(left)
	_clear(right)
	left.add_child(UIKit.button("‹ Contents", show_home))
	left.add_child(UIKit.header("How to play"))
	var list_parts := UIKit.scroll_list(Vector2(160, 190))
	left.add_child(list_parts[0])
	for topic: String in HELP_TOPICS:
		(list_parts[1] as VBoxContainer).add_child(UIKit.button(topic,
			func() -> void: _show_help_topic(topic)))
	_show_help_topic("Bond")


func _show_help_topic(topic: String) -> void:
	_clear(right)
	right.add_child(UIKit.header(topic))
	var body := UIKit.label(String(HELP_TOPICS.get(topic, "")), 10)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 205
	right.add_child(body)
	if topic == "Bond":
		var tiers := HBoxContainer.new()
		for level in range(1, 6):
			tiers.add_child(UIKit.bond_icon(level, Vector2(38, 38)))
		right.add_child(tiers)
	elif topic == "Customer mood":
		for mood in [["happy", "Good mood"], ["neutral", "Neutral mood"], ["unhappy", "Bad mood"]]:
			var row := HBoxContainer.new()
			var icon := TextureRect.new()
			icon.texture = UIKit.emote_texture(String(mood[0]))
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			row.add_child(UIKit.label(String(mood[1]), 9))
			right.add_child(row)


func show_orders() -> void:
	_clear(left)
	_clear(right)
	left.add_child(UIKit.button("‹ Contents", show_home))
	left.add_child(UIKit.header("Accepted orders"))
	var list_parts := UIKit.scroll_list(Vector2(165, 185))
	left.add_child(list_parts[0])
	var list: VBoxContainer = list_parts[1]
	if InventoryManager.orders.is_empty():
		list.add_child(UIKit.label("No active orders.", 9, UIKit.COL_DIM))
	else:
		for order: Dictionary in InventoryManager.orders:
			var due := int(order.get("return_day", order.get("deadline_day", TimeManager.day)))
			list.add_child(UIKit.button("Day %d — %dx %s" % [due, int(order.get("qty", 1)),
				InventoryManager.order_target_label(order)], func() -> void: _show_order(order)))
	right.add_child(UIKit.header("Order ledger"))
	var help := UIKit.label("Orders are delivered only when that customer returns to the shop. Keep the requested quantity in storage before their return day.", 10)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 205
	right.add_child(help)


func _show_order(order: Dictionary) -> void:
	_clear(right)
	var customer: Dictionary = order.get("customer", {})
	right.add_child(UIKit.header(String(customer.get("name", order.get("customer_id", "Customer")))))
	var item_id := String(order.get("target", ""))
	_add_preview(right, ContentDatabase.item_texture(item_id), ContentDatabase.item_name(item_id))
	var qty := int(order.get("qty", 1))
	var stock := InventoryManager.matching_stock(order)
	var return_day := int(order.get("return_day", order.get("deadline_day", TimeManager.day)))
	right.add_child(UIKit.label("Requested: %dx %s\nReturns: Day %d\nIn storage: %d/%d\nPayment: %dg" % [
		qty, InventoryManager.order_target_label(order), return_day, stock, qty,
		qty * int(order.get("reward_each", 0))], 9, UIKit.COL_GOOD if stock >= qty else UIKit.COL_BAD))


func show_encyclopedia() -> void:
	_clear(left)
	_clear(right)
	left.add_child(UIKit.button("‹ Contents", show_home))
	left.add_child(UIKit.header("ADMIN SPRITE REVIEW" if GameState.admin_mode else "Encyclopedia"))
	for category in ["Items", "Enemies", "Bosses", "Heroes", "Customers"]:
		var entries := _entries(category)
		left.add_child(UIKit.button("%s  (%d)" % [category, entries.size()],
			func() -> void: open_category(category)))
	right.add_child(UIKit.header("Choose a category"))
	var body_text := "Open a category to see full sprite previews and names. Select any entry for its complete encyclopedia page."
	if GameState.admin_mode:
		body_text = "Admin mode reveals every reviewable sprite. Check any number of entries, then export a Markdown list and clipboard copy for the art-fix pass."
	var body := UIKit.label(body_text, 10)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 205
	right.add_child(body)
	var note := UIKit.label("Items are recorded when handled. Creatures, heroes, and customers are catalogued from worlds you can currently reach.", 9, UIKit.COL_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 205
	right.add_child(note)
	if GameState.admin_mode:
		_add_admin_export_controls(right)


func open_category(category: String) -> void:
	_clear(left)
	_clear(right)
	left.add_child(UIKit.button("‹ Categories", show_encyclopedia))
	left.add_child(UIKit.header(category))
	var list_parts := UIKit.scroll_list(Vector2(195 if GameState.admin_mode else 165,
		160 if GameState.admin_mode else 185))
	left.add_child(list_parts[0])
	if GameState.admin_mode:
		(list_parts[0] as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	(list_parts[1] as VBoxContainer).add_child(grid)
	var entries := _entries(category)
	if entries.is_empty():
		grid.columns = 1
		grid.add_child(UIKit.label("No entries recorded yet.", 9, UIKit.COL_DIM))
	else:
		for entry: Dictionary in entries:
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(190 if GameState.admin_mode else 150, 40)
			var entry_id := String(entry["id"])
			if GameState.admin_mode:
				var review_check := _review_checkbox(category, entry_id, "")
				review_check.tooltip_text = "Flag %s for sprite correction" % String(entry["name"])
				row.add_child(review_check)
			var portrait := UIKit.item_icon(entry_id, Vector2(42, 38)) if category == "Items" else TextureRect.new()
			if category != "Items":
				portrait.texture = _entry_texture(category, entry)
				portrait.custom_minimum_size = Vector2(42, 38)
				portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(portrait)
			var button := UIKit.button(String(entry["name"]),
				func() -> void: show_entry(category, entry), 8)
			if GameState.admin_mode:
				button.flat = true
				button.clip_text = true
				var empty_style := StyleBoxEmpty.new()
				for state in ["normal", "hover", "focus", "pressed"]:
					button.add_theme_stylebox_override(state, empty_style)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(button)
			grid.add_child(row)
	right.add_child(UIKit.header("%s entries" % category))
	right.add_child(UIKit.label("Select a portrait on the left page.", 9, UIKit.COL_DIM))
	if not entries.is_empty():
		show_entry(category, entries[0])


func show_entry(category: String, entry: Dictionary) -> void:
	_clear(right)
	right.add_child(UIKit.header(String(entry["name"])))
	_add_preview(right, _entry_texture(category, entry), String(entry["name"]))
	if GameState.admin_mode:
		right.add_child(_review_checkbox(category, String(entry["id"]), "Flag this sprite for correction"))
		_add_admin_export_controls(right)
	var data: Dictionary = entry["data"]
	var world := ContentDatabase.get_world(String(data.get("world", "")))
	var lines: Array[String] = ["World: %s" % String(world.get("name", data.get("world", "Unknown")))]
	match category:
		"Items":
			lines.append("Category: %s" % String(data.get("category", "item")).capitalize())
			lines.append("Market value: %dg" % MarketManager.market_value(String(entry["id"])))
			var tags: Array = data.get("tags", [])
			if not tags.is_empty(): lines.append("Tags: %s" % ", ".join(tags))
			lines.append(String(data.get("desc", "No notes recorded.")))
			var effects: Dictionary = data.get("effect", {})
			var stats: Dictionary = data.get("stats", {})
			if not effects.is_empty(): lines.append("Effects: %s" % _dictionary_text(effects))
			if not stats.is_empty(): lines.append("Stats: %s" % _dictionary_text(stats))
		"Enemies", "Bosses":
			lines.append("HP %d   ATK %d   SPD %d" % [int(data.get("hp", 0)), int(data.get("atk", 0)), int(data.get("spd", 0))])
			lines.append("Behavior: %s" % String(data.get("behavior", "unknown")).replace("_", " ").capitalize())
			var loot_names: Array[String] = []
			for drop in data.get("loot", []):
				if drop is Array and not drop.is_empty(): loot_names.append(ContentDatabase.item_name(String(drop[0])))
			if not loot_names.is_empty(): lines.append("Known drops: %s" % ", ".join(loot_names))
			var gold: Array = data.get("gold", [])
			if gold.size() >= 2: lines.append("Gold carried: %d–%dg" % [int(gold[0]), int(gold[1])])
		"Heroes":
			var base: Dictionary = data.get("base_stats", {})
			lines.append("HP %d   ATK %d   DEF %d   SPD %d" % [int(base.get("hp", 0)), int(base.get("atk", 0)), int(base.get("def", 0)), int(base.get("spd", 0))])
			lines.append("Weapon: %s" % String(data.get("weapon_type", "unknown")).replace("_", " ").capitalize())
			lines.append("Bond Lv.%d" % RelationshipManager.friendship_level(String(entry["id"])))
			lines.append(String(data.get("bio", "No biography recorded.")))
		"Customers":
			var customer_id := _customer_relationship_id(data)
			var archetype_id := CustomerGen._identity_archetype(data)
			var archetype := ContentDatabase.get_archetype(archetype_id)
			var known := customer_id in GameState.known_customers
			lines.append("Status: %s" % ("Met" if known else "Not met yet"))
			lines.append("Customer type: %s" % String(archetype.get("name", archetype_id.capitalize())))
			lines.append("Bond Lv.%d  (%d points)" % [RelationshipManager.level(customer_id),
				RelationshipManager.points(customer_id)])
			lines.append("Bond records fair deals, completed orders, and broken promises with this customer.")
	var details := UIKit.label("\n".join(lines), 9)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 205
	right.add_child(details)


func _entries(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var accessible := BridgeManager.accessible_worlds()
	match category:
		"Items":
			var item_ids: Array = ContentDatabase.live_items if GameState.admin_mode else GameState.encyclopedia
			for item_id in item_ids:
				var id := String(item_id)
				var data := ContentDatabase.get_item(id)
				if not data.is_empty() and ContentDatabase.is_live_item(id):
					out.append({"id": id, "name": ContentDatabase.item_name(id), "data": data})
		"Enemies":
			for id: String in ContentDatabase.enemies:
				var data: Dictionary = ContentDatabase.enemies[id]
				if GameState.admin_mode or String(data.get("world", "")) in accessible:
					out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"Bosses":
			for id: String in ContentDatabase.bosses:
				var data: Dictionary = ContentDatabase.bosses[id]
				if GameState.admin_mode or String(data.get("world", "")) in accessible:
					out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"Heroes":
			for id: String in ContentDatabase.heroes:
				var data: Dictionary = ContentDatabase.heroes[id]
				if GameState.admin_mode or String(data.get("world", "")) in accessible:
					out.append({"id": id, "name": String(data.get("name", id)), "data": data})
		"Customers":
			var seen: Dictionary = {}
			for raw: Variant in ContentDatabase.customer_visual_pool:
				var data: Dictionary = raw
				var identity := CustomerGen._entry_identity(data)
				if (GameState.admin_mode or String(data.get("world", "")) in accessible) and not seen.has(identity):
					seen[identity] = true
					out.append({"id": String(data.get("slug", identity)),
						"name": String(data.get("name", data.get("slug", "Customer"))), "data": data})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"]))
	return out


func _review_checkbox(category: String, entry_id: String, text: String) -> CheckBox:
	var check := CheckBox.new()
	check.name = "AdminReviewCheck"
	check.text = text
	check.custom_minimum_size = Vector2(22, 22)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.theme = UIKit.light_theme()
	for color_name in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		check.add_theme_color_override(color_name, UIKit.COL_INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.0)
	normal.set_content_margin_all(2)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.38, 0.70, 0.16)
	for state in ["normal", "pressed", "disabled"]:
		check.add_theme_stylebox_override(state, normal)
	for state in ["hover", "hover_pressed", "focus"]:
		check.add_theme_stylebox_override(state, hover)
	check.set_meta("review_category", category)
	check.set_meta("review_id", entry_id)
	check.set_pressed_no_signal(GameState.is_admin_review_flagged(category, entry_id))
	check.toggled.connect(func(flagged: bool) -> void:
		GameState.set_admin_review_flag(category, entry_id, flagged)
		_sync_admin_review_controls())
	return check


func _sync_admin_review_controls() -> void:
	for node in find_children("AdminReviewCheck", "CheckBox", true, false):
		var check := node as CheckBox
		check.set_pressed_no_signal(GameState.is_admin_review_flagged(
			String(check.get_meta("review_category", "")), String(check.get_meta("review_id", ""))))
	for node in find_children("AdminReviewCount", "Label", true, false):
		(node as Label).text = "%d flagged" % GameState.admin_review_flag_count()


func _add_admin_export_controls(page: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var count := UIKit.label("%d flagged" % GameState.admin_review_flag_count(), 9, UIKit.COL_BAD)
	count.name = "AdminReviewCount"
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(count)
	row.add_child(UIKit.button("Export .md + copy", _export_admin_review, 8))
	page.add_child(row)
	var status := UIKit.label("", 8, UIKit.COL_DIM)
	status.name = "AdminReviewExportStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 205
	page.add_child(status)


func _export_admin_review() -> void:
	var groups := {"Items": [], "Characters": [], "Enemies": []}
	var category_groups := {
		"Items": "Items", "Heroes": "Characters", "Customers": "Characters",
		"Enemies": "Enemies", "Bosses": "Enemies",
	}
	var category_labels := {
		"Items": "Item", "Heroes": "Hero", "Customers": "Customer",
		"Enemies": "Enemy", "Bosses": "Boss",
	}
	for category: String in category_groups:
		for entry: Dictionary in _entries(category):
			var id := String(entry["id"])
			if not GameState.is_admin_review_flagged(category, id):
				continue
			var data: Dictionary = entry["data"]
			var world := ContentDatabase.get_world(String(data.get("world", "")))
			var world_name := String(world.get("name", data.get("world", "Unknown")))
			var asset := _entry_asset_reference(category, entry)
			var line := "- [ ] %s (`%s`) — %s · %s" % [
				String(entry["name"]), id, String(category_labels[category]), world_name]
			if asset != "":
				line += " — `%s`" % asset
			(groups[String(category_groups[category])] as Array).append(line)
	var lines: Array[String] = [
		"# Crossroads Sprite Review", "", "Generated: %s" % Time.get_datetime_string_from_system(),
		"Flagged entries: %d" % GameState.admin_review_flag_count(), "",
	]
	for group_name in ["Items", "Characters", "Enemies"]:
		lines.append("## %s" % group_name)
		lines.append("")
		var entries: Array = groups[group_name]
		if entries.is_empty():
			lines.append("_No entries flagged._")
		else:
			lines.append_array(entries)
		lines.append("")
	var markdown := "\n".join(lines)
	var export_dir := ProjectSettings.globalize_path("user://exports")
	DirAccess.make_dir_recursive_absolute(export_dir)
	var file := FileAccess.open(ADMIN_EXPORT_PATH, FileAccess.WRITE)
	if file == null:
		_set_admin_export_status("Export failed: %s" % FileAccess.get_open_error(), true)
		return
	file.store_string(markdown)
	DisplayServer.clipboard_set(markdown)
	_set_admin_export_status("Exported and copied:\n%s" % ProjectSettings.globalize_path(ADMIN_EXPORT_PATH), false)


func _set_admin_export_status(message: String, failed: bool) -> void:
	for node in find_children("AdminReviewExportStatus", "Label", true, false):
		var status := node as Label
		status.text = message
		status.add_theme_color_override("font_color", UIKit.COL_BAD if failed else UIKit.COL_GOOD)
	for node in find_children("AdminReviewCount", "Label", true, false):
		var count := node as Label
		count.text = "Export failed" if failed else "Saved .md + copied!"
		count.tooltip_text = message
		count.add_theme_color_override("font_color", UIKit.COL_BAD if failed else UIKit.COL_GOOD)


func _entry_asset_reference(category: String, entry: Dictionary) -> String:
	var id := String(entry["id"])
	var data: Dictionary = entry["data"]
	var world := String(data.get("world", "crossroads"))
	if category == "Items":
		return "res://assets/franchises/%s/processed/items/%s.png" % [world, id]
	if category == "Customers":
		var customer_manifest := String(data.get("manifest", ""))
		return customer_manifest if customer_manifest != "" else String(data.get("static", ""))
	var manifest := "res://assets/franchises/%s/manifests/%s.json" % [world, id]
	if ResourceLoader.exists(manifest):
		return manifest
	var folder := "bosses" if category == "Bosses" else "enemies"
	return "res://assets/franchises/%s/processed/%s/%s.png" % [world, folder, id]


func _entry_texture(category: String, entry: Dictionary) -> Texture2D:
	var id := String(entry["id"])
	var data: Dictionary = entry["data"]
	if category == "Items":
		return ContentDatabase.item_texture(id)
	if category == "Customers":
		var manifest := String(data.get("manifest", ""))
		if manifest != "" and ResourceLoader.exists(manifest):
			var customer_frames := SpriteFramesBuilder.from_manifest_path(manifest)
			if customer_frames != null:
				var customer_animation := StringName("idle_down")
				if not customer_frames.has_animation(customer_animation):
					customer_animation = customer_frames.get_animation_names()[0]
				return customer_frames.get_frame_texture(customer_animation, 0)
		var static_path := String(data.get("static", ""))
		if static_path != "" and ResourceLoader.exists(static_path):
			return load(static_path)
	var world := String(data.get("world", "crossroads"))
	var frames := SpriteFramesBuilder.from_manifest_path(
		"res://assets/franchises/%s/manifests/%s.json" % [world, id])
	if frames != null:
		var animation := StringName("idle_down")
		if not frames.has_animation(animation):
			animation = frames.get_animation_names()[0]
		return frames.get_frame_texture(animation, 0)
	for path in [
		"res://assets/franchises/%s/processed/enemies/%s.png" % [world, id],
		"res://assets/franchises/%s/processed/bosses/%s.png" % [world, id],
		"res://assets/franchises/%s/processed/%s.png" % [world, id],
	]:
		if ResourceLoader.exists(path): return load(path)
	return ContentDatabase.entity_texture(id, world, String(data.get("color", "#c0c0c0")), 24)


func _customer_relationship_id(entry: Dictionary) -> String:
	var identity := CustomerGen._entry_identity(entry)
	for named_id: String in ContentDatabase.named_customers:
		var named: Dictionary = ContentDatabase.named_customers[named_id]
		var visual := ContentDatabase.customer_pool_entry_by_name(String(named.get("name", "")))
		if not visual.is_empty() and CustomerGen._entry_identity(visual) == identity:
			return named_id
	return "walkin_%s" % String(entry.get("slug", "customer"))


func _add_preview(page: VBoxContainer, texture: Texture2D, caption: String) -> void:
	var preview := TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(205, 82)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.tooltip_text = caption
	page.add_child(preview)


func _dictionary_text(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in values:
		parts.append("%s %s" % [key.replace("_", " "), str(values[key])])
	return ", ".join(parts)
