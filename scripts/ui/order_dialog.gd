class_name OrderDialog
extends Node
## Face-to-face order request and return-day delivery dialogue.

signal resolved(result: String)


func show_request(parent: Node, customer: Dictionary, offer: Dictionary,
		portrait_texture: Texture2D) -> void:
	parent.add_child(self)
	var item_id := String(offer.get("target", ""))
	var item_name := ContentDatabase.item_name(item_id)
	var qty := int(offer.get("qty", 1))
	var return_day := TimeManager.day + int(offer.get("return_in_days", 1))
	var order_type := String(offer.get("order_type", "bulk"))
	var request := "I'm looking for something special: %dx %s." % [qty, item_name]
	if order_type == "bulk":
		request = "I need a plentiful batch: %dx %s." % [qty, item_name]
	request += "\nI'll return on Day %d. Can you have it ready?" % return_day
	var parts := _shell("A customer has an order", customer, portrait_texture)
	var vb: VBoxContainer = parts[1]
	_add_item_summary(vb, item_id, qty, int(offer.get("reward_each", 0)), request)
	var note := UIKit.label("Completing an order creates a major bond increase.", 9, UIKit.COL_GOOD)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note)
	_add_choices(vb, [
		["Take the order", "accept", false],
		["Decline", "decline", false],
	])


func show_delivery(parent: Node, customer: Dictionary, order: Dictionary,
		portrait_texture: Texture2D) -> void:
	parent.add_child(self)
	var item_id := String(order.get("target", ""))
	var qty := int(order.get("qty", 1))
	var available := InventoryManager.matching_stock(order)
	var request := "I'm back for my order: %dx %s.\nDo you have everything ready?" % [
		qty, InventoryManager.order_target_label(order)]
	var parts := _shell("Order delivery — Day %d" % TimeManager.day, customer, portrait_texture)
	var vb: VBoxContainer = parts[1]
	_add_item_summary(vb, item_id, qty, int(order.get("reward_each", 0)), request)
	var stock_color := UIKit.COL_GOOD if available >= qty else UIKit.COL_BAD
	vb.add_child(UIKit.label("In storage: %d / %d" % [available, qty], 11, stock_color))
	var warning := UIKit.label("Delivery greatly increases bond. Saying you don't have it greatly decreases bond.", 9, UIKit.COL_DIM)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.x = 330
	vb.add_child(warning)
	_add_choices(vb, [
		["Deliver the items", "deliver", available < qty],
		["I don't have it", "missing", false],
	])


func _shell(title: String, customer: Dictionary, portrait_texture: Texture2D) -> Array:
	var parts := UIKit.modal(self, title)
	var vb: VBoxContainer = parts[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = portrait_texture
	portrait.custom_minimum_size = Vector2(66, 66)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	identity.add_child(UIKit.header(String(customer.get("name", "Customer"))))
	var bond := RelationshipManager.level(String(customer.get("id", "")))
	var bond_row := HBoxContainer.new()
	var art := UIKit.bond_icon(maxi(1, bond), Vector2(36, 36))
	if bond == 0:
		art.modulate = Color(1, 1, 1, 0.35)
	bond_row.add_child(art)
	bond_row.add_child(UIKit.label("Bond: New" if bond == 0 else "Bond Lv.%d" % bond, 10))
	identity.add_child(bond_row)
	return parts


func _add_item_summary(vb: VBoxContainer, item_id: String, qty: int,
		reward_each: int, request: String) -> void:
	var speech := UIKit.label(request, 11)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.custom_minimum_size.x = 340
	vb.add_child(speech)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ContentDatabase.item_texture(item_id)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	details.add_child(UIKit.label("%dx %s" % [qty, ContentDatabase.item_name(item_id)], 12, UIKit.COL_ACCENT))
	var reward := HBoxContainer.new()
	reward.add_child(UIKit.label("Delivery payment:", 9))
	reward.add_child(UIKit.gold_icon(UIKit.gold_variant(reward_each * qty), Vector2(18, 16)))
	reward.add_child(UIKit.label("%dg total (%dg each)" % [reward_each * qty, reward_each], 10, UIKit.COL_ACCENT))
	details.add_child(reward)


func _add_choices(vb: VBoxContainer, definitions: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	for definition: Array in definitions:
		var result := String(definition[1])
		var button := UIKit.button(String(definition[0]), func() -> void: _finish(result))
		button.disabled = bool(definition[2])
		row.add_child(button)


func _finish(result: String) -> void:
	resolved.emit(result)
	queue_free()
