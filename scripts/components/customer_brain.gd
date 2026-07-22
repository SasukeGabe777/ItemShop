class_name CustomerBrain
extends Node
## Drives a customer entity through the shop: enter -> browse display slots ->
## decide -> negotiate (or leave). The shop scene listens to these signals.

signal wants_to_negotiate(customer: Dictionary, item_id: String)
signal wants_to_order(customer: Dictionary, direct_boom_request: bool)
signal wants_order_delivery(customer: Dictionary, order_id: int)
signal disappointed(customer: Dictionary)
signal leaving()

enum State { ENTERING, BROWSING, DECIDING, NEGOTIATING, LEAVING }

var customer: Dictionary = {}
var state: State = State.ENTERING
var browse_time: float = 0.0
var target_slot: int = -1
var preferred_interest: String = ""


func setup(cust: Dictionary, p_preferred_interest: String = "") -> void:
	customer = cust
	preferred_interest = p_preferred_interest
	state = State.ENTERING
	var arch: Dictionary = ContentDatabase.get_archetype(String(cust.get("archetype", "")))
	browse_time = 1.2 + float(arch.get("patience", 3)) * 0.5


func tick(delta: float) -> void:
	match state:
		State.BROWSING:
			browse_time -= delta
			if browse_time <= 0.0:
				state = State.DECIDING
				_decide()
		_:
			pass


func begin_browsing() -> void:
	state = State.BROWSING


func _decide() -> void:
	if int(customer.get("order_delivery_id", -1)) >= 0:
		state = State.NEGOTIATING
		wants_order_delivery.emit(customer, int(customer["order_delivery_id"]))
		return
	if bool(customer.get("order_intent", false)):
		state = State.NEGOTIATING
		wants_to_order.emit(customer, false)
		return
	# Negotiate for the item that drew us to this stand. If another customer
	# bought the last copy while we walked over, choose again from live stock.
	var interest := preferred_interest
	if interest == "" or not (interest in InventoryManager.displayed_ids()):
		interest = CustomerGen.pick_interest(customer)
	if interest != "":
		state = State.NEGOTIATING
		wants_to_negotiate.emit(customer, interest)
	elif BoomManager.is_active() and String(customer.get("boom_id", "")) == BoomManager.active_boom_id \
			and randf() < BoomManager.request_frequency():
		state = State.NEGOTIATING
		wants_to_order.emit(customer, true)
	elif randf() < 0.5:
		wants_to_order.emit(customer, false)
		state = State.LEAVING
		leaving.emit()
	else:
		if BoomManager.is_active():
			disappointed.emit(customer)
		state = State.LEAVING
		leaving.emit()


func finish_negotiation() -> void:
	state = State.LEAVING
	leaving.emit()
