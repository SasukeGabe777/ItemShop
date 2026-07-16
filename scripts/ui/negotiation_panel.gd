class_name NegotiationPanel
extends CanvasLayer
## Interactive haggling UI over Negotiation logic. Player types/nudges a price;
## the customer accepts, counters, warns, or walks.

signal finished(outcome: Dictionary)

var nego: Negotiation
var customer: Dictionary
var item_id: String
var price_spin: SpinBox
var chat: VBoxContainer
var panel_layer: CanvasLayer
var offer_btn: Button
var accept_counter_btn: Button
var last_counter: int = 0


func setup(cust: Dictionary, target_item: String) -> void:
	customer = cust
	item_id = target_item
	nego = Negotiation.start(cust, target_item)


func _ready() -> void:
	layer = 45
	AudioManager.play_track("negotiation")
	var parts := UIKit.modal(self, "%s wants: %s" % [String(customer.get("name", "?")), ContentDatabase.item_name(item_id)])
	var vb: VBoxContainer = parts[1]
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = ContentDatabase.item_texture(item_id)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info.add_child(icon)
	var facts := VBoxContainer.new()
	facts.add_child(UIKit.label("Market value: ~%dg" % nego.market_value, 10))
	var arch := ContentDatabase.get_archetype(String(customer.get("archetype", "")))
	facts.add_child(UIKit.label("%s | relationship Lv.%d | mood %s" % [
		String(arch.get("name", "?")), RelationshipManager.level(String(customer.get("id", ""))),
		"good" if RelationshipManager.mood(String(customer.get("id", ""))) > 0.2 else ("bad" if RelationshipManager.mood(String(customer.get("id", ""))) < -0.2 else "neutral")], 9, UIKit.COL_DIM))
	info.add_child(facts)
	vb.add_child(info)
	var chat_parts := UIKit.scroll_list(Vector2(340, 110))
	vb.add_child(chat_parts[0])
	chat = chat_parts[1]
	if String(customer.get("line", "")) != "":
		_say(String(customer.get("name", "?")), String(customer["line"]))
	_say(String(customer.get("name", "?")), "How much for the %s?" % ContentDatabase.item_name(item_id))
	var offer_row := HBoxContainer.new()
	offer_row.add_theme_constant_override("separation", 6)
	price_spin = SpinBox.new()
	price_spin.min_value = 1
	price_spin.max_value = 999999
	price_spin.value = int(round(nego.market_value * 1.25))
	price_spin.custom_minimum_size = Vector2(110, 0)
	offer_row.add_child(price_spin)
	for pct: Array in [["-10%", 0.9], ["+10%", 1.1]]:
		offer_row.add_child(UIKit.button(String(pct[0]), func() -> void:
			price_spin.value = maxi(1, int(round(price_spin.value * float(pct[1]))))))
	offer_btn = UIKit.button("Propose price", _propose)
	offer_row.add_child(offer_btn)
	vb.add_child(offer_row)
	accept_counter_btn = UIKit.button("", Callable())
	accept_counter_btn.visible = false
	accept_counter_btn.pressed.connect(_accept_counter)
	vb.add_child(accept_counter_btn)
	vb.add_child(UIKit.button("Decline to sell", func() -> void:
		EconomyManager.break_combo()
		_finish({"result": Negotiation.RESULT_LEAVE, "price": 0, "relationship_delta": 0, "perfect": false})))


func _say(who: String, text: String) -> void:
	chat.add_child(UIKit.label("%s: %s" % [who, text], 9))


func _propose() -> void:
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
