class_name NegotiationPanel
extends CanvasLayer
## Interactive haggling UI over Negotiation logic. Player types/nudges a price;
## the customer accepts, counters, warns, or walks. Big readable layout with
## the customer's own sprite as a portrait and a running record of the last
## offer/counter so the player always knows where the haggle stands.

signal finished(outcome: Dictionary)

var nego: Negotiation
var customer: Dictionary
var item_id: String
var portrait_tex: Texture2D = null
var price_spin: SpinBox
var chat: VBoxContainer
var chat_scroll: ScrollContainer
var offer_btn: Button
var accept_counter_btn: Button
var your_offer_lbl: Label
var last_counter: int = 0


func setup(cust: Dictionary, target_item: String, portrait: Texture2D = null) -> void:
	customer = cust
	item_id = target_item
	portrait_tex = portrait
	nego = Negotiation.start(cust, target_item)


func _ready() -> void:
	layer = 45
	AudioManager.play_track("negotiation")
	var parts := UIKit.modal(self, "%s wants: %s" % [String(customer.get("name", "?")), ContentDatabase.item_name(item_id)])
	var vb: VBoxContainer = parts[1]
	(vb.get_parent() as PanelContainer).custom_minimum_size = Vector2(500, 0)
	vb.add_theme_constant_override("separation", 6)

	# ---- header: customer portrait + facts | item icon + value ----
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	var pr := TextureRect.new()
	pr.texture = portrait_tex if portrait_tex != null else ContentDatabase.entity_texture(
		String(customer.get("id", "cust")), String(customer.get("world", "")), String(customer.get("color", "#c0c0c0")), 24)
	pr.custom_minimum_size = Vector2(56, 56)
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info.add_child(pr)
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 1)
	var cname := String(customer.get("name", "?"))
	var arch_name := String(ContentDatabase.get_archetype(String(customer.get("archetype", ""))).get("name", ""))
	facts.add_child(UIKit.label(cname, 15))
	var bond_txt := "bond Lv.%d" % RelationshipManager.level(String(customer.get("id", "")))
	if arch_name != "" and arch_name != cname:
		bond_txt = "%s  |  %s" % [arch_name, bond_txt]
	facts.add_child(UIKit.label(bond_txt, 12, UIKit.COL_DIM))
	var mood := RelationshipManager.mood(String(customer.get("id", "")))
	var mood_txt := "Neutral"
	var mood_col := UIKit.COL_DIM
	if mood > 0.2:
		mood_txt = "Good"
		mood_col = UIKit.COL_GOOD
	elif mood < -0.2:
		mood_txt = "Bad"
		mood_col = UIKit.COL_BAD
	facts.add_child(UIKit.label("Mood: %s" % mood_txt, 14, mood_col))
	info.add_child(facts)
	info.add_child(UIKit.spacer(false))
	var item_box := VBoxContainer.new()
	item_box.add_theme_constant_override("separation", 1)
	item_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = ContentDatabase.item_texture(item_id)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_box.add_child(icon)
	var value_lbl := UIKit.label("~%dg market" % nego.market_value, 12, UIKit.COL_ACCENT)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_box.add_child(value_lbl)
	info.add_child(item_box)
	vb.add_child(info)
	vb.add_child(UIKit.hsep())

	# ---- conversation ----
	var chat_parts := UIKit.scroll_list(Vector2(470, 92))
	chat_scroll = chat_parts[0]
	vb.add_child(chat_scroll)
	chat = chat_parts[1]
	chat.add_theme_constant_override("separation", 4)
	if String(customer.get("line", "")) != "":
		_say(cname, String(customer["line"]))
	_say(cname, "How much for the %s?" % ContentDatabase.item_name(item_id))

	# ---- running state of the haggle (accept button doubles as the
	# customer's standing counter-offer) ----
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	your_offer_lbl = UIKit.label("Your last offer: —", 12, UIKit.COL_DIM)
	your_offer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	your_offer_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(your_offer_lbl)
	accept_counter_btn = UIKit.button("", Callable(), 12)
	accept_counter_btn.visible = false
	accept_counter_btn.pressed.connect(_accept_counter)
	status.add_child(accept_counter_btn)
	vb.add_child(status)

	# ---- offer controls ----
	var offer_row := HBoxContainer.new()
	offer_row.add_theme_constant_override("separation", 8)
	price_spin = SpinBox.new()
	price_spin.min_value = 1
	price_spin.max_value = 999999
	price_spin.value = int(round(nego.market_value * 1.25))
	price_spin.custom_minimum_size = Vector2(130, 30)
	price_spin.get_line_edit().add_theme_font_size_override("font_size", 14)
	offer_row.add_child(price_spin)
	for pct: Array in [["-10%", 0.9], ["+10%", 1.1]]:
		var factor := float(pct[1])
		var nudge := func() -> void:
			price_spin.value = maxi(1, int(round(price_spin.value * factor)))
		offer_row.add_child(UIKit.button(String(pct[0]), nudge, 12))
	offer_btn = UIKit.button("Propose price", _propose, 12)
	offer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_row.add_child(offer_btn)
	vb.add_child(offer_row)
	var decline := func() -> void:
		EconomyManager.break_combo()
		_finish({"result": Negotiation.RESULT_LEAVE, "price": 0, "relationship_delta": 0, "perfect": false})
	vb.add_child(UIKit.button("Decline to sell", decline, 12))


func _say(who: String, text: String) -> void:
	chat.add_child(UIKit.label("%s: %s" % [who, text], 12))
	await get_tree().process_frame
	if is_instance_valid(chat_scroll):
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


func _propose() -> void:
	your_offer_lbl.text = "Your last offer: %dg" % int(price_spin.value)
	your_offer_lbl.add_theme_color_override("font_color", UIKit.COL_INK)
	var outcome := nego.propose(int(price_spin.value))
	_handle(outcome)


func _accept_counter() -> void:
	var outcome := nego.propose(last_counter)
	_handle(outcome)


func _handle(outcome: Dictionary) -> void:
	var cname := String(customer.get("name", "?"))
	_say(cname, String(outcome.get("message", "")))
	match String(outcome["result"]):
		Negotiation.RESULT_PERFECT, Negotiation.RESULT_ACCEPT:
			nego.finalize_sale(outcome)
			if bool(outcome.get("perfect", false)):
				AudioManager.play_stinger("victory_stinger")
			_finish(outcome)
		Negotiation.RESULT_COUNTER, Negotiation.RESULT_FINAL_WARNING:
			last_counter = int(outcome["price"])
			accept_counter_btn.text = "Accept their %dg" % last_counter
			accept_counter_btn.visible = true
			price_spin.value = last_counter
		Negotiation.RESULT_LEAVE:
			RelationshipManager.change_relationship(String(customer.get("id", "")), int(outcome["relationship_delta"]))
			_finish(outcome)


func _finish(outcome: Dictionary) -> void:
	AudioManager.play_track("item_shop")
	finished.emit(outcome)
	queue_free()
