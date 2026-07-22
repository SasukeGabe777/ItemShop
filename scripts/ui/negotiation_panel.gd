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

# right-stick price nudging: a tap moves 1g, holding ramps up fast
const STICK_DEADZONE := 0.45
const STICK_HOLD_DELAY := 0.35
var pad_device := 0  # split-screen: which controller haggles here
var _stick_hold := 0.0
var _stick_accum := 0.0
var _stick_stepped := false


func setup(cust: Dictionary, target_item: String, portrait: Texture2D = null) -> void:
	customer = cust
	item_id = target_item
	portrait_tex = portrait
	nego = Negotiation.start(cust, target_item)


func _ready() -> void:
	layer = 45
	AudioManager.play_track("negotiation")
	var item_label := ContentDatabase.item_name(item_id)
	if nego.quantity > 1:
		item_label = "%dx %s" % [nego.quantity, item_label]
	var parts := UIKit.modal(self, "%s wants: %s" % [String(customer.get("name", "?")), item_label])
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
	if arch_name != "" and arch_name != cname:
		facts.add_child(UIKit.label(arch_name, 11, UIKit.COL_DIM))
	var bond_level := RelationshipManager.level(String(customer.get("id", "")))
	var bond_row := HBoxContainer.new()
	bond_row.add_theme_constant_override("separation", 4)
	var bond_art := UIKit.bond_icon(maxi(1, bond_level), Vector2(38, 38))
	if bond_level == 0:
		bond_art.modulate = Color(1, 1, 1, 0.35)
	bond_row.add_child(bond_art)
	var bond_label := UIKit.label("Bond: New" if bond_level == 0 else "Bond Lv.%d" % bond_level, 12, UIKit.COL_DIM)
	bond_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bond_row.add_child(bond_label)
	facts.add_child(bond_row)
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
	facts.add_child(_purse_label())
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
	_say(cname, "How much for %s?" % item_label)
	var afford := float(nego.budget) / maxf(1.0, float(nego.market_value))
	if afford < 0.7:
		_note("Their purse looks far too light for this — expect offers well under market value.")
	elif afford < 1.0:
		_note("Their purse looks a touch light — full market price may be out of reach.")

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
	# pad/keyboard focus navigation must never land in the LineEdit (it eats
	# arrow keys for the caret); mouse users can still click in to type
	price_spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
	offer_row.add_child(price_spin)
	var nudge := func(factor: float) -> void:
		price_spin.value = maxi(1, int(round(price_spin.value * factor)))
	var minus_btn := UIKit.button("-10%", nudge.bind(0.9), 12)
	offer_row.add_child(minus_btn)
	var plus_btn := UIKit.button("+10%", nudge.bind(1.1), 12)
	offer_row.add_child(plus_btn)
	offer_btn = UIKit.button("Propose price", _propose, 12)
	offer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_row.add_child(offer_btn)
	vb.add_child(offer_row)
	var decline := func() -> void:
		EconomyManager.break_combo()
		_finish({"result": Negotiation.RESULT_LEAVE, "price": 0, "relationship_delta": 0, "perfect": false, "emote": "neutral", "message": ""})
	if UIKit.pad_connected():
		vb.add_child(UIKit.label("Right stick: adjust price by 1g — hold to speed up", 9, UIKit.COL_DIM))
	var decline_btn := UIKit.button("Decline to sell", decline, 12)
	vb.add_child(decline_btn)
	# Godot's geometric focus picker gets lost in this layout (the full-width
	# Decline button wins every horizontal probe), so wire the pad path by hand:
	# left/right cycles -10% / +10% / Propose, down is Decline, up is the
	# customer's counter-offer button whenever it is showing.
	var cycle: Array[Control] = [minus_btn, plus_btn, offer_btn]
	for i in cycle.size():
		var c := cycle[i]
		c.focus_neighbor_left = c.get_path_to(cycle[(i - 1 + cycle.size()) % cycle.size()])
		c.focus_neighbor_right = c.get_path_to(cycle[(i + 1) % cycle.size()])
		c.focus_neighbor_top = c.get_path_to(accept_counter_btn)
		c.focus_neighbor_bottom = c.get_path_to(decline_btn)
	accept_counter_btn.focus_neighbor_bottom = accept_counter_btn.get_path_to(offer_btn)
	decline_btn.focus_neighbor_top = decline_btn.get_path_to(offer_btn)


func _process(delta: float) -> void:
	if price_spin == null or not UIKit.pad_connected():
		return
	var v := Input.get_joy_axis(pad_device, JOY_AXIS_RIGHT_Y)
	if absf(v) < STICK_DEADZONE:
		_stick_hold = 0.0
		_stick_accum = 0.0
		_stick_stepped = false
		return
	var dir := -signf(v)  # stick up raises the price
	if not _stick_stepped:
		_stick_stepped = true
		price_spin.value += dir
		return
	_stick_hold += delta
	if _stick_hold < STICK_HOLD_DELAY:
		return
	# after the hold delay the rate ramps hard: ~15 g/s at first, quadrupling
	# every second held, topping out near 1000 g/s
	var held := _stick_hold - STICK_HOLD_DELAY
	_stick_accum += 15.0 * pow(4.0, minf(held, 3.0)) * delta
	if _stick_accum >= 1.0:
		var step := floorf(_stick_accum)
		_stick_accum -= step
		price_spin.value += dir * step


func _say(who: String, text: String) -> void:
	chat.add_child(UIKit.label("%s: %s" % [who, text], 12))
	await get_tree().process_frame
	if is_instance_valid(chat_scroll):
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


## Narration line in the chat: observations the shopkeeper makes.
func _note(text: String) -> void:
	chat.add_child(UIKit.label("(%s)" % text, 10, UIKit.COL_DIM))
	await get_tree().process_frame
	if is_instance_valid(chat_scroll):
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


## Coin pips + phrase sizing the customer's wallet against this item's price.
func _purse_label() -> Label:
	var afford := float(nego.budget) / maxf(1.0, float(nego.market_value))
	var filled := clampi(int(ceil(afford * 2.5)), 1, 5)
	var pips := "●".repeat(filled) + "○".repeat(5 - filled)
	var txt := "can pay well over market"
	var col := UIKit.COL_GOOD
	if afford < 0.7:
		txt = "can't afford this item"
		col = UIKit.COL_BAD
	elif afford < 1.0:
		txt = "a little short for this"
		col = UIKit.COL_ACCENT
	elif afford < 1.3:
		txt = "can afford market price"
	var lbl := UIKit.label("Purse %s  %s" % [pips, txt], 12, col)
	lbl.tooltip_text = "How much coin they carry compared to this item's market value (~%dg).\nA short purse means lowball offers — it's all they can pay." % nego.market_value
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	return lbl


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
			AudioManager.play_sfx("itemsale", 2.0)
			if bool(outcome.get("perfect", false)):
				AudioManager.play_sfx("achievement_unlocked", 2.0)
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
